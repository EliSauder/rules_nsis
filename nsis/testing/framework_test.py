import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from nsis.testing.generate import REGISTERS, generate, validate
from nsis.testing.runner import Harness, command_line, read_outputs


ECHO = {
    "symbol": "Echo",
    "kind": "macro",
    "parameters": [
        {"name": "text", "direction": "in"},
        {"name": "result", "direction": "out"},
    ],
}


def record(**values):
    return (
        "NSIS-HARNESS-1\n" + "".join(
            f"{name}:{len(value.encode('utf-16-le')) // 2}:{value}"
            for name, value in values.items()
        )
    ).encode("utf-16-le")


class GeneratorTest(unittest.TestCase):
    def test_macro_and_definition_arguments(self):
        for kind, command in [("macro", "!insertmacro Echo"), ("definition", "${Echo}")]:
            with self.subTest(kind=kind):
                script = generate(dict(ECHO, kind=kind), "example.nsh")
                self.assertIn(f'{command} "$_harness_param_text" $_harness_param_result', script)

    def test_function_stack_order_and_uninstaller(self):
        spec = {
            "symbol": "un.Add",
            "kind": "function",
            "context": "uninstaller",
            "parameters": [
                {"name": "left", "direction": "in"},
                {"name": "right", "direction": "in"},
                {"name": "sum", "direction": "out"},
            ],
        }
        script = generate(spec, "example.nsh")
        self.assertIn('Push "$_harness_param_right"\nPush "$_harness_param_left"\nCall un.Add\nPop $_harness_param_sum', script)
        self.assertIn('WriteUninstaller "$_harness_uninstaller"', script)
        self.assertGreater(script.index("Call un.Add"), script.index('Section "Uninstall"'))

    def test_constant_definition(self):
        script = generate({
            "symbol": "Answer", "kind": "definition", "invocation": "value",
            "parameters": [{"name": "result", "direction": "out"}],
        }, "example.nsh")
        self.assertIn('StrCpy $_harness_param_result "${Answer}"', script)

    def test_invalid_descriptions(self):
        for change in [
            {"kind": "unknown"}, {"symbol": 'Bad"\nQuit'}, {"extra": True},
            {"parameters": [{"name": "output", "direction": "in"}]},
            {"parameters": [{"name": "a", "direction": "invalid"}]},
            {"parameters": [{"name": "a", "direction": "in"}] * 2},
            {"parameters": [{"name": "a", "direction": "in", "type": "float"}]},
        ]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate(dict(ECHO, **change))

    def test_registers_are_seeded_before_and_checked_after_api_in_both_contexts(self):
        for context in ("installer", "uninstaller"):
            script = generate(dict(ECHO, context=context), "example.nsh")
            call = script.index('!insertmacro Echo "$_harness_param_text" $_harness_param_result')
            write = script.index('FileOpen $_harness_file "$_harness_output"')
            for register in REGISTERS:
                with self.subTest(context=context, register=register):
                    self.assertLess(
                        script.index(f"StrCpy ${register} $_harness_before_{register}"), call
                    )
                    snapshot = script.index(f"StrCpy $_harness_after_{register} ${register}")
                    self.assertLess(call, snapshot)
                    self.assertLess(snapshot, write)
                    self.assertIn(
                        f"StrCmpS $_harness_after_{register} $_harness_before_{register} +2",
                        script,
                    )


