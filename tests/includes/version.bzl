"""Version.nsh cases."""

load(":defs.bzl", "include_api_case")

def version_cases():
    cases = []
    for name, kind in [("version_compare", "definition"), ("version_compare_call", "macro")]:
        cases += include_api_case(
            name = name,
            api = "version",
            include = "Version.nsh",
            symbol = "VersionCompare",
            kind = kind,
            parameters = ["in:first", "in:second", "out:comparison:int"],
        )
    return cases
