from tests.includes import common


def run_case(case, harness, args):
    base = common.base(case)
    if base == "option_round_trip":
        harness.run(value="C:\\Program Files\\App $x").assert_outputs(result="C:\\Program Files\\App $x")
    elif base == "option_is_set":
        harness.run(value="1").assert_outputs(set=True)
        harness.run(value="0").assert_outputs(set=False)
        harness.run(value="").assert_outputs(set=False)
    elif base == "option_list_contains":
        for items, value, found in [
            ("a|b|c", "b", True),
            ("a|b|c", "c", True),
            ("a|b|c", "a", True),
            ("a|bb|c", "b", False),
            ("a|b", "B", True),
            ("", "a", False),
            ("a|b", "", False),
            ("single", "single", True),
        ]:
            harness.run(list=items, value=value).assert_outputs(found=found)
    elif base == "option_persist":
        for value in ["plain", "", "with | pipe and spaces", "C:\\Temp\\x"]:
            harness.run(value=value).assert_outputs(result=value)
    elif base == "option_load_missing":
        harness.run(default="kept").assert_outputs(result="kept")
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
