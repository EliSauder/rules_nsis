from tests.includes import common

# Values that must survive untouched: quotes, line breaks, non-ASCII, and
# characters that are special to the registry, the command line or NSIS.
_TRICKY = ['say "hi"', "line1\r\nline2", "line1\nline2", "\u03bb \U0001f600", "100% $x ${y} $$", "a,b|c", " pad ", "C:\\dir\\"]


_OPTIONS_KEY = "SOFTWARE\\rules_nsis_tests\\Options"


def stored_scalar(winreg, kind, value):
    if kind == "bool":
        return bytes([int(value)]), winreg.REG_BINARY
    if kind in ("int", "int32"):
        return int(value) & 0xFFFFFFFF, winreg.REG_DWORD
    if kind == "int64":
        return int(value) & 0xFFFFFFFFFFFFFFFF, winreg.REG_QWORD
    return value, winreg.REG_SZ


def run_case(case, harness, args):
    base = common.base(case)
    if base == "option_persist_typed":
        import winreg

        key = common.scoped(harness, _OPTIONS_KEY)
        try:
            for kind, values in [
                ("bool", ["0", "1"]),
                ("int", ["-2147483648", "-1", "0", "2147483647"]),
                ("int32", ["-2147483648", "2147483647"]),
                ("int64", ["-9223372036854775808", "-1", "0", "4294967296", "9223372036854775807"]),
                ("string", ["", *_TRICKY]),
                ("multiline", ["", "first\\nsecond", "literal\\\\n"]),
                ("file", ["", r"C:\with spaces\file.txt", r"%TEMP%\file.txt"]),
                ("dir", ["", r"C:\with spaces", r"%TEMP%\data"]),
            ]:
                for value in values:
                    harness.run(kind=kind, value=value).assert_outputs(result=value)
                    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key) as handle:
                        assert winreg.QueryValueEx(handle, "typed.value") == stored_scalar(winreg, kind, value)
        finally:
            common.delete_registry_tree(winreg, key)
    elif base == "option_load_typed":
        import winreg

        key = common.scoped(harness, _OPTIONS_KEY)
        try:
            for kind, value in [
                ("bool", "0"), ("bool", "1"), ("int32", "-2147483648"),
                ("int32", "2147483647"), ("int64", "-9223372036854775808"),
                ("int64", "9223372036854775807"), ("string", ""),
                ("file", r"%TEMP%\literal.txt"), ("multiline", "a\\nb\\\\c"),
            ]:
                expected, expected_type = stored_scalar(winreg, kind, value)
                legacy_multi = ["a\r\nb\\c"] if kind == "multiline" else [value]
                for data, registry_type in [
                    (expected, expected_type),
                    (value, winreg.REG_SZ),
                    (legacy_multi, winreg.REG_MULTI_SZ),
                ]:
                    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, key) as handle:
                        winreg.SetValueEx(handle, "typed.value", 0, registry_type, data)
                    harness.run(kind=kind, default="not the stored value").assert_outputs(result=value)
                    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key) as handle:
                        stored = winreg.QueryValueEx(handle, "typed.value")
                    assert stored == ((data, registry_type) if case.startswith("un_") else (expected, expected_type))
            for kind, data, registry_type in [
                ("bool", b"\x02", winreg.REG_BINARY),
                ("bool", b"\x01\x00", winreg.REG_BINARY),
                ("int32", b"\x01", winreg.REG_BINARY),
                ("int64", 1, winreg.REG_DWORD),
                ("string", 1, winreg.REG_DWORD),
            ]:
                with winreg.CreateKey(winreg.HKEY_CURRENT_USER, key) as handle:
                    winreg.SetValueEx(handle, "typed.value", 0, registry_type, data)
                harness.run(kind=kind, default="kept").assert_outputs(result="kept")
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key) as handle:
                    assert winreg.QueryValueEx(handle, "typed.value") == (data, registry_type)
        finally:
            common.delete_registry_tree(winreg, key)
    elif base == "option_round_trip":
        harness.run(value="C:\\App\\$x|y").assert_outputs(result="C:\\App\\$x|y")
    elif base == "option_is_set":
        harness.run(value="1").assert_outputs(set=True)
        harness.run(value="0").assert_outputs(set=False)
        harness.run(value="").assert_outputs(set=False)
    elif base == "option_list_contains":
        for items, value, found in [
            (["a", "b", "c"], "b", True),
            (["a", "b", "c"], "c", True),
            (["a", "b", "c"], "a", True),
            (["a", "bb", "c"], "b", False),
            (["a", "b"], "B", True),
            ([], "a", False),
            (["a", "b"], "", False),
            (["single"], "single", True),
            (["x|y"], "x", False),
            (_TRICKY, 'say "hi"', True),
            (_TRICKY, "line1\r\nline2", True),
            (_TRICKY, "\u03bb \U0001f600", True),
            (_TRICKY, "line1", False),
            (_TRICKY, "a", False),
            ([f"item{i:02}" for i in range(600)], "item599", True),
            ([f"item{i:02}" for i in range(600)], "item600", False),
        ]:
            harness.run(items=items, value=value).assert_outputs(found=found)
        harness.run(items=[], value='"').assert_outputs(found=False)
        harness.run(items=['"', "\n"], value="\n").assert_outputs(found=True)
    elif base == "option_persist":
        for value in ["plain", "", "with|pipe$and\\slash", "C:\\Temp\\x", *_TRICKY]:
            harness.run(value=value).assert_outputs(result=value)
    elif base == "option_persist_kinds":
        import winreg

        key = common.scoped(harness, _OPTIONS_KEY)
        text = "l1\\n\\\\x\\n"
        for items in [["a", "b"], _TRICKY, [f"item{i:03}" for i in range(500)]]:
            try:
                harness.run(items=items, text=text).assert_outputs(count=str(len(items)), items_out=items, text_out=text)
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key) as handle:
                    assert winreg.QueryValueEx(handle, "test.b") == (items, winreg.REG_MULTI_SZ)
                    assert winreg.QueryValueEx(handle, "test.c") == (text, winreg.REG_SZ)
            finally:
                common.delete_registry_tree(winreg, _OPTIONS_KEY + "\\" + harness.test_id)
        try:
            harness.run(items=[], text="t").assert_outputs(count="0", items_out=[], text_out="t")
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key) as handle:
                assert winreg.QueryValueEx(handle, "test.b") == ([], winreg.REG_MULTI_SZ)
        finally:
            common.delete_registry_tree(winreg, _OPTIONS_KEY + "\\" + harness.test_id)
    elif base == "option_load_stored":
        import winreg

        key = common.scoped(harness, _OPTIONS_KEY)
        try:
            # Legacy list strings are promoted; scalar REG_SZ stays REG_SZ.
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, key) as handle:
                winreg.SetValueEx(handle, "test.b", 0, winreg.REG_SZ, "x|y")
                winreg.SetValueEx(handle, "test.c", 0, winreg.REG_SZ, "m1\\nm2")
            harness.run().assert_outputs(count="2", items=["x", "y"], text="m1\\nm2")
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key) as handle:
                assert winreg.QueryValueEx(handle, "test.b") == (["x", "y"], winreg.REG_MULTI_SZ)
                assert winreg.QueryValueEx(handle, "test.c") == ("m1\\nm2", winreg.REG_SZ)
            harness.run().assert_outputs(count="2", items=["x", "y"], text="m1\\nm2")
        finally:
            common.delete_registry_tree(winreg, _OPTIONS_KEY + "\\" + harness.test_id)
    elif base == "option_load_missing":
        harness.run(default="kept").assert_outputs(result="kept")
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
