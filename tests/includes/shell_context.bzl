"""ShellContext.nsh cases."""

load(":defs.bzl", "include_api_case")

_ADMIN = ["${UpdateShellContextToAdmin}"]
_CURRENT = ["${UpdateShellContextToCurrent}"]
_RESET = ["${UpdateShellContextToAdmin}", "${ResetShellContext}"]
_SET = {"installer": ["${SetShellContext}"], "uninstaller": ["${un.SetShellContext}"]}
_ADMIN_LEVEL = {"IS_ADMIN_EXECUTION_LEVEL": "1"}

def shell_context_cases():
    cases = []
    for name, symbol in [
        ("shell_context_admin", "UpdateShellContextToAdmin"),
        ("shell_context_current", "UpdateShellContextToCurrent"),
        ("shell_context_reset", "ResetShellContext"),
    ]:
        cases += include_api_case(
            name = name,
            api = "shell_context",
            include = "ShellContext.nsh",
            symbol = symbol,
            un_symbol = symbol,
        )
    cases += include_api_case(
        name = "shell_context_set",
        api = "shell_context",
        include = "ShellContext.nsh",
        symbol = "SetShellContext",
    )

    # Each case's expected result is in shell_context_test.py.
    for name, symbol, on_init, defines in [
        ("if_admin_after_admin", "IfAdmin", _ADMIN, {}),
        ("if_admin_after_current", "IfAdmin", _CURRENT, {}),
        ("if_admin_after_reset", "IfAdmin", _RESET, {}),
        ("if_admin_after_reset_admin_level", "IfAdmin", _RESET, _ADMIN_LEVEL),
        ("if_admin_default", "IfAdmin", _SET, {}),
        ("if_admin_default_admin_level", "IfAdmin", _SET, _ADMIN_LEVEL),
        ("if_not_admin_after_admin", "IfNotAdmin", _ADMIN, {}),
        ("if_not_admin_after_current", "IfNotAdmin", _CURRENT, {}),
    ]:
        cases += include_api_case(
            name = name,
            api = "shell_context",
            include = "ShellContext.nsh",
            symbol = symbol,
            un_symbol = symbol,
            kind = "condition",
            invocation = "statement",
            parameters = ["out:admin:bool"],
            on_init = on_init,
            defines = defines,
        )
    return cases
