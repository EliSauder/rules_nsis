"""Registry.nsh cases."""

load(":defs.bzl", "include_api_case")

_TEST_ID = ['${SetTestId} "framework-test-id"']

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
