"""Arch.nsh cases."""

load(":defs.bzl", "include_api_case")

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

    # ArchAllows32On64 takes the installer arch at compile time, so an adapter
    # evaluates all four against a simulated host.
    cases += include_api_case(
        name = "arch_allows_32_on_64",
        api = "arch",
        include = "Arch.nsh",
        src = "arch_adapters.nsh",
        symbol = "HarnessArchAllows32On64",
        parameters = ["in:host", "out:accepted"],
    )
    return cases
