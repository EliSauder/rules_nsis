"""Shared helpers for declaring include API test cases."""

load("@rules_python//python:py_test.bzl", "py_test")
load("//nsis/testing:defs.bzl", "nsis_symbol", "nsis_test_harness")

CONTEXTS = ["installer", "uninstaller"]

def include_label(include):
    return "//nsis/private/includes:" + include

def _for_context(value, context):
    """Values may be shared, or a dict keyed by context."""
    if type(value) == "dict":
        return value.get(context, [])
    return value

def include_api_case(
        name,
        api,
        include,
        symbol,
        parameters = [],
        kind = "macro",
        invocation = "",
        constants = {},
        src = None,
        contexts = CONTEXTS,
        un_symbol = None,
        defines = {},
        testable = True,
        on_init = [],
        args = [],
        data = []):
    """Declares a symbol, harness and py_test for each context.

    Args:
        name: Case name; uninstaller cases are prefixed with "un_".
        api: Name of the <api>_test.py module holding the case's assertions.
        include: The include under test, used as src unless src is given.
        symbol: Installer symbol.
        parameters: nsis_symbol parameters.
        kind: nsis_symbol kind.
        invocation: nsis_symbol invocation.
        constants: nsis_symbol constants.
        src: A test adapter to use as the harness source instead of include.
        contexts: Contexts to test.
        un_symbol: Uninstaller symbol; defaults to "un." + symbol.
        defines: Harness defines.
        testable: Whether to define TESTABLE_INSTALLER.
        on_init: Harness on_init lines, or a dict of them keyed by context.
        args: Extra test arguments, or a dict of them keyed by context.
        data: Extra test data.

    Returns:
        A struct per declared case for include_api_suite.
    """
    harness_defines = dict(defines)
    if testable:
        harness_defines["TESTABLE_INSTALLER"] = ""
    cases = []
    for context in contexts:
        case = name if context == "installer" else "un_" + name
        nsis_symbol(
            name = case + "_symbol",
            symbol = symbol if context == "installer" else (un_symbol or "un." + symbol),
            kind = kind,
            context = context,
            parameters = parameters,
            constants = constants,
            invocation = invocation,
            testonly = True,
        )
        nsis_test_harness(
            name = case + "_harness",
            src = src or include_label(include),
            description = ":" + case + "_symbol",
            defines = harness_defines,
            on_init = _for_context(on_init, context),
            testonly = True,
        )
        case_args = _for_context(args, context)
        py_test(
            name = case,
            srcs = [api + "_test.py"],
            main = api + "_test.py",
            args = [
                case,
                "$(rlocationpath :" + case + "_harness)",
                "$(rlocationpath :" + case + "_symbol)",
            ] + case_args,
            data = [":" + case + "_harness", ":" + case + "_symbol"] + data,
            deps = [":common"],
            target_compatible_with = ["@platforms//os:windows"],
            timeout = "short",
        )
        cases.append(struct(
            name = case,
            api = api,
            args = case_args,
            data = data,
        ))
    return cases

def include_api_suite(name, cases, extra_tests = [], extra_binaries = []):
    """Declares the test suite, binaries and host contract test for cases."""
    native.test_suite(
        name = name,
        tests = [":" + case.name for case in cases] + extra_tests,
    )
    native.filegroup(
        name = "binaries",
        srcs = [":" + case.name + "_harness" for case in cases] + extra_binaries,
        testonly = True,
    )
    data = []
    for case in cases:
        for label in [":" + case.name + "_symbol"] + case.data:
            if label not in data:
                data.append(label)
    apis = []
    for case in cases:
        if case.api not in apis:
            apis.append(case.api)
    py_test(
        name = "contract_test",
        size = "small",
        srcs = ["contract_test.py"] + [api + "_test.py" for api in apis],
        main = "contract_test.py",
        # Each case is api|case|description[|extra args...].
        args = [
            "|".join([case.api, case.name, "$(rlocationpath :" + case.name + "_symbol)"] + case.args)
            for case in cases
        ],
        data = data,
        deps = [":common"],
    )
