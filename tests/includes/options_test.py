from tests.includes import common

# Joins the items of a list for the harness; see _HARNESS_SEP in the adapters.
_SEP = "~|~"


def _join(items):
    return _SEP.join(items)


_OPTIONS_KEY = "SOFTWARE\\rules_nsis_tests\\Options\\framework-test-id"


def run_case(case, harness, args):
    base = common.base(case)
    if base == "option_round_trip":
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
            ([f"item{i:02}" for i in range(60)], "item59", True),
            ([f"item{i:02}" for i in range(60)], "item60", False),
        ]:
            harness.run(items=_join(items), value=value).assert_outputs(found=found)
    elif base == "option_persist":
        for value in ["plain", "", "with|pipe$and\\slash", "C:\\Temp\\x"]:
            harness.run(value=value).assert_outputs(result=value)
    elif base == "option_persist_kinds":
        import winreg

        try:
            harness.run(items=_join(["a", "b"]), text="l1\\n\\\\x\\n").assert_outputs(count="2", items_out=_join(["a", "b"]), text_out="l1\\n\\\\x\\n")
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, _OPTIONS_KEY) as handle:
                assert winreg.QueryValueEx(handle, "test.b") == (["a", "b"], winreg.REG_MULTI_SZ)
                assert winreg.QueryValueEx(handle, "test.c") == (["l1\r\n\\x\r\n"], winreg.REG_MULTI_SZ)
        finally:
            common.delete_registry_tree(winreg, _OPTIONS_KEY)
        try:
            harness.run(items="", text="t").assert_outputs(count="0", items_out="", text_out="t")
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, _OPTIONS_KEY) as handle:
                assert winreg.QueryValueEx(handle, "test.b") == ([], winreg.REG_MULTI_SZ)
        finally:
            common.delete_registry_tree(winreg, _OPTIONS_KEY)
        many = [f"item{i:02}" for i in range(40)]
        try:
            harness.run(items=_join(many), text="t").assert_outputs(count="40", items_out=_join(many), text_out="t")
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, _OPTIONS_KEY) as handle:
                assert winreg.QueryValueEx(handle, "test.b") == (many, winreg.REG_MULTI_SZ)
        finally:
            common.delete_registry_tree(winreg, _OPTIONS_KEY)
    elif base == "option_load_stored":
        import winreg

        try:
            # Values stored as REG_SZ by older versions are read, then promoted.
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, _OPTIONS_KEY) as handle:
                winreg.SetValueEx(handle, "test.b", 0, winreg.REG_SZ, "x|y")
                winreg.SetValueEx(handle, "test.c", 0, winreg.REG_SZ, "m1\\nm2")
            harness.run().assert_outputs(count="2", items=_join(["x", "y"]), text="m1\\nm2")
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, _OPTIONS_KEY) as handle:
                assert winreg.QueryValueEx(handle, "test.b") == (["x", "y"], winreg.REG_MULTI_SZ)
                assert winreg.QueryValueEx(handle, "test.c") == (["m1\r\nm2"], winreg.REG_MULTI_SZ)
            harness.run().assert_outputs(count="2", items=_join(["x", "y"]), text="m1\\nm2")
        finally:
            common.delete_registry_tree(winreg, _OPTIONS_KEY)
    elif base == "option_load_missing":
        harness.run(default="kept").assert_outputs(result="kept")
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
