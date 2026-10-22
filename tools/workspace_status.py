#!/usr/bin/env python3
"""Bazel workspace status command.

Prints key/value pairs consumed by Bazel's `--workspace_status_command`.
Keys prefixed with STABLE_ trigger a rebuild of dependents when their value
changes; unprefixed keys do not.
"""

print("STABLE_TEST_VENDOR Rules Nsis Testing")
