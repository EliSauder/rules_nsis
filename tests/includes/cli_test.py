from tests.includes import common

def run_case(case, harness, args):
    base = common.base(case)
    if base == "cli_init":
        harness.run(expect_errors=False)
    elif base == "cli_arg_count":
        count = harness.run().outputs["count"]
        # Quotes group an arg, so an empty or spaced arg still counts once.
        extra = ["a", '"b c"', "d=e", '""', 'f"g h"i']
        harness.run(command_args=extra).assert_outputs(count=count + len(extra))
        # NSIS consumes /D= and everything after it before the script runs.
        harness.run(command_tail=["/D=C:\\Program Files\\x y"]).assert_outputs(count=count)
    elif base == "cli_get_arg":
        extra = ["plain", '"two words"', 'a"b c"d', '""', "/n=1", "last"]
        expected = ["plain", "two words", "ab cd", "", "/n=1", "last"]
        # The harness command line follows the args: /S, /output=..., then one
        # arg per input.
        for offset, value in enumerate(expected):
            harness.run(
                index=offset, command_args=extra, expect_errors=False
            ).assert_outputs(value=value)
        after = len(extra)
        harness.run(index=after, command_args=extra, expect_errors=False).assert_outputs(value="/S")
        harness.run(index=after + 2, command_args=extra, expect_errors=False).assert_outputs(
            value=f"/index={after + 2}"
        )
        harness.run(index=1000, expect_errors=True).assert_outputs(value="")
        harness.run(index=-1, expect_errors=True).assert_outputs(value="")
    elif base == "cli_has_arg":
        for arguments, expected in [
            ([], False),
            (["/Flag"], True),
            (["/FLAG"], True),
            (["/flag=value"], True),
            (["/flag="], True),
            (['"/flag=a b"'], True),
            (["/flags"], False),
            (["/fla"], False),
            (["Flag"], False),
            (["/other=/flag"], False),
        ]:
            harness.run(command_args=arguments).assert_outputs(matched=expected)
    elif base == "cli_get_arg_value":
        for arguments, expected in [
            (["/x=value"], "value"),
            (["/X=value"], "value"),
            (["/x="], ""),
            (["/x=a=b"], "a=b"),
            (['/x="with spaces"'], "with spaces"),
            (['"/x=with spaces"'], "with spaces"),
            (['/x=a"b c"d'], "ab cd"),
            (["/x=one", "/x=two", "/X=three"], "three"),
            (["/x=one", "/x"], ""),
            (["/x", "/x=two"], "two"),
        ]:
            # A bare /x leaves no value even when an earlier one had it.
            bare_last = arguments[-1] == "/x"
            harness.run(command_args=arguments, expect_errors=bare_last).assert_outputs(value=expected)
        for arguments in ([], ["/x"], ["/xy=1"], ["/y=1"], ["x=1"]):
            harness.run(command_args=arguments, expect_errors=True).assert_outputs(value="")
    elif base == "cli_get_arg_bool":
        for value, expected in [
            ("1", "1"), ("true", "1"), ("Yes", "1"), ("y", "1"), ("t", "1"), ("ON", "1"),
            ("0", "0"), ("false", "0"), ("No", "0"), ("n", "0"), ("f", "0"), ("off", "0"),
        ]:
            harness.run(command_args=[f"/x={value}"], expect_errors=False).assert_outputs(value=expected)
        # A bare switch is on.
        harness.run(command_args=["/x"], expect_errors=False).assert_outputs(value="1")
        harness.run(command_args=["/x=0", "/x"], expect_errors=False).assert_outputs(value="1")
        harness.run(command_args=["/x", "/x=off"], expect_errors=False).assert_outputs(value="0")
        for arguments in ([], ["/x="], ["/x=maybe"], ["/x=2"], ["/y"]):
            harness.run(command_args=arguments, expect_errors=True).assert_outputs(value="")
    elif base == "cli_get_arg_int":
        for value, expected in [
            ("0", "0"), ("42", "42"), ("+7", "7"), ("-7", "-7"), ("007", "7"),
            ("2147483647", "2147483647"), ("-2147483648", "-2147483648"),
        ]:
            harness.run(command_args=[f"/x={value}"], expect_errors=False).assert_outputs(value=expected)
        harness.run(command_args=["/x=1", "/x=2"], expect_errors=False).assert_outputs(value="2")
        for arguments in (
            [], ["/x"], ["/x="], ["/x=abc"], ["/x=1.5"], ["/x=2147483648"],
            ["/x=1", "/x=bad"], ["/y=1"],
        ):
            harness.run(command_args=arguments, expect_errors=True).assert_outputs(value="")
    elif base in ("cli_fail", "cli_fail_logging_enabled"):
        result = harness.run(message="something went wrong", expected_exitcode=2)
        # Logging also writes the message, but only once.
        assert result.stdout == "ERROR: something went wrong\n", repr(result.stdout)
        assert result.outputs == {}, result.outputs
        return
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
