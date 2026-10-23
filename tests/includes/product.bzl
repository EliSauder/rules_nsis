"""Product.nsh cases."""

load(":defs.bzl", "include_api_case")

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

def product_code(code):
    """on_init and args giving a case its own product code per context.

    Each context needs a distinct code: the cases run in parallel and share
    the HKCU uninstall key derived from it.
    """
    un_code = code[:-1] + ("0" if code[-1] != "0" else "1")
    return struct(
        on_init = {
            "installer": ['${SetProductCode} "' + code + '"'],
            "uninstaller": ['${un.SetProductCode} "' + un_code + '"'],
        },
        args = {"installer": [code], "uninstaller": [un_code]},
    )

def product_cases():
    cases = []
    for name, symbol, parameters, code in [
        ("set_product_code", "SetProductCode", ["in:guid"], None),
        ("product_code", "GetProductCode", ["out:value"], "aabbccdd-eeff-0011-2233-445566778899"),
        ("product_code_unset", "GetProductCode", ["out:value"], None),
        ("uninstall_registry_update", "UpdateUninstallRegistry", ["in:subkey", "in:value"], "11111111-1111-4111-8111-111111111111"),
        ("uninstall_registry_update_dword", "UpdateUninstallRegistryDWORD", ["in:subkey", "in:value:int"], "22222222-2222-4222-8222-222222222222"),
        ("uninstall_registry_get", "GetUninstallRegistry", ["in:subkey", "out:value"], "33333333-3333-4333-8333-333333333333"),
        ("uninstall_registry_remove", "RemoveUninstallRegistry", [], "55555555-5555-4555-8555-555555555555"),
        ("install_detail_update", "UpdateInstallDetail", [
            "in:publisher",
            "in:product",
            "in:component",
            "in:subkey",
            "in:value",
        ], None),
        ("install_detail_get", "GetInstallDetail", [
            "in:publisher",
            "in:product",
            "in:component",
            "in:subkey",
            "out:value",
        ], None),
    ]:
        product = product_code(code) if code else struct(on_init = [], args = [])
        cases += include_api_case(
            name = name,
            api = "product",
            include = "Product.nsh",
            symbol = symbol,
            parameters = parameters,
            on_init = product.on_init,
            args = product.args,
        )

    cases += include_api_case(
        name = "set_product_key",
        api = "product",
        include = "Product.nsh",
        symbol = "SetProductKey",
        parameters = ["in:path"],
    )
    for name, on_init in [
        ("product_key", {
            "installer": ['${SetProductKey} "Publisher\\Product"'],
            "uninstaller": ['${un.SetProductKey} "Publisher\\Product"'],
        }),
        ("product_key_unset", []),
    ]:
        cases += include_api_case(
            name = name,
            api = "product",
            include = "Product.nsh",
            symbol = "GetProductKey",
            parameters = ["out:value"],
            on_init = on_init,
        )

    # The output operand is a register the macro also uses internally.
    product = product_code("88888888-8888-4888-8888-888888888888")
    cases += include_api_case(
        name = "uninstall_registry_get_register",
        api = "product",
        include = "Product.nsh",
        src = "product_adapters.nsh",
        symbol = "HarnessGetUninstallRegistryRegister",
        parameters = ["in:subkey", "out:value"],
        on_init = product.on_init,
        args = product.args,
    )

    for name, symbol, value in _CONSTANTS:
        cases += include_api_case(
            name = "uninstall_constant_" + name,
            api = "product",
            include = "Product.nsh",
            symbol = symbol,
            kind = "definition",
            invocation = "value",
            parameters = ["out:value"],
            contexts = ["installer"],
            args = [value],
        )
    return cases
