"""Logging.nsh cases."""

load(":defs.bzl", "include_api_case")

def logging_cases():
    cases = []
    for name, symbol in [
        ("log", "Log"),
        ("log_debug", "LogDebug"),
        ("log_info", "LogInfo"),
        ("log_warn", "LogWarn"),
        ("log_error", "LogError"),
    ]:
        cases += include_api_case(
            name = name,
            api = "logging",
            include = "Logging.nsh",
            symbol = symbol,
            un_symbol = symbol,
            parameters = ["in:text"],
        )
    return cases
