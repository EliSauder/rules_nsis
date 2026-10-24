"""Cli.nsh cases."""

load(":defs.bzl", "include_api_case")

def cli_cases():
    cases = include_api_case(
        name = "cli_init",
        api = "cli",
        include = "Cli.nsh",
        symbol = "Cli_Init",
    )
    cases += include_api_case(
        name = "cli_arg_count",
        api = "cli",
        include = "Cli.nsh",
        symbol = "Cli_ArgCount",
        parameters = ["out:count:int"],
    )
    cases += include_api_case(
        name = "cli_get_arg",
        api = "cli",
        include = "Cli.nsh",
        symbol = "Cli_GetArg",
        parameters = ["in:index:int", "out:value"],
    )
    cases += include_api_case(
        name = "cli_has_arg",
        api = "cli",
        include = "Cli.nsh",
        symbol = "Cli_HasArg",
        kind = "condition",
        parameters = ["const:name", "out:matched:bool"],
        constants = {"name": '"/Flag"'},
    )

    # The harness passes the case's arguments on the real command line, and the
    # tests append the args under test, all named /x.
    for name, symbol in [
        ("cli_get_arg_value", "Cli_GetArgValue"),
        ("cli_get_arg_bool", "Cli_GetArgBool"),
        ("cli_get_arg_int", "Cli_GetArgInt"),
    ]:
        cases += include_api_case(
            name = name,
            api = "cli",
            include = "Cli.nsh",
            symbol = symbol,
            parameters = ["const:name", "out:value"],
            constants = {"name": '"/x"'},
        )

    # The same macro serves both contexts.
    for name, defines in [
        ("cli_fail", {}),
        ("cli_fail_logging_enabled", {"LOGGING_ENABLE": ""}),
    ]:
        cases += include_api_case(
            name = name,
            api = "cli",
            include = "Cli.nsh",
            symbol = "Cli_Fail",
            un_symbol = "Cli_Fail",
            parameters = ["in:message"],
            defines = defines,
        )
    return cases
