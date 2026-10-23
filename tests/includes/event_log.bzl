"""EventLog.nsh cases. Event sources live under HKLM, so these need admin."""

load(":defs.bzl", "include_api_case")

_TEST_ID = ['${SetTestId} "framework-test-id"']

def event_log_cases():
    cases = []
    for name, symbol, parameters in [
        ("eventlog_add_source", "EventLog_AddSource", [
            "in:key",
            "in:source",
            "in:types:int",
            "in:event_file",
            "in:category_file",
            "in:parameter_file",
        ]),
        ("eventlog_remove_source", "EventLog_RemoveSource", ["in:key", "in:source"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "event_log",
            include = "EventLog.nsh",
            symbol = symbol,
            parameters = parameters,
            on_init = _TEST_ID,
        )
    return cases
