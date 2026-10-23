load("@rules_python//python:py_test.bzl", "py_test")
load("//nsis/testing:defs.bzl", "nsis_symbol", "nsis_test_harness")

_PAIRED = [
    ("arch_get", "GetArch", ["out:arch"]),
    ("arch_detect", "DetectArch", []),
    ("arch_is_64_bit", "Is64Bit", ["out:value:bool"]),
    ("arch_is_32_bit", "Is32Bit", ["out:value:bool"]),
    ("arch_validate", "ValidateArch", ["in:expected"]),
    ("arch_validate_bitwidth", "ValidateBitwidth", ["in:bits:int"]),
    ("arch_validate_isa", "ValidateISA", ["in:isa"]),
    ("arch_reg_view", "DefineRegView", []),
    ("char_to_ascii", "CharToASCII", ["in:character", "out:value:int"]),
    ("hex_to_bin", "Hex2Bin", ["in:value", "out:binary"]),
    ("format_str_to_bin", "FormatStrToBin", ["in:value", "in:is_int:bool", "out:binary"]),
    ("format_str_to_dword", "FormatStrToDWORD", ["in:value", "out:result"]),
    ("normalize_guid", "NormalizeGuid", ["in:value", "out:result"]),
    ("trim_quotes", "TrimQuotes", ["in:value", "out:result"]),
    ("registry_set_string", "SetRegistrySubKeyStr", ["in:key", "in:subkey", "in:value"]),
    ("registry_get_string", "GetRegistrySubKey", ["in:key", "in:subkey", "out:value"]),
    ("registry_set_dword", "SetRegistrySubKeyDWORD", ["in:key", "in:subkey", "in:value:int"]),
    ("registry_get_dword", "GetRegistrySubKey", ["in:key", "in:subkey", "out:value:int"]),
    ("registry_set_binary", "HarnessSetRegistryBinary", ["in:key", "in:subkey"]),
    ("registry_set_binary_register", "HarnessSetRegistryBinaryRegister", ["in:key", "in:subkey"]),
    ("registry_set_binary_test_id", "HarnessSetRegistryBinary", ["in:key", "in:subkey"]),
    ("registry_remove", "RemoveRegistryKey", ["in:key"]),
    ("test_id", "GetTestId", ["out:value"]),
    ("shell_context_admin", "UpdateShellContextToAdmin", []),
    ("shell_context_current", "UpdateShellContextToCurrent", []),
    ("shell_context_set", "SetShellContext", []),
    ("shell_context_reset", "ResetShellContext", []),
    ("eventlog_add_source", "EventLog_AddSource", [
        "in:key", "in:source", "in:types:int", "in:event_file", "in:category_file", "in:parameter_file",
    ]),
    ("eventlog_remove_source", "EventLog_RemoveSource", ["in:key", "in:source"]),
    ("set_product_code", "SetProductCode", ["in:guid"]),
    ("product_code", "GetProductCode", ["out:value"]),
    ("uninstall_registry_update", "UpdateUninstallRegistry", ["in:subkey", "in:value"]),
    ("uninstall_registry_get", "GetUninstallRegistry", ["in:subkey", "out:value"]),
    ("uninstall_registry_get_register", "HarnessGetUninstallRegistryRegister", ["in:subkey", "out:value"]),
    ("uninstall_registry_remove", "RemoveUninstallRegistry", []),
    ("install_detail_update", "UpdateInstallDetail", [
        "in:publisher", "in:product", "in:component", "in:subkey", "in:value",
    ]),
    ("install_detail_get", "GetInstallDetail", [
        "in:publisher", "in:product", "in:component", "in:subkey", "out:value",
    ]),
    ("uninstall_existing", "UninstallExisting", ["in:appkey", "out:exitcode:int"]),
    ("mutex", "ValidateMutex", ["in:name"]),
    ("log_debug", "LogDebug", ["in:text"]),
    ("log_info", "LogInfo", ["in:text"]),
    ("log_warn", "LogWarn", ["in:text"]),
    ("log_error", "LogError", ["in:text"]),
    ("log", "Log", ["in:text"]),
    ("move_file", "MoveFile", ["in:source", "in:destination"]),
    ("move_folder", "MoveFolder", ["in:source", "in:destination", "in:mask"]),
    # nsExec returns decimal codes or the nonnumeric strings "error"/"timeout".
    ("service_create", "Service_Create", [
        "in:name", "in:binary", "in:display_name", "in:start_type", "in:dependencies", "out:result",
    ]),
    ("service_query", "Service_Query", ["in:name", "out:result"]),
    ("service_update", "Service_Update", [
        "in:name", "in:binary", "in:display_name", "in:start_type", "in:dependencies", "out:result",
    ]),
    ("service_start", "Service_Start", ["in:name", "out:result"]),
    ("service_stop", "Service_Stop", ["in:name", "out:result"]),
    ("service_delete", "Service_Delete", ["in:name", "out:result"]),
    ("service_set_description", "Service_SetDescription", ["in:name", "in:description", "out:result"]),
    ("icacls_grant", "iCacls_Grant", ["in:path", "in:sid", "in:permission", "in:recursive:int", "out:result"]),
    ("icacls_deny", "iCacls_Deny", ["in:path", "in:sid", "in:permission", "in:recursive:int", "out:result"]),
    ("icacls_remove_grant", "iCacls_RemoveGrant", ["in:path", "in:sid", "in:recursive:int", "out:result"]),
    ("icacls_remove_deny", "iCacls_RemoveDeny", ["in:path", "in:sid", "in:recursive:int", "out:result"]),
    ("icacls_integrity", "iCacls_IntegrityLevel", ["in:path", "in:level", "in:inheritance", "in:recursive:int", "out:result"]),
    ("icacls_substitute", "iCacls_Substitute", ["in:path", "in:old_sid", "in:new_sid", "in:recursive:int", "out:result"]),
]

