"""Shortcut.nsh cases."""

load(":defs.bzl", "include_api_case")

def shortcut_cases():
    cases = []
    for name, symbol, parameters in [
        ("shortcut_get_target", "Shortcut_GetTarget", ["in:link", "out:target"]),
        ("shortcut_remove_if_owned", "Shortcut_RemoveIfOwned", ["in:link", "in:prefix"]),
        ("shortcut_remove_empty_dirs", "Shortcut_RemoveEmptyDirs", ["in:directory", "in:stop_at"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "shortcut",
            include = "Shortcut.nsh",
            symbol = symbol,
            parameters = parameters,
        )

    # CreateShortCut only accepts a literal icon index.
    cases += include_api_case(
        name = "shortcut_create",
        api = "shortcut",
        include = "Shortcut.nsh",
        symbol = "Shortcut_Create",
        parameters = ["in:link", "in:target", "in:arguments", "in:icon", "const:icon_index", "in:description"],
        constants = {"icon_index": "0"},
    )
    return cases
