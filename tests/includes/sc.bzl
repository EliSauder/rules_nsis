"""Sc.nsh cases."""

load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_python//python:py_test.bzl", "py_test")
load(":defs.bzl", "include_api_case")

_OPERATIONS = [
    ("create", "Service_Create", ["in:name", "in:binary", "in:display_name", "in:start_type", "in:dependencies", "out:result"]),
    ("query", "Service_Query", ["in:name", "out:result"]),
    ("update", "Service_Update", ["in:name", "in:binary", "in:display_name", "in:start_type", "in:dependencies", "out:result"]),
    ("start", "Service_Start", ["in:name", "out:result"]),
    ("stop", "Service_Stop", ["in:name", "out:result"]),
    ("delete", "Service_Delete", ["in:name", "out:result"]),
    ("set_description", "Service_SetDescription", ["in:name", "in:description", "out:result"]),
]

def sc_cases():
    """Per-macro failure cases, plus a lifecycle test of a real service."""
    cases = []
    for operation, symbol, parameters in _OPERATIONS:
        # nsExec returns decimal codes or the nonnumeric strings "error"/"timeout".
        cases += include_api_case(
            name = "service_" + operation,
            api = "sc",
            include = "Sc.nsh",
            symbol = symbol,
            # The macros only run sc through nsExec, so they are context-free.
            un_symbol = symbol,
            parameters = parameters,
        )

    cc_binary(
        name = "service_stub",
        srcs = ["service_stub.c"],
        linkopts = select({
            "@rules_cc//cc/compiler:msvc-cl": ["advapi32.lib"],
            "//conditions:default": ["-ladvapi32"],
        }),
        target_compatible_with = ["@platforms//os:windows"],
        testonly = True,
    )

    # Drives one real service through every macro, in each context.
    tests = []
    for prefix in ["", "un_"]:
        name = prefix + "service_lifecycle"
        harnesses = [prefix + "service_" + operation for operation, _, _ in _OPERATIONS]
        py_test(
            name = name,
            srcs = ["sc_test.py"],
            main = "sc_test.py",
            args = [name, "$(rlocationpath :service_stub)"] + [
                "$(rlocationpath :" + h + "_harness)=$(rlocationpath :" + h + "_symbol)"
                for h in harnesses
            ],
            data = [":service_stub"] + [":" + h + "_harness" for h in harnesses] + [
                ":" + h + "_symbol"
                for h in harnesses
            ],
            deps = [":common"],
            target_compatible_with = ["@platforms//os:windows"],
            timeout = "moderate",
        )
        tests.append(":" + name)
    return struct(cases = cases, tests = tests, binaries = [":service_stub"])
