from tests.includes import common


def run_case(case, harness, args):
    base = common.base(case)
    if base == "array_missing":
        harness.run().assert_outputs(count="0", item="", item_missing=True, joined="", key_missing=True)
    elif base == "array_items":
        harness.run(a="x", b="y").assert_outputs(count="2", first="x", second="y", joined="x,y", named="x")
    elif base == "array_copy":
        harness.run(a="x", b="y").assert_outputs(
            copy_count="2", copy_joined="x,y", source_count="3", named="x",
            missing_count="0", text="0 => x, 1 => y, 2 => z", text_missing="",
        )
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