_CONSTANTS = [
    ("display_name", "UnDisplayName", "DisplayName"),
    ("display_version", "UnDisplayVersion", "DisplayVersion"),
    ("display_icon", "UnDisplayIcon", "DisplayIcon"),
    ("publisher", "UnPublisher", "Publisher"),
    ("version_minor", "UnVersionMinor", "VersionMinor"),
    ("version_major", "UnVersionMajor", "VersionMajor"),
    ("help_link", "UnHelpLink", "HelpLink"),
    ("help_telephone", "UnHelpTelephone", "HelpTelephone"),
    ("install_date", "UnInstallDate", "InstallDate"),
    ("install_date_today", "UnInstallDateToday", "InstallDateToday"),
    ("install_location", "UnInstallLocation", "InstallLocation"),
    ("install_source", "UnInstallSource", "InstallSource"),
    ("url_about_info", "UnUrlAboutInfo", "UrlAboutInfo"),
    ("url_update_info", "UnUrlUpdateInfo", "UrlUpdateInfo"),
    ("authorized_cdf_prefix", "UnAuthorizedCdfPrefix", "AuthorizedCdfPrefix"),
    ("comments", "UnComments", "Comments"),
    ("contact", "UnContact", "Contact"),
    ("estimated_size", "UnEstimatedSize", "EstimatedSize"),
    ("language", "UnLanguage", "Language"),
    ("modify_path", "UnModifyPath", "ModifyPath"),
    ("readme", "UnReadme", "Readme"),
    ("uninstall_string", "UnUninstallString", "UninstallString"),
    ("quiet_uninstall_string", "UnQuietUninstallString", "QuietUninstallString"),
    ("settings_identifier", "UnSettingsIdentifier", "SettingsIdentifier"),
    ("no_modify", "UnNoModify", "NoModify"),
    ("no_repair", "UnNoRepair", "NoRepair"),
    ("no_remove", "UnNoRemove", "NoRemove"),
    ("product_id", "UnProductID", "ProductID"),
    ("system_component", "UnSystemComponent", "SystemComponent"),
    ("installed", "InsInstalled", "Installed"),
    ("directory", "InsDirectory", "Directory"),
    ("eventlog_source", "InsEventLogSource", "EventLogSource"),
    ("ins_install_location", "InsInstallLocation", "InstallLocation"),
]

_INSTALLER_ONLY = [
    ("version_compare", "VersionCompare", "definition", ["in:first", "in:second", "out:comparison:int"], ""),
    ("version_compare_call", "VersionCompare", "macro", ["in:first", "in:second", "out:comparison:int"], ""),
]

