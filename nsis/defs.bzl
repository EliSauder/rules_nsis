"""Public definitions for NSIS installers

Contains the public rulesets for creating installers using NSIS.

Definitions outside this file are subject to change without notice.
"""

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
