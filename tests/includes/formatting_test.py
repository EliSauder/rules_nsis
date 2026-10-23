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
    elif base == "parse_bool":
        for value, expected in [
            ("1", "1"), ("true", "1"), ("t", "1"), ("yes", "1"), ("y", "1"), ("on", "1"),
            ("0", "0"), ("false", "0"), ("f", "0"), ("no", "0"), ("n", "0"), ("off", "0"),
            ("TRUE", "1"), ("Yes", "1"), ("ON", "1"), ("False", "0"), ("OfF", "0"),
        ]:
            harness.run(value=value, expect_errors=False).assert_outputs(result=expected)
        for value in ("", "2", "-1", "maybe", "truee", "tr", "yess", "of", "10"):
            harness.run(value=value, expect_errors=True).assert_outputs(result="")
    elif base == "parse_int":
        for value, expected in [
            ("0", "0"), ("7", "7"), ("+7", "7"), ("-7", "-7"), ("007", "7"), ("-007", "-7"),
            ("+0", "0"), ("-0", "0"), ("000", "0"), ("12345", "12345"),
            ("2147483647", "2147483647"), ("+2147483647", "2147483647"),
            ("-2147483648", "-2147483648"), ("0002147483647", "2147483647"),
            ("2147483639", "2147483639"), ("-2147483647", "-2147483647"),
        ]:
            harness.run(value=value, expect_errors=False).assert_outputs(result=expected)
        for value in (
            "", "+", "-", "--1", "+-1", "1.5", "1a", "a1", "0x10", "1,000",
            "2147483648", "-2147483649", "3000000000", "99999999999", "2147483650",
        ):
            harness.run(value=value, expect_errors=True).assert_outputs(result="")
    elif base == "parse_date":
        for value in (
            "2024-01-31", "2023-02-28", "2024-02-29", "2000-02-29", "1601-01-01",
            "9999-12-31", "2023-04-30", "2023-12-01",
        ):
            harness.run(value=value, expect_errors=False).assert_outputs(result=value)
        for value in (
            "", "2023-02-29", "1900-02-29", "2100-02-29", "2024-02-30", "2023-04-31",
            "2023-13-01", "2023-00-10", "2023-01-00", "2023-01-32", "1600-12-31",
            "0000-01-01", "2023-1-01", "2023-01-1", "20230101", "2023/01/01",
            "2023-01-011", "202a-01-01", "2023-01-0a", "+023-01-01",
        ):
            harness.run(value=value, expect_errors=True).assert_outputs(result="")
    elif base == "parse_ipv4":
        for value, expected in [
            ("0.0.0.0", "0.0.0.0"), ("255.255.255.255", "255.255.255.255"),
            ("192.168.1.10", "192.168.1.10"), ("010.001.000.099", "10.1.0.99"),
            ("1.2.3.4", "1.2.3.4"), ("000.0.0.0", "0.0.0.0"),
        ]:
            harness.run(value=value, expect_errors=False).assert_outputs(result=expected)
        for value in (
            "", "1.2.3", "1.2.3.4.5", "256.1.1.1", "1.1.1.256", "1.2.3.", ".1.2.3",
            "1..2.3", "a.b.c.d", "1.2.3.-4", "1000.1.1.1", "0001.1.1.1",
            "1.2.3.4a", "1,2,3,4",
        ):
            harness.run(value=value, expect_errors=True).assert_outputs(result="")
    elif base == "parse_net_address":
        v4, v4_service, v4_network = 0x1, 0x2, 0x4
        v6, v6_service, v6_network = 0x8, 0x20, 0x80
        named = 0x100
        for value, flags in [
            ("192.168.1.10", v4), ("192.168.1.10:80", v4_service), ("10.0.0.0/8", v4_network),
            ("::1", v6), ("[::1]:443", v6_service), ("fe80::/10", v6_network),
            ("example.com", named), ("192.168.1.10", v4 | v6), ("::1", v4 | v6),
        ]:
            harness.run(value=value, flags=flags, expect_errors=False).assert_outputs(result=value)
        for value, flags in [
            ("", v4), ("not_an_address!", v4 | v6), ("999.1.1.1", v4),
            ("::1", v4), ("192.168.1.10", v6), ("192.168.1.10:80", v4),
            ("10.0.0.0/8", v4), ("example.com", v4 | v6),
        ]:
            harness.run(value=value, flags=flags, expect_errors=True).assert_outputs(result="")
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
