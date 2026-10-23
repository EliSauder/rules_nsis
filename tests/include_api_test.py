import os
import platform
import sys
import uuid

from python.runfiles import Runfiles

from nsis.testing import Harness


def _registry_test(case, harness):
    import winreg

    case = case.removeprefix("un_")
    key = str(uuid.uuid4())
    path = "Software\\RulesNsisIncludeApi\\" + key
    try:
        if case.startswith("registry_set_"):
            kind = case.removeprefix("registry_set_")
            value = {"string": "value λ", "dword": 37, "binary": "000102FF"}[kind]
            if kind == "binary":
                harness.run(key=path, subkey="Value")
            else:
                harness.run(key=path, subkey="Value", value=value)
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path) as handle:
                actual, actual_type = winreg.QueryValueEx(handle, "Value")
            if kind == "string":
                assert (actual, actual_type) == (value, winreg.REG_SZ)
            elif kind == "dword":
                assert (actual, actual_type) == (int(value), winreg.REG_DWORD)
            else:
                assert (actual, actual_type) == (bytes.fromhex(value), winreg.REG_BINARY)
        elif case.startswith("registry_get_"):
            kind = case.removeprefix("registry_get_")
            value = {"string": "value λ", "dword": 37, "binary": bytes.fromhex("000102ff")}[kind]
            value_type = {
                "string": winreg.REG_SZ,
                "dword": winreg.REG_DWORD,
                "binary": winreg.REG_BINARY,
            }[kind]
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as handle:
                winreg.SetValueEx(handle, "Value", 0, value_type, value)
            result = harness.run(key=path, subkey="Value")
            expected = value if kind != "binary" else "000102FF"
            result.assert_outputs(value=expected)
        else:
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path):
                pass
            harness.run(key=path)
            try:
                winreg.OpenKey(winreg.HKEY_CURRENT_USER, path)
            except FileNotFoundError:
                return
            raise AssertionError(f"registry key was not removed: {path}")
    finally:
        try:
            winreg.DeleteKey(winreg.HKEY_CURRENT_USER, path)
        except FileNotFoundError:
            pass