_BRANCH_ADAPTERS = [
    ("if_test", "HarnessIfTest", ["out:result"], {"TEST_INITIAL_ID": "framework-test-id"}),
    ("if_not_test", "HarnessIfNotTest", ["out:result"], {}),
    ("test_id_set", "HarnessSetTestId", ["in:id", "out:value"], {}),
    ("shell_context_aliases", "HarnessShellContext", ["in:mode", "out:context"], {}),
    ("native_arch_define", "HarnessNativeArch", ["out:arch"], {}),
    ("arch_allows_32_on_64", "HarnessArchAllows32On64", ["in:host", "out:accepted"], {}),
    ("trim_quotes_special", "HarnessTrimQuotesSpecial", [
        "out:quoted", "out:empty", "out:left",
    ], {}),
    ("char_to_ascii_soft_hyphen", "HarnessCharToASCIISoftHyphen", ["out:value:int"], {}),
    ("move_file_twice", "HarnessMoveFileTwice", [
        "in:first_source", "in:first_destination", "in:second_source", "in:second_destination",
    ], {}),
]

_NO_UNINSTALLER_SYMBOL = [
    "uninstall_existing",
    "move_file",
    "move_folder",
    "service_create",
    "service_query",
    "service_update",
    "service_start",
    "service_stop",
    "service_delete",
    "service_set_description",
    "icacls_grant",
    "icacls_deny",
    "icacls_remove_grant",
    "icacls_remove_deny",
    "icacls_integrity",
    "icacls_substitute",
]

_UNPREFIXED_UNINSTALLER_SYMBOL = [
    "test_id",
    "shell_context_admin",
    "shell_context_current",
    "shell_context_reset",
    "log_debug",
    "log_info",
    "log_warn",
    "log_error",
    "log",
]

# Cases whose harness runs under an active test id ("framework-test-id").
_TEST_ID_CASES = [
    "test_id",
    "registry_set_binary_test_id",
    "eventlog_add_source",
    "eventlog_remove_source",
]

_PRODUCT_CODES = {
    "uninstall_existing": "77777777-7777-4777-8777-777777777777",
    "product_code": "aabbccdd-eeff-0011-2233-445566778899",
    "un_product_code": "aabbccdd-eeff-0011-2233-445566778899",
    "uninstall_registry_update": "11111111-1111-4111-8111-111111111111",
    "un_uninstall_registry_update": "22222222-2222-4222-8222-222222222222",
    "uninstall_registry_get": "33333333-3333-4333-8333-333333333333",
    "un_uninstall_registry_get": "44444444-4444-4444-8444-444444444444",
    "uninstall_registry_remove": "55555555-5555-4555-8555-555555555555",
    "un_uninstall_registry_remove": "66666666-6666-4666-8666-666666666666",
    "uninstall_registry_get_register": "88888888-8888-4888-8888-888888888888",
    "un_uninstall_registry_get_register": "99999999-9999-4999-8999-999999999999",
}

