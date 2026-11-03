from tests.includes import common

# Condition cases: whether they match, and the test id of the run (None keeps
# the harness's own).
_CONDITIONS = {
    "if_test": (True, None),
    "if_test_unset": (False, ""),
    "if_test_production": (False, None),
    "if_not_test": (True, ""),
    "if_not_test_set": (False, None),
    "if_not_test_production": (True, None),
}


def run_case(case, harness, args):
    base = common.base(case)
    if base == "test_id":
        harness.run().assert_outputs(value=harness.test_id)
    elif base == "test_id_set":
        assert harness.run(id="updated-test-id").returncode == 0
    elif base == "test_id_init":
        for test_id in ("from-command-line", "with spaces", ""):
            harness.run(test_id=test_id, expect_errors=False).assert_outputs(value=test_id)
    elif base in _CONDITIONS:
        matched, test_id = _CONDITIONS[base]
        harness.run(test_id=test_id).assert_outputs(matched=matched)
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