def _run_case(case, harness, child_binaries=()):
    base = case.removeprefix("un_")
    if base in (
        "registry_set_string", "registry_set_dword", "registry_set_binary",
        "registry_get_string", "registry_get_dword", "registry_remove",
    ):
        return _registry_test(case, harness)
    if base.startswith("uninstall_constant_"):
        expected = {
            "display_name": "DisplayName",
            "display_version": "DisplayVersion",
            "display_icon": "DisplayIcon",
            "publisher": "Publisher",
            "version_minor": "VersionMinor",
            "version_major": "VersionMajor",
            "help_link": "HelpLink",
            "help_telephone": "HelpTelephone",
            "install_date": "InstallDate",
            "install_date_today": "InstallDateToday",
            "install_location": "InstallLocation",
            "install_source": "InstallSource",
            "url_about_info": "UrlAboutInfo",
            "url_update_info": "UrlUpdateInfo",
            "authorized_cdf_prefix": "AuthorizedCdfPrefix",
            "comments": "Comments",
            "contact": "Contact",
            "estimated_size": "EstimatedSize",
            "language": "Language",
            "modify_path": "ModifyPath",
            "readme": "Readme",
            "uninstall_string": "UninstallString",
            "quiet_uninstall_string": "QuietUninstallString",
            "settings_identifier": "SettingsIdentifier",
            "no_modify": "NoModify",
            "no_repair": "NoRepair",
            "no_remove": "NoRemove",
            "product_id": "ProductID",
            "system_component": "SystemComponent",
            "installed": "Installed",
            "directory": "Directory",
            "eventlog_source": "EventLogSource",
            "ins_install_location": "InstallLocation",
        }
        result = harness.run()
        result.assert_outputs(value=expected[base.removeprefix("uninstall_constant_")])
        return
    machine = platform.machine().lower()
    if "arm" in machine:
        arch = "arm64" if "64" in machine else "arm32"
    else:
        arch = "x86_64" if "64" in machine else "x86_32"
    if base == "arch_get":
        result = harness.run()
        assert type(result.outputs["arch"]) is str
        assert result.outputs["arch"] in ("x86_32", "x86_64", "arm32", "arm64")
    elif base == "arch_detect":
        assert harness.run().returncode == 0
    elif base in ("arch_is_64_bit", "arch_is_32_bit"):
        result = harness.run()
        result.assert_outputs(value=(base == "arch_is_64_bit") == ("64" in arch))
    elif base == "arch_validate":
        assert harness.run(expected=arch).returncode == 0
    elif base == "arch_validate_bitwidth":
        assert harness.run(bits=64 if "64" in arch else 32).returncode == 0
    elif base == "arch_validate_isa":
        assert harness.run(isa="arm" if "arm" in arch else "x86").returncode == 0
    elif base == "arch_reg_view":
        assert harness.run().returncode == 0
    elif base == "arch_if_bitwidth_match":
        harness.run().assert_outputs(result="matched")
    elif base == "if_test":
        harness.run().assert_outputs(result="matched")
    elif base == "if_not_test":
        harness.run().assert_outputs(result="matched")
    elif base == "shell_context_aliases":
        for mode, expected in [("current", "current"), ("admin", "admin"), ("reset", "current")]:
            harness.run(mode=mode).assert_outputs(context=expected)
    elif base == "native_arch_define":
        result = harness.run()
        expected = "arm32" if arch == "arm32" else "other"
        result.assert_outputs(arch=expected)
    elif base == "char_to_ascii":
        for character, expected in [("A", 65), ("z", 122), ("λ", 0), ("ab", 0), ("", 0)]:
            harness.run(character=character).assert_outputs(value=expected)
    elif base == "hex_to_bin":
        for value, expected in [
            ("0123456789ABCDEF", "0000000100100011010001010110011110001001101010111100110111101111"),
            ("f", "1111"), ("a1", "10100001"), ("", ""), ("xz", ""), ("g", ""),
        ]:
            harness.run(value=value).assert_outputs(binary=expected)
    elif base == "format_str_to_bin":
        for value, is_int, expected in [
            ("A", False, "01000001"), ("255", True, "11111111"),
            ("not-one-character", False, "0000"), ("15", True, "1111"),
        ]:
            harness.run(value=value, is_int=is_int).assert_outputs(binary=expected)
    elif base == "format_str_to_dword":
        for value, expected in [("A", "0x41"), ("z", "0x7A"), ("ab", "0x0")]:
            harness.run(value=value).assert_outputs(result=expected)
    elif base == "normalize_guid":
        guid = "aabbccdd-eeff-0011-2233-445566778899"
        expected = "{AABBCCDD-EEFF-0011-2233-445566778899}"
        for value in (guid, "{" + guid + "}"):
            harness.run(value=value).assert_outputs(result=expected)
        for value in ("not-a-guid", guid[:-1] + "z"):
            harness.run(value=value).assert_outputs(result="")
    elif base == "version_compare" or base == "version_compare_call":
        for first, second, expected in [
            ("1.2.3", "1.2.4", -1), ("1.2.4", "1.2.3", 1),
            ("1.2.3", "1.2.3", 0), ("01.002", "1.2", 0),
        ]:
            harness.run(first=first, second=second).assert_outputs(comparison=expected)
    elif base == "trim_quotes":
        for value, expected in [
            ("plain value", "plain value"),
        ]:
            harness.run(value=value).assert_outputs(result=expected)
    elif base == "trim_quotes_special":
        harness.run().assert_outputs(quoted="quoted value", empty="", left="left only")
    elif base == "product_code":
        result = harness.run()
        result.assert_outputs(value="{AABBCCDD-EEFF-0011-2233-445566778899}")
    elif base == "set_product_code":
        result = harness.run(guid="aabbccdd-eeff-0011-2233-445566778899")
        assert result.returncode == 0
    elif base == "test_id":
        result = harness.run()
        result.assert_outputs(value="framework-test-id")
    elif base == "test_id_set":
        harness.run(id="updated-test-id").assert_outputs(value="updated-test-id")
    elif base == "uninstall_registry_update":
        import winreg

        subkey = "DisplayName"
        harness.run(subkey=subkey, value="include API test")
        path = _uninstall_key(case)
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path) as handle:
                assert winreg.QueryValueEx(handle, subkey) == ("include API test", winreg.REG_SZ)
        finally:
            _delete_registry_tree(winreg, path)
    elif base in ("uninstall_registry_get", "uninstall_registry_get_register"):
        import winreg

        path = _uninstall_key(case)
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as handle:
            winreg.SetValueEx(handle, "DisplayName", 0, winreg.REG_SZ, "seeded")
        try:
            harness.run(subkey="DisplayName").assert_outputs(value="seeded")
        finally:
            _delete_registry_tree(winreg, path)
    elif base == "uninstall_registry_remove":
        import winreg

        path = _uninstall_key(case)
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as handle:
            winreg.SetValueEx(handle, "DisplayName", 0, winreg.REG_SZ, "remove me")
        try:
            assert harness.run().returncode == 0
            try:
                winreg.OpenKey(winreg.HKEY_CURRENT_USER, path)
            except FileNotFoundError:
                pass
            else:
                raise AssertionError(f"uninstall registry key was not removed: {path}")
        finally:
            _delete_registry_tree(winreg, path)
    elif base == "install_detail_update":
        import winreg

        publisher = str(uuid.uuid4())
        product = str(uuid.uuid4())
        component = str(uuid.uuid4())
        value = "install detail"
        path = "Software\\" + publisher + "\\" + product + "\\Components\\" + component
        try:
            harness.run(publisher=publisher, product=product, component=component, subkey="Name", value=value)
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path) as handle:
                assert winreg.QueryValueEx(handle, "Name") == (value, winreg.REG_SZ)
        finally:
            _delete_registry_tree(winreg, "Software\\" + publisher)
    elif base == "install_detail_get":
        import winreg

        publisher, product, component = str(uuid.uuid4()), "product", "component"
        path = "Software\\" + publisher + "\\" + product + "\\Components\\" + component
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as handle:
            winreg.SetValueEx(handle, "Name", 0, winreg.REG_SZ, "install detail")
        try:
            harness.run(publisher=publisher, product=product, component=component, subkey="Name").assert_outputs(value="install detail")
        finally:
            _delete_registry_tree(winreg, "Software\\" + publisher)
    elif base == "uninstall_existing":
        _uninstall_existing_test(harness, child_binaries)
    elif base == "mutex":
        assert harness.run(name="RulesNsisIncludeApi-" + str(uuid.uuid4())).returncode == 0
    elif base == "eventlog_add_source":
        import winreg

        source = "RulesNsisHarness" + uuid.uuid4().hex
        path = "SYSTEM\\CurrentControlSet\\Services\\EventLog\\Application\\" + source
        try:
            result = harness.run(
                key="Application", source=source, types=7,
                event_file="", category_file="category.dll", parameter_file="parameter.dll",
            )
            assert result.returncode == 0
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path) as handle:
                assert winreg.QueryValueEx(handle, "TypesSupported") == (7, winreg.REG_DWORD)
                assert winreg.QueryValueEx(handle, "EventMessageFile") == (
                    "%SystemRoot%\\System32\\EventCreate.exe",
                    winreg.REG_SZ,
                )
                assert winreg.QueryValueEx(handle, "CategoryMessageFile") == ("category.dll", winreg.REG_SZ)
                assert winreg.QueryValueEx(handle, "ParameterMessageFile") == ("parameter.dll", winreg.REG_SZ)
        finally:
            _delete_registry_tree(winreg, path)
    elif base == "eventlog_remove_source":
        import winreg

        source = "RulesNsisHarnessRemove" + uuid.uuid4().hex
        path = "SYSTEM\\CurrentControlSet\\Services\\EventLog\\Application\\" + source
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as handle:
            winreg.SetValueEx(handle, "TypesSupported", 0, winreg.REG_DWORD, 1)
        try:
            assert harness.run(key="Application", source=source).returncode == 0
            try:
                winreg.OpenKey(winreg.HKEY_CURRENT_USER, path)
            except FileNotFoundError:
                pass
            else:
                raise AssertionError(f"event log source was not removed: {path}")
        finally:
            _delete_registry_tree(winreg, path)
    elif base == "move_file":
        source = harness.directory / "source.txt"
        destination = harness.directory / "destination.txt"
        source.write_text("move test", encoding="utf-8")
        harness.run(source=str(source), destination=str(destination))
        assert destination.read_text(encoding="utf-8") == "move test"
        assert not source.exists()
    elif base == "move_folder":
        source = harness.directory / "source"
        destination = harness.directory / "destination"
        (source / "child").mkdir(parents=True)
        (source / "child" / "source.txt").write_text("move folder test", encoding="utf-8")
        harness.run(source=str(source), destination=str(destination), mask="*.txt")
        assert (destination / "child" / "source.txt").read_text(encoding="utf-8") == "move folder test"
        assert not source.exists()
    elif base in ("log", "log_debug", "log_info", "log_warn", "log_error"):
        result = harness.run(text="harness log")
        assert result.returncode == 0
    elif base in (
        "service_create", "service_update", "service_query", "service_start",
        "service_stop", "service_delete", "service_set_description",
    ):
        name = (
            "RulesNsis/Invalid-" + uuid.uuid4().hex
            if base in ("service_create", "service_update", "service_delete", "service_set_description")
            else "RulesNsisMissing-" + uuid.uuid4().hex
        )
        params = {"name": name}
        if base in ("service_create", "service_update"):
            params.update(binary=r"C:\Windows\System32\cmd.exe", display_name="Missing", start_type="demand", dependencies="")
        elif base == "service_set_description":
            params["description"] = "Missing service"
        result = harness.run(**params)
        assert result.outputs["result"] not in ("", "0")
    elif base in (
        "icacls_grant", "icacls_deny", "icacls_remove_grant",
        "icacls_remove_deny", "icacls_integrity", "icacls_substitute",
    ):
        params = {
            "path": str(harness.directory / "missing"),
            "recursive": 0,
        }
        if base in ("icacls_grant", "icacls_deny", "icacls_remove_grant", "icacls_remove_deny"):
            params["sid"] = "*S-1-1-0"
        if base in ("icacls_grant", "icacls_deny"):
            params["permission"] = "R"
        if base == "icacls_integrity":
            params.update(level="Low", inheritance="")
        if base == "icacls_substitute":
            params.update(old_sid="*S-1-1-0", new_sid="*S-1-5-18")
        for inheritance in (("", "OI") if base == "icacls_integrity" else (None,)):
            if inheritance is not None:
                params["inheritance"] = inheritance
            result = harness.run(**params)
            assert result.outputs["result"] not in ("", "0")
    elif base in ("shell_context_admin", "shell_context_current", "shell_context_set", "shell_context_reset"):
        assert harness.run().returncode == 0
    else:
        raise ValueError(f"Unhandled include API case: {case}")


