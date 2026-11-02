"""Ini.nsh cases."""

load(":defs.bzl", "include_api_case")

def ini_cases():
    cases = []
    for name, symbol, parameters in [
        ("ini_read_list", "HarnessIniReadList", ["in:file", "in:section", "in:key", "out:count", "out:first", "out:second", "out:missing:bool"]),
        ("ini_read_str", "HarnessIniReadStr", ["in:file", "in:section", "in:key", "out:value", "out:missing:bool"]),
        ("ini_names", "HarnessIniNames", ["in:file", "in:section", "out:sections", "out:keys"]),
        ("ini_format_list", "HarnessIniFormatList", ["in:a", "in:b", "in:key", "in:out_file"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "ini",
            include = "Ini.nsh",
            src = "ini_adapters.nsh",
            symbol = symbol,
            parameters = parameters,
            contexts = ["installer"],
        )
    return cases