def nsis_include_api_tests():
    test_names = []
    binaries = []
    child_binaries = []
    for code in [0, 37]:
        name = "uninstall_child_" + str(code)
        nsis_symbol(
            name = name + "_symbol",
            symbol = "HarnessChildExit",
            kind = "macro",
            defines = {"TEST_CHILD_EXITCODE": str(code)},
            testonly = True,
        )
        nsis_test_harness(
            name = name + "_harness",
            src = "include_api_fixture.nsh",
            description = ":" + name + "_symbol",
            testonly = True,
        )
        child_binaries.append(":" + name + "_harness")
        binaries.append(":" + name + "_harness")
    for name, symbol, parameters in _PAIRED:
        contexts = ["installer"]
        if name not in _NO_UNINSTALLER_SYMBOL:
            contexts.append("uninstaller")
        for context in contexts:
            prefix = "" if context == "installer" else "un_"
            test_name = prefix + name
            symbol_name = symbol if context == "installer" or name in _UNPREFIXED_UNINSTALLER_SYMBOL else "un." + symbol
            defines = {}
            if test_name in _PRODUCT_CODES:
                defines["TEST_PRODUCT_CODE"] = _PRODUCT_CODES[test_name]
            if name in _TEST_ID_CASES:
                defines["TEST_INITIAL_ID"] = "framework-test-id"
            nsis_symbol(
                name = test_name + "_symbol",
                symbol = symbol_name,
                kind = "macro",
                context = context,
                parameters = parameters,
                defines = defines,
                testonly = True,
            )
            nsis_test_harness(
                name = test_name + "_harness",
                src = "include_api_fixture.nsh",
                description = ":" + test_name + "_symbol",
                testonly = True,
            )
            py_test(
                name = "include_api_" + test_name,
                srcs = ["include_api_test.py"],
                main = "include_api_test.py",
                args = [
                    test_name,
                    "$(rlocationpath :" + test_name + "_harness)",
                    "$(rlocationpath :" + test_name + "_symbol)",
                ] + (["$(rlocationpath " + child + ")" for child in child_binaries] if name == "uninstall_existing" else []),
                data = [":" + test_name + "_harness", ":" + test_name + "_symbol"] + (child_binaries if name == "uninstall_existing" else []),
                deps = ["//nsis/testing", "@rules_python//python/runfiles"],
                target_compatible_with = ["@platforms//os:windows"],
                timeout = "short",
            )
            test_names.append(":include_api_" + test_name)
            binaries.append(":" + test_name + "_harness")
    for name, symbol, kind, parameters, invocation in _INSTALLER_ONLY:
        nsis_symbol(
            name = name + "_symbol",
            symbol = symbol,
            kind = kind,
            parameters = parameters,
            invocation = invocation if invocation else "",
            testonly = True,
        )
        nsis_test_harness(
            name = name + "_harness",
            src = "include_api_fixture.nsh",
            description = ":" + name + "_symbol",
            testonly = True,
        )
        py_test(
            name = "include_api_" + name,
            srcs = ["include_api_test.py"],
            main = "include_api_test.py",
            args = [
                name,
                "$(rlocationpath :" + name + "_harness)",
                "$(rlocationpath :" + name + "_symbol)",
            ],
            data = [":" + name + "_harness", ":" + name + "_symbol"],
            deps = ["//nsis/testing", "@rules_python//python/runfiles"],
            target_compatible_with = ["@platforms//os:windows"],
            timeout = "short",
        )
        test_names.append(":include_api_" + name)
        binaries.append(":" + name + "_harness")

    for name, symbol, parameters, defines in _BRANCH_ADAPTERS:
        nsis_symbol(
            name = name + "_symbol",
            symbol = symbol,
            kind = "macro",
            parameters = parameters,
            defines = defines,
            testonly = True,
        )
        nsis_test_harness(
            name = name + "_harness",
            src = "include_api_fixture.nsh",
            description = ":" + name + "_symbol",
            testonly = True,
        )
        py_test(
            name = "include_api_" + name,
            srcs = ["include_api_test.py"],
            main = "include_api_test.py",
            args = [
                name,
                "$(rlocationpath :" + name + "_harness)",
                "$(rlocationpath :" + name + "_symbol)",
            ],
            data = [":" + name + "_harness", ":" + name + "_symbol"],
            deps = ["//nsis/testing", "@rules_python//python/runfiles"],
            target_compatible_with = ["@platforms//os:windows"],
            timeout = "short",
        )
        test_names.append(":include_api_" + name)
        binaries.append(":" + name + "_harness")

    for name, symbol, value in _CONSTANTS:
        test_name = "uninstall_constant_" + name
        nsis_symbol(
            name = test_name + "_symbol",
            symbol = symbol,
            kind = "definition",
            invocation = "value",
            parameters = ["out:value"],
            testonly = True,
        )
        nsis_test_harness(
            name = test_name + "_harness",
            src = "include_api_fixture.nsh",
            description = ":" + test_name + "_symbol",
            testonly = True,
        )
        py_test(
            name = "include_api_" + test_name,
            srcs = ["include_api_test.py"],
            main = "include_api_test.py",
            args = [
                test_name,
                "$(rlocationpath :" + test_name + "_harness)",
                "$(rlocationpath :" + test_name + "_symbol)",
            ],
            data = [":" + test_name + "_harness", ":" + test_name + "_symbol"],
            deps = ["//nsis/testing", "@rules_python//python/runfiles"],
            target_compatible_with = ["@platforms//os:windows"],
            timeout = "short",
        )
        test_names.append(":include_api_" + test_name)
        binaries.append(":" + test_name + "_harness")

    native.test_suite(
        name = "include_api_tests",
        tests = test_names,
    )
    native.filegroup(
        name = "include_api_test_binaries",
        srcs = binaries,
        testonly = True,
    )
    symbols = [test[len(":include_api_"):] for test in test_names]
    py_test(
        name = "include_api_contract_test",
        size = "small",
        srcs = ["include_api_contract_test.py", "include_api_test.py", "__init__.py"],
        main = "include_api_contract_test.py",
        args = [
            "$(rlocationpath :" + name + "_symbol)"
            for name in symbols
        ] + ["--includes=$(rlocationpath //nsis/private/includes:includes_dir)"],
        data = [":" + name + "_symbol" for name in symbols] + ["//nsis/private/includes:includes_dir"],
        deps = ["//nsis/testing", "@rules_python//python/runfiles"],
    )
