"""Registry.nsh cases."""

load(":defs.bzl", "include_api_case")

_TEST_ID = ['${SetTestId} "framework-test-id"']

# HKCU\Software is shared by both registry views, so view cases use HKLM.
_ADMIN = ["${UpdateShellContextToAdmin}"]
_PINNED = {"REGISTRY_VIEW": "32"}

def registry_cases():
    cases = []
    for name, symbol, parameters in [
        ("registry_set_string", "SetRegistrySubKeyStr", ["in:key", "in:subkey", "in:value"]),
        ("registry_get_string", "GetRegistrySubKey", ["in:key", "in:subkey", "out:value"]),
        ("registry_set_dword", "SetRegistrySubKeyDWORD", ["in:key", "in:subkey", "in:value:int"]),
        ("registry_get_dword", "GetRegistrySubKey", ["in:key", "in:subkey", "out:value:int"]),
        ("registry_remove", "RemoveRegistryKey", ["in:key"]),
        ("registry_define_reg_view", "DefineRegView", []),
        ("format_str_to_bin", "FormatStrToBin", ["in:value", "in:is_int:bool", "out:binary"]),
        ("format_str_to_dword", "FormatStrToDWORD", ["in:value", "out:result"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "registry",
            include = "Registry.nsh",
            symbol = symbol,
            parameters = parameters,
        )

    # WriteRegBin only accepts compile-time hex literals.
    for name, on_init in [
        ("registry_set_binary", []),
        ("registry_set_binary_test_id", _TEST_ID),
    ]:
        cases += include_api_case(
            name = name,
            api = "registry",
            include = "Registry.nsh",
            symbol = "SetRegistrySubKeyBin",
            parameters = ["in:key", "in:subkey", "const:value"],
            constants = {"value": "000102FF"},
            on_init = on_init,
        )

    for name, symbol, parameters, constants, defines in [
        ("registry_view_set_string", "SetRegistrySubKeyStrInView", ["in:view", "in:key", "in:subkey", "in:value"], {}, {}),
        ("registry_view_set_dword", "SetRegistrySubKeyDWORDInView", ["in:view", "in:key", "in:subkey", "in:value:int"], {}, {}),
        ("registry_view_set_binary", "SetRegistrySubKeyBinInView", ["in:view", "in:key", "in:subkey", "const:value"], {"value": "000102FF"}, {}),
        ("registry_view_get", "GetRegistrySubKeyInView", ["in:view", "in:key", "in:subkey", "out:value"], {}, {}),
        ("registry_view_remove", "RemoveRegistryKeyInView", ["in:view", "in:key"], {}, {}),
        # REGISTRY_VIEW pins the view used by the functions without one.
        ("registry_pinned_set_string", "SetRegistrySubKeyStr", ["in:key", "in:subkey", "in:value"], {}, _PINNED),
        ("registry_pinned_set_binary", "SetRegistrySubKeyBin", ["in:key", "in:subkey", "const:value"], {"value": "000102FF"}, _PINNED),
    ]:
        cases += include_api_case(
            name = name,
            api = "registry",
            include = "Registry.nsh",
            symbol = symbol,
            parameters = parameters,
            constants = constants,
            defines = defines,
            on_init = _ADMIN,
        )

    for name, defines, view in [
        ("registry_get_view", {}, "native"),
        ("registry_get_view_pinned", _PINNED, "32"),
    ]:
        cases += include_api_case(
            name = name,
            api = "registry",
            include = "Registry.nsh",
            symbol = "GetRegView",
            parameters = ["out:view"],
            defines = defines,
            args = [view],
        )

    # KEY and SUBKEY arrive in registers the Bin macro itself uses as scratch.
    cases += include_api_case(
        name = "registry_set_binary_register",
        api = "registry",
        include = "Registry.nsh",
        src = "registry_adapters.nsh",
        symbol = "HarnessSetRegistryBinaryRegister",
        parameters = ["in:key", "in:subkey"],
    )
    return cases
