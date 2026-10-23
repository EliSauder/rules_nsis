from tests.includes import common

# Cases with a compiled-in value, and their expected result.
_CONSTANT = {
    "trim_quotes_quoted": "quoted value",
    "trim_quotes_empty": "",
    "trim_quotes_left_only": "left only",
    "trim_quotes_right_only": "right only",
}


def run_case(case, harness, args):
    base = common.base(case)
    if base == "trim_quotes":
        for value in ("plain value", ""):
            harness.run(value=value).assert_outputs(result=value)
    elif base in _CONSTANT:
        harness.run().assert_outputs(result=_CONSTANT[base])
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
