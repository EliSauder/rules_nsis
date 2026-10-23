"""Console.nsh cases."""

load(":defs.bzl", "include_api_case")

def console_cases():
    cases = []
    for name, symbol, kind, parameters in [
        ("console_init", "Console_Init", "macro", []),
        ("console_write", "Console_Write", "macro", ["in:text"]),
        ("console_write_line", "Console_WriteLine", "macro", ["in:text"]),
        ("console_is_available", "Console_IsAvailable", "condition", ["out:available:bool"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "console",
            include = "Console.nsh",
            symbol = symbol,
            un_symbol = symbol,
            kind = kind,
            parameters = parameters,
        )

    # Console output does not depend on logging being enabled.
    cases += include_api_case(
        name = "console_write_line_logging_enabled",
        api = "console",
        include = "Console.nsh",
        symbol = "Console_WriteLine",
        un_symbol = "Console_WriteLine",
        parameters = ["in:text"],
        defines = {"LOGGING_ENABLE": ""},
    )
    return cases
