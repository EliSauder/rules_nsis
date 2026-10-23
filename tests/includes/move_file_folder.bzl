"""MoveFileFolder.nsh cases."""

load(":defs.bzl", "include_api_case")

def move_file_folder_cases():
    cases = []
    for name, symbol, parameters in [
        ("move_file", "MoveFile", ["in:source", "in:destination"]),
        ("move_folder", "MoveFolder", ["in:source", "in:destination", "in:mask"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "move_file_folder",
            include = "MoveFileFolder.nsh",
            symbol = symbol,
            parameters = parameters,
        )

    # MoveFile derives its labels from the call site, so repeated expansions in
    # one function must still compile and run.
    cases += include_api_case(
        name = "move_file_twice",
        api = "move_file_folder",
        include = "MoveFileFolder.nsh",
        src = "move_file_folder_adapters.nsh",
        symbol = "HarnessMoveFileTwice",
        parameters = [
            "in:first_source",
            "in:first_destination",
            "in:second_source",
            "in:second_destination",
        ],
    )
    return cases
