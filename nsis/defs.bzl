"""Public definitions for NSIS installers

Contains the public rulesets for creating installers using NSIS.

Definitions outside this file are subject to change without notice.
"""

load(
    "//nsis/private:options.bzl",
    _NsisOptionGroupInfo = "NsisOptionGroupInfo",
    _NsisOptionInfo = "NsisOptionInfo",
    _NsisOptionsPageInfo = "NsisOptionsPageInfo",
    _nsis_option = "nsis_option",
    _nsis_option_group = "nsis_option_group",
    _nsis_options_page = "nsis_options_page",
)
load(
    "//nsis/private:shortcuts.bzl",
    _NsisShortcutInfo = "NsisShortcutInfo",
    _nsis_shortcut = "nsis_shortcut",
)
load(
    "//nsis/private:defs.bzl",
    _nsis_installer = "nsis_installer",
    _nsis_component = "nsis_component",
    _nsis_component_group = "nsis_component_group",
    _nsis_directory = "nsis_directory",
    _nsis_eventlog_source = "nsis_eventlog_source",
)

nsis_directory = _nsis_directory
nsis_installer = _nsis_installer
nsis_component = _nsis_component
nsis_component_group = _nsis_component_group
nsis_eventlog_source = _nsis_eventlog_source
nsis_option = _nsis_option
nsis_option_group = _nsis_option_group
nsis_options_page = _nsis_options_page
NsisOptionInfo = _NsisOptionInfo
NsisOptionGroupInfo = _NsisOptionGroupInfo
NsisOptionsPageInfo = _NsisOptionsPageInfo
nsis_shortcut = _nsis_shortcut
NsisShortcutInfo = _NsisShortcutInfo
