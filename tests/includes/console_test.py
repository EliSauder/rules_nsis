from tests.includes import common


def run_case(case, harness, args):
    base = common.base(case)
    if base == "console_init":
        result = harness.run()
        assert result.stdout == "", repr(result.stdout)
    elif base == "console_write":
        result = harness.run(text="harness text")
        assert result.stdout == "harness text", repr(result.stdout)
    elif base in ("console_write_line", "console_write_line_logging_enabled"):
        result = harness.run(text="harness line")
        assert result.stdout == "harness line\n", repr(result.stdout)
    elif base == "console_is_available":
        # The harness redirects stdout, so a handle is always inherited.
        result = harness.run()
        result.assert_outputs(available=True)
    else:
        raise common.unhandled(case)
    assert result.stderr == "", repr(result.stderr)


if __name__ == "__main__":
    common.main(run_case)
