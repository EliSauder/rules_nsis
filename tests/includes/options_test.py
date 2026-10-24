from tests.includes import common


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
            ("a|b|c", "b", True),
            ("a|b|c", "c", True),
            ("a|b|c", "a", True),
            ("a|bb|c", "b", False),
            ("a|b", "B", True),
            ("", "a", False),
            ("a|b", "", False),
            ("single", "single", True),
            ("Alpha|BETA", "beta", True),
            ("a||b", "b", True),
            ("a|b|", "", False),
            ("/at=0|/key=x", "/at=0", True),
            ("a|b", "/at=0", False),
        ]:
            harness.run(list=items, value=value).assert_outputs(found=found)
        # Well over 50 items: first, last, a case variant and a missing one.
    elif base == "option_list_contains_long":
        # 180 items, 899 characters.
        for value, found in [("i000", True), ("i179", True), ("I042", True), ("i180", False), ("i04", False)]:
            harness.run(count=180, value=value).assert_outputs(found=found)
    elif base == "option_list_count":
        for items, count in [("", 0), ("a", 1), ("a|b|c", 3), ("a||b|", 4)]:
            harness.run(list=items).assert_outputs(count=count)
    elif base == "option_list_count_long":
        harness.run(count=180).assert_outputs(count_out=180)
    elif base == "option_list_join":
        for items, joined in [("a", "a"), ("a||b|", "a|b")]:
            harness.run(list=items, expect_errors=False).assert_outputs(joined=joined)
    elif base == "option_list_join_long":
        expected = "|".join(f"i{i:03d}" for i in range(180))
        harness.run(count=180, expect_errors=False).assert_outputs(joined=expected)
    elif base == "option_persist":
        many = "|".join(f"i{i:02d}" for i in range(60))
        for value in ["plain", "", "with|pipe$and\\slash", "C:\\Temp\\x", "a|b|c", many]:
            harness.run(value=value).assert_outputs(result=value)
    elif base == "option_load_missing":
        harness.run(default="kept").assert_outputs(result="kept")
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
