from tests.includes import common


def run_case(case, harness, args):
    if common.base(case) not in ("log", "log_debug", "log_info", "log_warn", "log_error"):
        raise common.unhandled(case)
    assert harness.run(text="harness log").returncode == 0


if __name__ == "__main__":
    common.main(run_case)
