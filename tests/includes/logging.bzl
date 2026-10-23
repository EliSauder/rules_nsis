"""Logging.nsh cases."""

load(":defs.bzl", "include_api_case")

_SYMBOLS = {
    "log": "Log",
    "log_debug": "LogDebug",
    "log_info": "LogInfo",
    "log_warn": "LogWarn",
    "log_error": "LogError",
}

_ENABLED = {"LOGGING_ENABLE": ""}

# (case, macro, defines); each case's expected output is in logging_test.py.
_CASES = [
    (name, name, dict(_ENABLED, LOGLEVEL_DEBUG = ""))
    for name in _SYMBOLS
] + [
    # The level is the least severe one written; INFO is the default.
    ("log_debug_default_level", "log_debug", _ENABLED),
    ("log_info_default_level", "log_info", _ENABLED),
    ("log_debug_at_info", "log_debug", dict(_ENABLED, LOGLEVEL_INFO = "")),
    ("log_info_at_warn", "log_info", dict(_ENABLED, LOGLEVEL_WARN = "")),
    ("log_warn_at_warn", "log_warn", dict(_ENABLED, LOGLEVEL_WARN = "")),
    ("log_warn_at_error", "log_warn", dict(_ENABLED, LOGLEVEL_ERR = "")),
    ("log_error_at_error", "log_error", dict(_ENABLED, LOGLEVEL_ERR = "")),
    ("log_at_error", "log", dict(_ENABLED, LOGLEVEL_ERR = "")),
    # Without LOGGING_ENABLE nothing is written, at any level.
    ("log_disabled", "log", {}),
    ("log_error_disabled", "log_error", {"LOGLEVEL_ERR": ""}),
]

def logging_cases():
    cases = []
    for name, macro, defines in _CASES:
        cases += include_api_case(
            name = name,
            api = "logging",
            include = "Logging.nsh",
            symbol = _SYMBOLS[macro],
            un_symbol = _SYMBOLS[macro],
            parameters = ["in:text"],
            defines = defines,
        )
    return cases
