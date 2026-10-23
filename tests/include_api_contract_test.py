"""Check every migrated dispatch contract without executing Windows binaries."""

import json
import os
import re
import shlex
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from python.runfiles import Runfiles

from tests import include_api_test
from nsis.testing.generate import validate
from nsis.testing.runner import serialize_input


SPECS = {}
INCLUDES = None


class ReachedInvocation(Exception):
    pass


class ContractResult:
    returncode = 0

    def __init__(self, spec):
        self.parameters = [p for p in spec["parameters"] if p["direction"] != "in"]
        self.outputs = {
            p["name"]: (
                True if p["type"] == "bool" else
                1 if p["type"] == "int" else
                "x86_64" if p["name"] == "arch" else "1"
            )
            for p in self.parameters
        }

    def assert_outputs(self, **expected):
        assert expected.keys() == self.outputs.keys(), expected
        for parameter in self.parameters:
            typ = {"string": str, "int": int, "bool": bool}[parameter["type"]]
            assert type(expected[parameter["name"]]) is typ, parameter


def contract_harness(spec, *, stop_at_invocation=False):
    def run(**inputs):
        parameters = [p for p in spec["parameters"] if p["direction"] != "out"]
        assert inputs.keys() == {p["name"] for p in parameters}, inputs
        for parameter in parameters:
            serialize_input(parameter, inputs[parameter["name"]])
        if stop_at_invocation:
            raise ReachedInvocation()
        return ContractResult(spec)

    return SimpleNamespace(
        run=MagicMock(side_effect=run), directory=Path(os.environ["TEST_TMPDIR"])
    )


def enumeration_end():
    error = OSError("No more registry items")
    error.winerror = 259
    return error


class DispatchContractTest(unittest.TestCase):
    def test_every_declared_case_reaches_a_valid_invocation(self):
        registry = MagicMock()
        registry.EnumKey.side_effect = enumeration_end()
        with patch.dict(sys.modules, winreg=registry):
            for case, spec in SPECS.items():
                with self.subTest(case=case):
                    harness = contract_harness(spec, stop_at_invocation=True)
                    with self.assertRaises(ReachedInvocation):
                        include_api_test._run_case(case, harness)
                    harness.run.assert_called_once()

    def test_all_pure_case_inputs_and_expected_output_types(self):
        excluded = (
            "registry_", "uninstall_registry_", "install_detail_", "eventlog_",
            "move_", "uninstall_existing",
        )
        with patch.object(include_api_test.platform, "machine", return_value="AMD64"):
            for case, spec in SPECS.items():
                if case.removeprefix("un_").startswith(excluded):
                    continue
                with self.subTest(case=case):
                    harness = contract_harness(spec)
                    include_api_test._run_case(case, harness)
                    self.assertGreater(harness.run.call_count, 0)

    def test_unknown_case_is_rejected(self):
        for case in ("not_a_declared_case", "log_typo", "service_typo", "icacls_typo", "registry_typo"):
            with self.subTest(case=case), self.assertRaisesRegex(ValueError, "Unhandled include API case"):
                include_api_test._run_case(case, MagicMock())

    def test_registry_enumeration_only_swallows_no_more_items(self):
        registry = MagicMock()
        registry.EnumKey.side_effect = enumeration_end()
        include_api_test._delete_registry_tree(registry, "Software\\test")
        registry.DeleteKey.assert_called_once()
        for code in (5, 6):
            error = OSError("Registry failure")
            error.winerror = code
            registry.EnumKey.side_effect = error
            with self.subTest(code=code), self.assertRaises(OSError) as raised:
                include_api_test._delete_registry_tree(registry, "Software\\test")
            self.assertIs(raised.exception, error)


