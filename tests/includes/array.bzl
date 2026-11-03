"""Array.nsh cases."""

load(":defs.bzl", "include_api_case")

def array_cases():
    cases = []
    for name, symbol, parameters in [
        ("array_missing", "HarnessArrayMissing", ["out:count", "out:item", "out:item_missing:bool", "out:joined", "out:key_missing:bool"]),
        ("array_items", "HarnessArrayItems", ["in:a", "in:b", "out:count", "out:first", "out:second", "out:joined", "out:named"]),
        ("array_copy", "HarnessArrayCopy", ["in:a", "in:b", "out:copy_count", "out:copy_joined", "out:source_count", "out:named", "out:missing_count", "out:text", "out:text_missing"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "array",
            include = "Array.nsh",
            src = "array_adapters.nsh",
            symbol = symbol,
            parameters = parameters,
            contexts = ["installer"],
        )
    return cases
