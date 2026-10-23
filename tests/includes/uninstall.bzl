"""Uninstall.nsh cases."""

load("//nsis/testing:defs.bzl", "nsis_symbol", "nsis_test_harness")
load(":defs.bzl", "include_api_case", "include_label")
load(":product.bzl", "product_code")

_CHILD_EXIT_CODES = [0, 37]

def uninstall_cases():
    # Stand-ins for an installed product's uninstaller: they exit with a fixed
    # code from .onInit, before the harness reads any arguments.
    children = []
    for code in _CHILD_EXIT_CODES:
        name = "uninstall_child_" + str(code)
        nsis_symbol(
            name = name + "_symbol",
            symbol = "UninstallExisting",
            kind = "macro",
            parameters = ["in:appkey", "out:exitcode:int"],
            testonly = True,
        )
        nsis_test_harness(
            name = name + "_harness",
            src = include_label("Uninstall.nsh"),
            description = ":" + name + "_symbol",
            on_init = ["SetErrorLevel " + str(code), "Quit"],
            testonly = True,
        )
        children.append(":" + name + "_harness")

    product = product_code("77777777-7777-4777-8777-777777777777")
    return include_api_case(
        name = "uninstall_existing",
        api = "uninstall",
        include = "Uninstall.nsh",
        symbol = "UninstallExisting",
        parameters = ["in:appkey", "out:exitcode:int"],
        on_init = product.on_init,
        args = {
            context: product.args[context] + ["$(rlocationpath " + child + ")" for child in children]
            for context in product.args
        },
        data = children,
    )
