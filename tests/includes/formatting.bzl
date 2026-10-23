"""Formatting.nsh cases."""

load(":defs.bzl", "include_api_case")

def formatting_cases():
    cases = []
    for name, symbol, parameters in [
        ("char_to_ascii", "CharToASCII", ["in:character", "out:value:int"]),
        ("hex_to_bin", "Hex2Bin", ["in:value", "out:binary"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "formatting",
            include = "Formatting.nsh",
            symbol = symbol,
            parameters = parameters,
        )

    # GetOptions treats the zero-weight U+00AD as the end of a command line
    # value, so it is compiled in.
    cases += include_api_case(
        name = "char_to_ascii_soft_hyphen",
        api = "formatting",
        include = "Formatting.nsh",
        symbol = "CharToASCII",
        parameters = ["const:character", "out:value:int"],
        constants = {"character": '"${U+00AD}"'},
    )
    return cases
