import shutil

from tests.includes import common

# Exit codes of the child uninstallers, in argument order.
_CHILD_EXIT_CODES = (0, 37)


def run_case(case, harness, args):
    import winreg

    if common.base(case) != "uninstall_existing":
        raise common.unhandled(case)
    code, *children = args
    assert len(children) == len(_CHILD_EXIT_CODES), children
    path = common.uninstall_key(code)
    try:
        common.delete_registry_tree(winreg, path)
        harness.run(appkey="missing-test-product").assert_outputs(exitcode=0)
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as key:
            winreg.SetValueEx(key, "UninstallString", 0, winreg.REG_SZ, str(harness.directory / "missing.exe"))
        harness.run(appkey="missing-file").assert_outputs(exitcode=0)

        for child, expected in zip(children, _CHILD_EXIT_CODES):
            install = harness.directory / f"installed product {expected}"
            install.mkdir()
            program = install / "Uninstall.exe"
            shutil.copyfile(common.rlocation(child), program)
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as key:
                winreg.SetValueEx(key, "UninstallString", 0, winreg.REG_SZ, str(program))
                winreg.SetValueEx(key, "InstallLocation", 0, winreg.REG_SZ, "")
            harness.run(appkey="missing-install-location").assert_outputs(exitcode=1)
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path, 0, winreg.KEY_SET_VALUE) as key:
                winreg.SetValueEx(key, "InstallLocation", 0, winreg.REG_SZ, str(install))
            harness.run(appkey="existing-product").assert_outputs(exitcode=expected)
            # A successful uninstaller deletes itself; a failed one is left.
            assert program.exists() is (expected != 0)
    finally:
        common.delete_registry_tree(winreg, path)


if __name__ == "__main__":
    common.main(run_case)
