import uuid

from tests.includes import common


def _set_binary(winreg, kind, harness, path):
    harness.run(key=path, subkey="Value")
    expected = bytes.fromhex("0A0B" if kind == "binary_register" else "000102FF")
    target = path + "\\framework-test-id" if kind == "binary_test_id" else path
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, target) as handle:
        assert winreg.QueryValueEx(handle, "Value") == (expected, winreg.REG_BINARY)
    if kind == "binary_test_id":
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path) as handle:
            try:
                winreg.QueryValueEx(handle, "Value")
            except FileNotFoundError:
                return
        raise AssertionError("binary value ignored the active test id")


def _registry_case(base, harness):
    import winreg

    path = "Software\\RulesNsisIncludeApi\\" + str(uuid.uuid4())
    try:
        if base.startswith("registry_set_binary"):
            _set_binary(winreg, base.removeprefix("registry_set_"), harness, path)
        elif base.startswith("registry_set_"):
            kind = base.removeprefix("registry_set_")
            # Values are pushed quoted, so spaces and empty values must round-trip.
            values = {"string": ["value λ", "value with  spaces", ""], "dword": [37]}[kind]
            value_type = {"string": winreg.REG_SZ, "dword": winreg.REG_DWORD}[kind]
            for value in values:
                harness.run(key=path, subkey="Value", value=value)
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path) as handle:
                    assert winreg.QueryValueEx(handle, "Value") == (value, value_type)
        elif base.startswith("registry_get_"):
            kind = base.removeprefix("registry_get_")
            value = {"string": "value λ", "dword": 37}[kind]
            value_type = {"string": winreg.REG_SZ, "dword": winreg.REG_DWORD}[kind]
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as handle:
                winreg.SetValueEx(handle, "Value", 0, value_type, value)
            harness.run(key=path, subkey="Value").assert_outputs(value=value)
        else:
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path):
                pass
            harness.run(key=path)
            common.assert_key_missing(winreg, path)
    finally:
        common.delete_registry_tree(winreg, path)


_REGISTRY = (
    "registry_set_string", "registry_set_dword", "registry_set_binary",
    "registry_set_binary_register", "registry_set_binary_test_id",
    "registry_get_string", "registry_get_dword", "registry_remove",
)


def run_case(case, harness, args):
    base = common.base(case)
    if base in _REGISTRY:
        _registry_case(base, harness)
    elif base == "registry_define_reg_view":
        assert harness.run().returncode == 0
    elif base == "format_str_to_bin":
        for value, is_int, expected in [
            ("A", False, "01000001"), ("255", True, "11111111"),
            ("not-one-character", False, "0000"), ("15", True, "1111"),
        ]:
            harness.run(value=value, is_int=is_int).assert_outputs(binary=expected)
    elif base == "format_str_to_dword":
        for value, expected in [("A", "0x41"), ("z", "0x7A"), ("ab", "0x0")]:
            harness.run(value=value).assert_outputs(result=expected)
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
