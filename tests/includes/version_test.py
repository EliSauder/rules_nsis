from tests.includes import common


def run_case(case, harness, args):
    if common.base(case) not in ("version_compare", "version_compare_call"):
        raise common.unhandled(case)
    for first, second, expected in [
        ("1.2.3", "1.2.4", -1), ("1.2.4", "1.2.3", 1),
        ("1.2.3", "1.2.3", 0), ("01.002", "1.2", 0), ("1.05", "1.5", 0),
        ("1.10", "1.9", 1), ("1.9", "1.10", -1), ("2", "10", -1),
        ("1.2", "1.2.0", 0), ("1.2.0.0", "1.2", 0), ("1.0.1", "1", 1), ("1", "1.0.1", -1),
        ("0", "0.0", 0), ("1.99999999999", "1.100000000000", -1),
        ("1.100000000000", "1.099999999999", 1),
    ]:
        harness.run(first=first, second=second).assert_outputs(comparison=expected)


if __name__ == "__main__":
    common.main(run_case)
