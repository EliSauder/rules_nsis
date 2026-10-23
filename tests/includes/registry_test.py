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


_VIEWS = ("32", "64")
_BINARY = bytes.fromhex("000102FF")


def _native_view():
    return "64" if "64" in common.host_arch() else "32"


def _split_views():
    """Whether the 32 and 64 bit views of HKLM\\Software are distinct."""
    return _native_view() == "64"


def _access(winreg, view):
    return {"32": winreg.KEY_WOW64_32KEY, "64": winreg.KEY_WOW64_64KEY}[view]


def _hklm_value(winreg, path, view, name="Value"):
    """The (value, type) of name in view, or None when the key or value is missing."""
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, path, 0, winreg.KEY_READ | _access(winreg, view)) as handle:
            return winreg.QueryValueEx(handle, name)
    except FileNotFoundError:
        return None


def _hklm_seed(winreg, path, view, value):
    access = winreg.KEY_WRITE | _access(winreg, view)
    with winreg.CreateKeyEx(winreg.HKEY_LOCAL_MACHINE, path, 0, access) as handle:
        winreg.SetValueEx(handle, "Value", 0, winreg.REG_SZ, value)


def _hklm_delete(winreg, path):
    for view in _VIEWS:
        try:
            winreg.DeleteKeyEx(winreg.HKEY_LOCAL_MACHINE, path, _access(winreg, view))
        except FileNotFoundError:
            pass


def _assert_only_in(winreg, path, view, expected):
    assert _hklm_value(winreg, path, view) == expected, view
    if _split_views():
        other = "32" if view == "64" else "64"
        assert _hklm_value(winreg, path, other) is None, f"{view} write leaked into the {other} view"


def _view_case(base, harness):
    import winreg

    path = "Software\\RulesNsisIncludeApi\\" + str(uuid.uuid4())
    try:
        if base == "registry_view_set_string":
            for view in _VIEWS:
                harness.run(view=view, key=path, subkey="Value", value=view + " view")
                _assert_only_in(winreg, path, view, (view + " view", winreg.REG_SZ))
                _hklm_delete(winreg, path)
            # An unknown view falls back to the native view.
            harness.run(view="bogus", key=path, subkey="Value", value="native")
            _assert_only_in(winreg, path, _native_view(), ("native", winreg.REG_SZ))
        elif base == "registry_view_set_dword":
            for view in _VIEWS:
                harness.run(view=view, key=path, subkey="Value", value=int(view))
                _assert_only_in(winreg, path, view, (int(view), winreg.REG_DWORD))
                _hklm_delete(winreg, path)
        elif base == "registry_view_set_binary":
            for view in _VIEWS:
                harness.run(view=view, key=path, subkey="Value")
                _assert_only_in(winreg, path, view, (_BINARY, winreg.REG_BINARY))
                _hklm_delete(winreg, path)
        elif base == "registry_view_get":
            views = _VIEWS if _split_views() else (_native_view(),)
            for view in views:
                _hklm_seed(winreg, path, view, view + " view")
            for view in views:
                harness.run(view=view, key=path, subkey="Value").assert_outputs(value=view + " view")
        elif base == "registry_view_remove":
            for view in _VIEWS:
                for seeded in _VIEWS:
                    _hklm_seed(winreg, path, seeded, seeded)
                harness.run(view=view, key=path)
                assert _hklm_value(winreg, path, view) is None, view
                if _split_views():
                    other = "32" if view == "64" else "64"
                    assert _hklm_value(winreg, path, other) == (other, winreg.REG_SZ), view
                _hklm_delete(winreg, path)
        elif base == "registry_pinned_set_string":
            harness.run(key=path, subkey="Value", value="pinned")
            _assert_only_in(winreg, path, "32", ("pinned", winreg.REG_SZ))
        elif base == "registry_pinned_set_binary":
            harness.run(key=path, subkey="Value")
            _assert_only_in(winreg, path, "32", (_BINARY, winreg.REG_BINARY))
        else:
            raise common.unhandled(base)
    finally:
        _hklm_delete(winreg, path)


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
            if kind == "string":
                # Missing values and keys read as empty with the error flag set.
                harness.run(key=path, subkey="Missing", expect_errors=True).assert_outputs(value="")
                harness.run(key=path + "\\Missing", subkey="Value", expect_errors=True).assert_outputs(value="")
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
    elif base.startswith(("registry_view_", "registry_pinned_")):
        _view_case(base, harness)
    elif base.startswith("registry_get_view"):
        (view,) = args
        harness.run().assert_outputs(view=_native_view() if view == "native" else view)
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
