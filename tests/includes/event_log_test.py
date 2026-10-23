import uuid

from tests.includes import common

_APPLICATION = "SYSTEM\\CurrentControlSet\\Services\\EventLog\\Application\\"


def run_case(case, harness, args):
    import winreg

    base = common.base(case)
    if base == "eventlog_add_source":
        # Event sources always live under HKLM with the active test id appended.
        source = "RulesNsisHarness" + uuid.uuid4().hex
        root = _APPLICATION + source
        path = root + "\\framework-test-id"
        try:
            result = harness.run(
                key="Application", source=source, types=7,
                event_file="", category_file="%SystemRoot%\\category.dll", parameter_file="parameter.dll",
                expect_errors=False,
            )
            assert result.returncode == 0
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, path) as handle:
                assert winreg.QueryValueEx(handle, "TypesSupported") == (7, winreg.REG_DWORD)
                assert winreg.QueryValueEx(handle, "EventMessageFile") == (
                    "%SystemRoot%\\System32\\EventCreate.exe", winreg.REG_EXPAND_SZ,
                )
                assert winreg.QueryValueEx(handle, "CategoryMessageFile") == (
                    "%SystemRoot%\\category.dll", winreg.REG_EXPAND_SZ,
                )
                assert winreg.QueryValueEx(handle, "ParameterMessageFile") == ("parameter.dll", winreg.REG_EXPAND_SZ)
            common.assert_key_missing(winreg, path)
        finally:
            common.delete_registry_tree(winreg, root, winreg.HKEY_LOCAL_MACHINE)
    elif base == "eventlog_remove_source":
        source = "RulesNsisHarnessRemove" + uuid.uuid4().hex
        root = _APPLICATION + source
        path = root + "\\framework-test-id"
        with winreg.CreateKey(winreg.HKEY_LOCAL_MACHINE, path) as handle:
            winreg.SetValueEx(handle, "TypesSupported", 0, winreg.REG_DWORD, 1)
        try:
            assert harness.run(key="Application", source=source).returncode == 0
            common.assert_key_missing(winreg, path, winreg.HKEY_LOCAL_MACHINE)
        finally:
            common.delete_registry_tree(winreg, root, winreg.HKEY_LOCAL_MACHINE)
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
