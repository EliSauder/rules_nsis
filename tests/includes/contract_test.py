"""Check every case's dispatch contract without executing Windows binaries."""

import importlib
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from nsis.testing.generate import inputs, outputs, validate
from nsis.testing.runner import serialize_input
from tests.includes import common

# api -> case -> (spec, extra args)
CASES = {}

# Cases that change machine state or assert process output, so only their
# first invocation is checked.
_IMPURE = (
    "registry_set_", "registry_get_", "registry_remove", "registry_view_", "registry_pinned_", "uninstall_registry_",
    "install_detail_", "eventlog_", "move_", "uninstall_existing", "icacls_", "mutex", "log", "console",
    "shortcut_", "cli_fail", "option_persist", "option_load_", "product_registry_",
)


class ReachedInvocation(Exception):
    pass


class ContractResult:
    returncode = 0
    errors = False

    def __init__(self, spec):
        self.parameters = outputs(spec)
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
    def run(expected_exitcode=0, expect_errors=None, command_args=(), command_tail=(), **values):
        assert type(expected_exitcode) is int
        assert expect_errors is None or type(expect_errors) is bool
        parameters = inputs(spec)
        assert values.keys() == {p["name"] for p in parameters}, values
        for parameter in parameters:
            serialize_input(parameter, values[parameter["name"]])
        if stop_at_invocation:
            raise ReachedInvocation()
        return ContractResult(spec)

    return SimpleNamespace(
        run=MagicMock(side_effect=run),
        directory=Path(tempfile.mkdtemp(dir=os.environ["TEST_TMPDIR"])),
    )


def enumeration_end():
    error = OSError("No more registry items")
    error.winerror = 259
    return error


def module(api):
    return importlib.import_module(f"tests.includes.{api}_test")


def all_cases():
    for api, cases in CASES.items():
        for case, (spec, args) in cases.items():
            yield api, case, spec, args


class DispatchContractTest(unittest.TestCase):
    def setUp(self):
        self.registry = MagicMock()
        self.registry.EnumKey.side_effect = enumeration_end()
        patcher = patch.dict(sys.modules, winreg=self.registry)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_every_declared_case_reaches_a_valid_invocation(self):
        for api, case, spec, args in all_cases():
            with self.subTest(case=case):
                harness = contract_harness(spec, stop_at_invocation=True)
                with self.assertRaises(ReachedInvocation):
                    module(api).run_case(case, harness, args)
                harness.run.assert_called_once()

    def test_all_pure_case_inputs_and_expected_output_types(self):
        with patch.object(common.platform, "machine", return_value="AMD64"):
            for api, case, spec, args in all_cases():
                if common.base(case).startswith(_IMPURE):
                    continue
                with self.subTest(case=case):
                    harness = contract_harness(spec)
                    module(api).run_case(case, harness, args)
                    self.assertGreater(harness.run.call_count, 0)

    def test_unknown_case_is_rejected(self):
        for api in CASES:
            for case in ("not_a_declared_case", "un_not_a_declared_case"):
                with self.subTest(api=api, case=case), self.assertRaisesRegex(
                    ValueError, "Unhandled include API case"
                ):
                    module(api).run_case(case, MagicMock(), [])

    def test_registry_enumeration_only_swallows_no_more_items(self):
        registry = MagicMock()
        registry.EnumKey.side_effect = enumeration_end()
        common.delete_registry_tree(registry, "Software\\test")
        registry.DeleteKey.assert_called_once()
        for code in (5, 6):
            error = OSError("Registry failure")
            error.winerror = code
            registry.EnumKey.side_effect = error
            with self.subTest(code=code), self.assertRaises(OSError) as raised:
                common.delete_registry_tree(registry, "Software\\test")
            self.assertIs(raised.exception, error)


if __name__ == "__main__":
    for argument in sys.argv[1:]:
        api, case, path, *args = argument.split("|")
        spec = validate(json.loads(Path(common.rlocation(path)).read_text()))
        CASES.setdefault(api, {})[case] = (spec, args)
    unittest.main(argv=[sys.argv[0]])