def _delete_registry_tree(winreg, path):
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path, 0, winreg.KEY_ALL_ACCESS) as key:
            while True:
                try:
                    child = winreg.EnumKey(key, 0)
                except OSError as error:
                    if getattr(error, "winerror", None) == 259:
                        break
                    raise
                _delete_registry_tree(winreg, path + "\\" + child)
        winreg.DeleteKey(winreg.HKEY_CURRENT_USER, path)
    except FileNotFoundError:
        pass


def _uninstall_key(case):
    codes = {
        "uninstall_registry_update": "11111111-1111-4111-8111-111111111111",
        "un_uninstall_registry_update": "22222222-2222-4222-8222-222222222222",
        "uninstall_registry_get": "33333333-3333-4333-8333-333333333333",
        "un_uninstall_registry_get": "44444444-4444-4444-8444-444444444444",
        "uninstall_registry_remove": "55555555-5555-4555-8555-555555555555",
        "un_uninstall_registry_remove": "66666666-6666-4666-8666-666666666666",
        "uninstall_registry_get_register": "88888888-8888-4888-8888-888888888888",
        "un_uninstall_registry_get_register": "99999999-9999-4999-8999-999999999999",
    }
    product_code = codes[case]
    return "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{" + product_code.upper() + "}"


def _uninstall_existing_test(harness, child_binaries):
    import shutil
    import winreg

    path = r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{77777777-7777-4777-8777-777777777777}"
    try:
        _delete_registry_tree(winreg, path)
        harness.run(appkey="missing-test-product").assert_outputs(exitcode=0)
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as key:
            winreg.SetValueEx(key, "UninstallString", 0, winreg.REG_SZ, str(harness.directory / "missing.exe"))
        harness.run(appkey="missing-file").assert_outputs(exitcode=0)

        assert len(child_binaries) == 2, "Expected success and failure child binaries"
        for child, expected in zip(child_binaries, (0, 37)):
            install = harness.directory / f"installed product {expected}"
            install.mkdir()
            program = install / "Uninstall.exe"
            shutil.copyfile(child, program)
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as key:
                winreg.SetValueEx(key, "UninstallString", 0, winreg.REG_SZ, str(program))
                winreg.SetValueEx(key, "InstallLocation", 0, winreg.REG_SZ, "")
            harness.run(appkey="missing-install-location").assert_outputs(exitcode=1)
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path, 0, winreg.KEY_SET_VALUE) as key:
                winreg.SetValueEx(key, "InstallLocation", 0, winreg.REG_SZ, str(install))
            harness.run(appkey="existing-product").assert_outputs(exitcode=expected)
            assert program.exists() is (expected != 0)
    finally:
        _delete_registry_tree(winreg, path)


def main():
    case, binary, description, *children = sys.argv[1:]
    runfiles = Runfiles.Create()
    with Harness(
        runfiles.Rlocation(binary),
        runfiles.Rlocation(description),
        directory=os.environ["TEST_TMPDIR"],
    ) as harness:
        _run_case(case, harness, [runfiles.Rlocation(child) for child in children])


if __name__ == "__main__":
    main()
