import uuid

from tests.includes import common

_CONSTANT = "uninstall_constant_"


def _uninstall_registry(base, harness, path):
    import winreg

    try:
        if base == "uninstall_registry_update":
            harness.run(subkey="DisplayName", value="include API test")
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path) as handle:
                assert winreg.QueryValueEx(handle, "DisplayName") == ("include API test", winreg.REG_SZ)
        elif base in ("uninstall_registry_get", "uninstall_registry_get_register"):
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as handle:
                winreg.SetValueEx(handle, "DisplayName", 0, winreg.REG_SZ, "seeded")
            harness.run(subkey="DisplayName").assert_outputs(value="seeded")
        else:
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as handle:
                winreg.SetValueEx(handle, "DisplayName", 0, winreg.REG_SZ, "remove me")
            assert harness.run().returncode == 0
            common.assert_key_missing(winreg, path)
    finally:
        common.delete_registry_tree(winreg, path)


def _install_detail(base, harness):
    import winreg

    publisher, product, component = str(uuid.uuid4()), "product", "component"
    path = "Software\\" + publisher + "\\" + product + "\\Components\\" + component
    try:
        if base == "install_detail_update":
            harness.run(publisher=publisher, product=product, component=component, subkey="Name", value="install detail")
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path) as handle:
                assert winreg.QueryValueEx(handle, "Name") == ("install detail", winreg.REG_SZ)
        else:
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as handle:
                winreg.SetValueEx(handle, "Name", 0, winreg.REG_SZ, "install detail")
            harness.run(
                publisher=publisher, product=product, component=component, subkey="Name",
            ).assert_outputs(value="install detail")
    finally:
        common.delete_registry_tree(winreg, "Software\\" + publisher)


def run_case(case, harness, args):
    base = common.base(case)
    if base.startswith(_CONSTANT):
        # The expected value is the only argument.
        (expected,) = args
        harness.run().assert_outputs(value=expected)
    elif base == "set_product_code":
        assert harness.run(guid="aabbccdd-eeff-0011-2233-445566778899").returncode == 0
    elif base == "product_code":
        (code,) = args
        harness.run().assert_outputs(value="{" + code.upper() + "}")
    elif base in (
        "uninstall_registry_update", "uninstall_registry_get",
        "uninstall_registry_get_register", "uninstall_registry_remove",
    ):
        (code,) = args
        _uninstall_registry(base, harness, common.uninstall_key(code))
    elif base in ("install_detail_update", "install_detail_get"):
        _install_detail(base, harness)
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
