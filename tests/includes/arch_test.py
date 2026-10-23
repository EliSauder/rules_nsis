from tests.includes import common

_ARCHES = ("x86_32", "x86_64", "arm32", "arm64")

# Installer arches each host accepts: a 32bit installer may only use the 64bit
# host of its own instruction set.
_ACCEPTS = {
    "x86_32": {"x86_32"},
    "x86_64": {"x86_32", "x86_64"},
    "arm32": {"arm32"},
    "arm64": {"arm32", "arm64"},
}


def run_case(case, harness, args):
    base = common.base(case)
    arch = common.host_arch()
    if base == "arch_get":
        result = harness.run()
        assert type(result.outputs["arch"]) is str
        assert result.outputs["arch"] in ("x86_32", "x86_64", "arm32", "arm64")
    elif base == "arch_detect":
        harness.run().assert_outputs(arch=arch, is64="64" in arch, is32="32" in arch)
    elif base in ("arch_is_64_bit", "arch_is_32_bit"):
        harness.run().assert_outputs(value=(base == "arch_is_64_bit") == ("64" in arch))
    elif base == "arch_validate":
        for expected in _ARCHES:
            harness.run(expected=expected, expected_exitcode=0 if expected == arch else 3)
    elif base == "arch_validate_bitwidth":
        bits = 64 if "64" in arch else 32
        harness.run(bits=bits)
        harness.run(bits=96 - bits, expected_exitcode=3)
    elif base == "arch_validate_isa":
        isa = arch.split("_")[0][:3]
        # Accepts the bare ISA or any full arch of it; rejects the other ISA and unknown ones.
        for expected in _ARCHES + ("x86", "arm", "mips"):
            harness.run(isa=expected, expected_exitcode=0 if expected[:3] == isa else 3)
    elif base == "arch_is_native_arm32":
        harness.run().assert_outputs(arm32=arch == "arm32")
    elif base.startswith(("arch_allows_32_on_64_on_", "arch_validate_32_on_64_on_")):
        (host,) = args
        for expected in _ARCHES:
            accepted = expected in _ACCEPTS[host]
            if base.startswith("arch_allows_"):
                harness.run(expected=expected).assert_outputs(accepted=accepted)
            else:
                harness.run(expected=expected, expected_exitcode=0 if accepted else 3)
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
