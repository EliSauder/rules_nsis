"""Guid.nsh cases."""

load(":defs.bzl", "include_api_case")

def guid_cases():
    return include_api_case(
        name = "normalize_guid",
        api = "guid",
        include = "Guid.nsh",
        symbol = "NormalizeGuid",
        parameters = ["in:value", "out:result"],
    )