class OperandPreservationTest(unittest.TestCase):
    def run_macro(self, source, name, output="$result"):
        """Symbolically execute straight-line stack/operand code, stubbing OS calls."""
        text = (INCLUDES / source).read_text()
        body = re.search(
            r"!macro " + re.escape(name) + r"(?: [^\n]*)?\n(.*?)!macroend",
            text, re.S,
        ).group(1).replace("${OUT}", output)
        # The mutex's success path skips the error/Abort branch.
        body = re.sub(r"\$\{If\}.*?\$\{EndIf\}", "", body, flags=re.S)
        registers = {
            "$" + register: "sentinel-" + register
            for register in [str(i) for i in range(10)] + ["R" + str(i) for i in range(10)]
        }
        original = dict(registers)
        stack = ["caller-stack-item"]
        for line in body.splitlines():
            parts = line.strip().split()
            if not parts:
                continue
            command, *operands = parts
            if command == "Push":
                stack.insert(0, registers.get(operands[0], operands[0]))
            elif command == "Pop":
                registers[operands[0]] = stack.pop(0)
            elif command == "Exch":
                register = operands[0]
                stack[0], registers[register] = registers[register], stack[0]
            elif command == "System::Call":
                registers["$1"] = "mutex-handle"
                stack.insert(0, "0")
            elif command == "!insertmacro":
                if operands[0].endswith("GetProductCode"):
                    registers[operands[-1]] = "product-code"
                elif operands[0].endswith("GetRegistrySubKey"):
                    registers[operands[-1]] = "registry-value"
                else:
                    self.fail(f"Unexpected macro: {line}")
            else:
                self.fail(f"Unexpected instruction: {line}")
        self.assertEqual(stack, ["caller-stack-item"])
        return registers, original

    def test_mutex_preserves_handle_output_register_in_both_contexts(self):
        for name in ("ValidateMutex", "un.ValidateMutex"):
            with self.subTest(name=name):
                registers, original = self.run_macro("Mutex.nsh", name)
                self.assertEqual(registers, original)

    def test_registry_getter_preserves_registers_and_supports_output_alias(self):
        for name in ("GetUninstallRegistry", "un.GetUninstallRegistry"):
            for output in ("$result", "$0", "$R9"):
                with self.subTest(name=name, output=output):
                    registers, original = self.run_macro("Product.nsh", name, output)
                    self.assertEqual(registers[output], "registry-value")
                    original[output] = "registry-value"
                    self.assertEqual(registers, original)

    def test_existing_uninstall_stack_paths(self):
        text = (INCLUDES / "Uninstall.nsh").read_text()
        body = text.split("Function UninstallExisting ", 1)[1].split("FunctionEnd", 1)[0]
        body = re.sub(
            r"!ifdef TESTABLE_INSTALLER\n(.*?)!else\n.*?!endif",
            lambda match: match[1], body, flags=re.S,
        )
        lines = [line.strip() for line in body.splitlines()[1:] if line.strip()]
        labels = {line[:-1]: index for index, line in enumerate(lines) if line.endswith(":")}

        def branch_end(index, allow_else):
            depth = 0
            for cursor in range(index + 1, len(lines)):
                line = lines[cursor]
                if line.startswith(("${If}", "${IfNotTest}")):
                    depth += 1
                elif line == "${EndIf}":
                    if depth == 0:
                        return cursor + 1
                    depth -= 1
                elif allow_else and line == "${Else}" and depth == 0:
                    return cursor + 1
            self.fail("Unbalanced conditional")

        scenarios = [
            ("", False, "", 0, 0),
            ("missing.exe", False, "", 0, 0),
            ("uninstall.exe", True, "", 0, 1),
            ("uninstall.exe", True, "install-dir", 0, 0),
            ("uninstall.exe", True, "install-dir", 37, 37),
        ]
        for path, exists, directory, child_code, expected in scenarios:
            with self.subTest(path=path, directory=directory, child_code=child_code):
                registers = {"$" + str(i): "sentinel-" + str(i) for i in range(10)}
                original = dict(registers)
                stack = ["appkey", "caller-stack-item"]
                value = lambda operand: registers.get(operand, operand)
                cursor = 0
                while cursor < len(lines):
                    line = lines[cursor]
                    cursor += 1
                    if line.startswith(("#", ";")) or line.endswith(":"):
                        continue
                    if line.startswith("!insertmacro"):
                        if "GetUninstallRegistry" in line:
                            registers[line.split()[-1]] = path if "UnUninstallString" in line else directory
                        elif "TrimQuotes" not in line and "Log" not in line:
                            self.fail(f"Unexpected macro: {line}")
                        continue
                    if line.startswith("nsExec::"):
                        stack[:0] = [str(child_code), "child-output"]
                        continue
                    parts = shlex.split(line)
                    command, *operands = parts
                    if command == "${If}":
                        matched = value(operands[0]) == value(operands[2])
                        if not matched:
                            cursor = branch_end(cursor - 1, True)
                    elif command == "${Else}":
                        cursor = branch_end(cursor - 1, False)
                    elif command in ("${EndIf}", "${IfNotTest}", "MessageBox", "Delete", "RMDir"):
                        pass
                    elif command == "Push":
                        stack.insert(0, value(operands[0]))
                    elif command == "Pop":
                        registers[operands[0]] = stack.pop(0)
                    elif command == "Exch":
                        if not operands or operands[0].isdigit():
                            offset = int(operands[0]) if operands else 1
                            stack[0], stack[offset] = stack[offset], stack[0]
                        else:
                            register = operands[0]
                            stack[0], registers[register] = registers[register], stack[0]
                    elif command == "StrCpy":
                        registers[operands[0]] = value(operands[1])
                    elif command == "IntOp":
                        registers[operands[0]] = str(int(value(operands[1])) + int(value(operands[3])))
                    elif command == "Goto":
                        cursor = labels[operands[0]]
                    elif command == "IfFileExists":
                        cursor = labels[operands[1] if exists else operands[2]]
                    elif command == "Return":
                        break
                    else:
                        self.fail(f"Unexpected instruction: {line}")
                self.assertEqual(stack, [str(expected), "caller-stack-item"])
                self.assertEqual(registers, original)


if __name__ == "__main__":
    runfiles = Runfiles.Create()
    for path in sys.argv[1:]:
        if path.startswith("--includes="):
            INCLUDES = Path(runfiles.Rlocation(path.removeprefix("--includes=")))
            continue
        case = Path(path).name.removesuffix("_symbol.json")
        SPECS[case] = validate(json.loads(Path(runfiles.Rlocation(path)).read_text()))
    unittest.main(argv=[sys.argv[0]])
