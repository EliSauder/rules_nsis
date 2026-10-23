"""Check every migrated dispatch contract without executing Windows binaries."""

import json
import os
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


class ReachedInvocation(Exception):
    pass


class ContractResult:
    returncode = 0
    errors = False

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
    def run(expect_errors=None, **inputs):
        assert expect_errors is None or type(expect_errors) is bool
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
            "move_", "uninstall_existing", "icacls_",
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


if __name__ == "__main__":
    runfiles = Runfiles.Create()
    for path in sys.argv[1:]:
        case = Path(path).name.removesuffix("_symbol.json")
        SPECS[case] = validate(json.loads(Path(runfiles.Rlocation(path)).read_text()))
    unittest.main(argv=[sys.argv[0]])
