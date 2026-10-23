from tests.includes import common


def run_case(case, harness, args):
    base = common.base(case)
    if base == "char_to_ascii":
        for character, expected in [
            ("A", 65), ("z", 122), ("~", 126), ("ÿ", 255),
            ("λ", 0), ("ab", 0), ("", 0),
        ]:
            harness.run(character=character).assert_outputs(value=expected)
    elif base == "char_to_ascii_soft_hyphen":
        # lstrcmp ignores U+00AD, which previously made empty input return 173.
        harness.run().assert_outputs(value=173)
    elif base == "hex_to_bin":
        for value, expected in [
            ("0123456789ABCDEF", "0000000100100011010001010110011110001001101010111100110111101111"),
            ("f", "1111"), ("a1", "10100001"), ("", ""), ("0x1", "0001"),
        ]:
            harness.run(value=value, expect_errors=False).assert_outputs(binary=expected)
        for value in ("xz", "g", "0x"):
            harness.run(value=value, expect_errors=True).assert_outputs(binary="")
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
