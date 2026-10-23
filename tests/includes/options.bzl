"""Options.nsh cases."""

load(":defs.bzl", "include_api_case")

_TEST_ID = ['${SetTestId} "framework-test-id"']

def options_cases():
    cases = []
    for name, symbol, parameters in [
        ("option_round_trip", "HarnessOptionRoundTrip", ["in:value", "out:result"]),
        ("option_is_set", "HarnessOptionIsSet", ["in:value", "out:set:bool"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "options",
            include = "Options.nsh",
            src = "options_adapters.nsh",
            symbol = symbol,
            un_symbol = symbol,
            parameters = parameters,
        )
    cases += include_api_case(
        name = "option_list_contains",
        api = "options",
        include = "Options.nsh",
        src = "options_adapters.nsh",
        symbol = "HarnessOptionListContains",
        parameters = ["in:list", "in:value", "out:found:bool"],
    )
    cases += include_api_case(
        name = "option_persist",
        api = "options",
        include = "Options.nsh",
        src = "options_adapters.nsh",
        symbol = "HarnessOptionPersist",
        parameters = ["in:value", "out:result"],
        contexts = ["installer"],
        on_init = _TEST_ID,
    )
    cases += include_api_case(
        name = "option_load_missing",
        api = "options",
        include = "Options.nsh",
        src = "options_adapters.nsh",
        symbol = "HarnessOptionLoadMissing",
        parameters = ["in:default", "out:result"],
        on_init = _TEST_ID,
    )
    return cases
