from tests.includes import common

# Expected stdout for each case; nothing is ever written to stderr.
_STDOUT = {
    "log": "harness log\n",
    "log_debug": "DEBUG: harness log\n",
    "log_info": "INFO: harness log\n",
    "log_warn": "WARN: harness log\n",
    "log_error": "ERROR: harness log\n",
    "log_debug_default_level": "",
    "log_info_default_level": "INFO: harness log\n",
    "log_debug_at_info": "",
    "log_info_at_warn": "",
    "log_warn_at_warn": "WARN: harness log\n",
    "log_warn_at_error": "",
    "log_error_at_error": "ERROR: harness log\n",
    "log_at_error": "harness log\n",
    "log_disabled": "",
    "log_error_disabled": "",
}


def run_case(case, harness, args):
    base = common.base(case)
    if base not in _STDOUT:
        raise common.unhandled(case)
    result = harness.run(text="harness log")
    assert result.stdout == _STDOUT[base], repr(result.stdout)
    assert result.stderr == "", repr(result.stderr)


if __name__ == "__main__":
    common.main(run_case)
