from tests.includes import common


def run_case(case, harness, args):
    base = common.base(case)
    if base == "array_missing":
        harness.run().assert_outputs(count="0", item="", item_missing=True, joined="", key_missing=True)
    elif base == "array_items":
        harness.run(a="x", b="y").assert_outputs(count="2", first="x", second="y", joined="x,y", named="x")
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
