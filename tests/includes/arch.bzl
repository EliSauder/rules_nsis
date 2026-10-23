"""Arch.nsh cases."""

load(":defs.bzl", "include_api_case")

_HOSTS = ["x86_32", "x86_64", "arm32", "arm64"]

def arch_cases():
    cases = []
    for name, symbol, parameters in [
        ("arch_get", "GetArch", ["out:arch"]),
        ("arch_detect", "DetectArch", []),
        ("arch_is_64_bit", "Is64Bit", ["out:value:bool"]),
        ("arch_is_32_bit", "Is32Bit", ["out:value:bool"]),
        ("arch_validate", "ValidateArch", ["in:expected"]),
        ("arch_validate_bitwidth", "ValidateBitwidth", ["in:bits:int"]),
        ("arch_validate_isa", "ValidateISA", ["in:isa"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "arch",
            include = "Arch.nsh",
            symbol = symbol,
            parameters = parameters,
        )
    cases += include_api_case(
        name = "arch_is_native_arm32",
        api = "arch",
        include = "Arch.nsh",
        symbol = "IsNativeARM32",
        kind = "condition",
        parameters = ["out:arm32:bool"],
        contexts = ["installer"],
    )

    # Each host is simulated by presetting the detected architecture.
    for host in _HOSTS:
        for name, symbol, parameters in [
            ("arch_allows_32_on_64", "ArchAllows32On64", ["in:expected", "out:accepted:bool"]),
            ("arch_validate_32_on_64", "ValidateArch32On64", ["in:expected"]),
        ]:
            cases += include_api_case(
                name = name + "_on_" + host,
                api = "arch",
                include = "Arch.nsh",
                symbol = symbol,
                parameters = parameters,
                on_init = ['StrCpy $current_arch "' + host + '"'],
                args = [host],
            )
    return cases
