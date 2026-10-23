from tests.includes import common

# Condition cases and whether they match.
_CONDITIONS = {
    "if_test": True,
    "if_test_unset": False,
    "if_test_production": False,
    "if_not_test": True,
    "if_not_test_set": False,
    "if_not_test_production": True,
}


def run_case(case, harness, args):
    base = common.base(case)
    if base == "test_id":
        harness.run().assert_outputs(value="framework-test-id")
    elif base == "test_id_set":
        harness.run(id="updated-test-id").assert_outputs(value="updated-test-id")
    elif base in _CONDITIONS:
        harness.run().assert_outputs(matched=_CONDITIONS[base])
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