class RunnerTest(unittest.TestCase):
    def test_typed_inputs_outputs_and_inout(self):
        spec = dict(ECHO, parameters=[
            {"name": "number", "direction": "inout", "type": "int"},
            {"name": "enabled", "direction": "inout", "type": "bool"},
        ])
        with Harness("example.exe", spec) as harness:
            for number, enabled in [(-2147483648, False), (2147483647, True)]:
                def execute(command):
                    self.assertIn(f"/number={number}", command)
                    self.assertIn(f"/enabled={int(enabled)}", command)
                    (harness.directory / "outputs.dat").write_bytes(
                        record(number=str(number), enabled=str(int(enabled)))
                    )
                    return subprocess.CompletedProcess(command, 0, "", "")
                with patch.object(harness, "_execute", side_effect=execute):
                    result = harness.run(number=number, enabled=enabled)
                result.assert_outputs(number=number, enabled=enabled)
                self.assertIs(type(result.outputs["number"]), int)
                self.assertIs(type(result.outputs["enabled"]), bool)
                with self.assertRaises(AssertionError):
                    result.assert_outputs(number=number, enabled=int(enabled))

    def test_invalid_typed_inputs_fail_before_execution(self):
        spec = dict(ECHO, parameters=[
            {"name": "number", "direction": "in", "type": "int"},
            {"name": "enabled", "direction": "in", "type": "bool"},
        ])
        with Harness("example.exe", spec) as harness:
            with patch.object(harness, "_execute") as execute:
                for number, enabled in [
                    (True, True), ("1", True), (1.0, True),
                    (-2147483649, True), (2147483648, True),
                    (1, 1), (1, "true"), (1, None),
                ]:
                    with self.subTest(number=number, enabled=enabled), self.assertRaises(ValueError):
                        harness.run(number=number, enabled=enabled)
                execute.assert_not_called()

    def test_invalid_typed_outputs_report_parameter(self):
        for typ, bad_values in [
            ("int", ["", "1.5", "0x10", " 1", "2147483648", "-2147483649"]),
            ("bool", ["", "true", "2", "-1"]),
        ]:
            spec = dict(ECHO, parameters=[{"name": "result", "direction": "out", "type": typ}])
            with Harness("example.exe", spec) as harness:
                for value in bad_values:
                    def execute(command):
                        (harness.directory / "outputs.dat").write_bytes(record(result=value))
                        return subprocess.CompletedProcess(command, 0, "", "")
                    with self.subTest(typ=typ, value=value):
                        with patch.object(harness, "_execute", side_effect=execute):
                            with self.assertRaisesRegex(ValueError, "result"):
                                harness.run()

    def test_nsis_command_line_quotes_values_not_entire_options(self):
        self.assertEqual(
            command_line([r"C:\a b\test.exe", "/S", "/text=  a /other=value  ", "/empty=", r"_?=C:\a b"]),
            r'"C:\a b\test.exe" /S /text="  a /other=value  " /empty="" _?=C:\a b',
        )

    def test_output_roundtrip_and_corruption(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "outputs"
            values = {"result": '  "\n:=;% \u03bb \U0001f600  ', "other": ""}
            output.write_bytes(record(**values))
            self.assertEqual(read_outputs(output, values), values)
            for bad in [b"", record(result="ok")[:-2], record(result="ok") + b"x"]:
                output.write_bytes(bad)
                with self.subTest(bad=bad), self.assertRaises(ValueError):
                    read_outputs(output, ["result"])

    def test_run_captures_streams_and_inputs_and_removes_stale_outputs(self):
        with Harness("example.exe", ECHO) as harness:
            output = harness.directory / "outputs.dat"
            output.write_bytes(record(result="stale"))

            def execute(command):
                self.assertFalse(output.exists())
                self.assertIn("/text=hello world", command)
                output.write_bytes(record(result="hello world"))
                return subprocess.CompletedProcess(command, 0, "stdout", "stderr")

            with patch.object(harness, "_execute", side_effect=execute):
                result = harness.run(text="hello world")
            result.assert_outputs(result="hello world")
            self.assertEqual((result.stdout, result.stderr), ("stdout", "stderr"))
            directory = harness.directory
        self.assertFalse(directory.exists())

    def test_abort_without_output_is_not_success(self):
        with Harness("example.exe", ECHO) as harness:
            with patch.object(harness, "_execute", return_value=subprocess.CompletedProcess([], 0, "", "")):
                with self.assertRaisesRegex(AssertionError, "without returning outputs"):
                    harness.run(text="")

    def test_invalid_inputs_and_expected_failure(self):
        with Harness("example.exe", ECHO) as harness:
            for inputs in [{}, {"text": "x", "unknown": ""}, {"text": '"quoted"'}, {"text": "\0"}]:
                with self.subTest(inputs=inputs), self.assertRaises(ValueError):
                    harness.run(**inputs)
            with patch.object(harness, "_execute", return_value=subprocess.CompletedProcess([], 3, "", "failed")):
                result = harness.run(text="", expected_exitcode=3)
                self.assertEqual(result.stderr, "failed")

    def test_uninstaller_preparation_and_direct_execution(self):
        spec = dict(ECHO, context="uninstaller")
        with Harness("example.exe", spec) as harness:
            def execute(command):
                if command[0] == str(harness.binary):
                    (harness.directory / "uninstall.exe").touch()
                else:
                    self.assertEqual(command[-1], f"_?={harness.directory}")
                    (harness.directory / "outputs.dat").write_bytes(record(result="hello"))
                return subprocess.CompletedProcess(command, 0, "", "")
            with patch.object(harness, "_execute", side_effect=execute):
                harness.run(text="hello").assert_outputs(result="hello")

    def test_register_changes_fail_even_when_exit_code_was_expected(self):
        with Harness("example.exe", ECHO) as harness:
            def execute(command):
                snapshots = {
                    f"{when}_{r}": f"random-{r}"
                    for r in REGISTERS for when in ("before", "after")
                }
                snapshots["after_0"] = "changed"
                snapshots["after_R9"] = "changed"
                (harness.directory / "outputs.dat.registers").write_bytes(record(**snapshots))
                return subprocess.CompletedProcess(command, 65, "stdout", "stderr")
            with patch.object(harness, "_execute", side_effect=execute):
                with self.assertRaisesRegex(
                    AssertionError, r"(?s)\$0: expected 'random-0'.*\$R9:.*stderr"
                ):
                    harness.run(text="", expected_exitcode=65)


if __name__ == "__main__":
    unittest.main()
