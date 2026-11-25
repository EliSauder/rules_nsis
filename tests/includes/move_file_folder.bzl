"""MoveFileFolder.nsh cases."""

load(":defs.bzl", "include_api_case")

def move_file_folder_cases():
    cases = []
    for name, symbol, parameters in [
        ("move_file", "MoveFile", ["in:source", "in:destination"]),
        ("move_folder", "MoveFolder", ["in:source", "in:destination", "in:mask"]),
        ("move_file_paths", "MoveFile", ["in:source", "in:destination"]),
        ("move_file_invalid", "MoveFile", ["in:source", "in:destination"]),
        ("move_file_locked", "HarnessMoveFileLocked", ["in:source", "in:destination", "in:locked"]),
        ("move_folder_paths", "MoveFolder", ["in:source", "in:destination", "in:mask"]),
        ("move_folder_invalid", "MoveFolder", ["in:source", "in:destination", "in:mask"]),
        ("move_folder_merge", "MoveFolder", ["in:source", "in:destination", "in:mask"]),
        ("move_file_aliases", "MoveFile", ["in:source", "in:destination"]),
        ("move_folder_aliases", "MoveFolder", ["in:source", "in:destination", "in:mask"]),
        ("move_file_case_sensitive", "MoveFile", ["in:source", "in:destination"]),
        ("move_folder_case_sensitive", "MoveFolder", ["in:source", "in:destination", "in:mask"]),
    ]:
        # $switch_overwrite replaces existing destinations regardless of age.
        for suffix, on_init in [("", []), ("_overwrite", ["StrCpy $switch_overwrite 1"])]:
            cases += include_api_case(
                name = name + suffix,
                api = "move_file_folder",
                include = "MoveFileFolder.nsh",
                symbol = symbol,
                parameters = parameters,
                on_init = on_init,
                src = "move_file_folder_adapters.nsh" if name == "move_file_locked" else None,
            )

    # Repeated expansions in one function must still compile and run.
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
    cases += include_api_case(
        name = "move_folder_cleanup_failure",
        api = "move_file_folder",
        include = "MoveFileFolder.nsh",
        src = "move_file_folder_adapters.nsh",
        symbol = "HarnessMoveFolderCleanupFailure",
        parameters = ["in:source", "out:removed:int"],
    )
    cases += include_api_case(
        name = "move_folder_locked_directory",
        api = "move_file_folder",
        include = "MoveFileFolder.nsh",
        src = "move_file_folder_adapters.nsh",
        symbol = "HarnessMoveFolderLockedDirectory",
        parameters = ["in:source", "in:destination"],
    )
    for kind in ["File", "Folder"]:
        cases += include_api_case(
            name = "move_" + kind.lower() + "_recovery",
            api = "move_file_folder",
            include = "MoveFileFolder.nsh",
            src = "move_file_folder_adapters.nsh",
            symbol = "HarnessMove" + kind + "Recovery",
            parameters = ["in:source", "in:destination", "out:first_failed:bool"],
        )
    for kind in ["File", "Folder"]:
        cases += include_api_case(
            name = "move_" + kind.lower() + "_cross_volume",
            api = "move_file_folder",
            include = "MoveFileFolder.nsh",
            src = "move_file_folder_adapters.nsh",
            symbol = "HarnessMove" + kind + "Locked",
            parameters = ["in:source", "in:destination", "in:locked"],
        )
        cases += include_api_case(
            name = "move_" + kind.lower() + "_copy_only",
            api = "move_file_folder",
            include = "MoveFileFolder.nsh",
            src = "move_file_folder_copy_only_adapters.nsh",
            symbol = "Move" + kind,
            parameters = ["in:source", "in:destination"] + (["in:mask"] if kind == "Folder" else []),
        )
    return cases
