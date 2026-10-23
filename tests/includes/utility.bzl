"""Utility.nsh cases."""

load(":defs.bzl", "include_api_case")

def utility_cases():
    cases = include_api_case(
        name = "trim_quotes",
        api = "utility",
        include = "Utility.nsh",
        symbol = "TrimQuotes",
        parameters = ["in:value", "out:result"],
    )

    # The runner rejects quotes in run-time inputs, so quoted values are compiled in.
    for name, value in [
        ("trim_quotes_quoted", '"$\\"quoted value$\\""'),
        ("trim_quotes_empty", '"$\\"$\\""'),
        ("trim_quotes_left_only", '"$\\"left only"'),
        ("trim_quotes_right_only", '"right only$\\""'),
    ]:
        cases += include_api_case(
            name = name,
            api = "utility",
            include = "Utility.nsh",
            symbol = "TrimQuotes",
            parameters = ["const:value", "out:result"],
            constants = {"value": value},
        )
    return cases
