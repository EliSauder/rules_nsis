"""Mutex.nsh cases."""

load(":defs.bzl", "include_api_case")

def mutex_cases():
    return include_api_case(
        name = "mutex",
        api = "mutex",
        include = "Mutex.nsh",
        symbol = "ValidateMutex",
        parameters = ["in:name"],
    )
