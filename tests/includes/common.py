"""Shared helpers for the include API tests."""

import os
import platform
import sys

from python.runfiles import Runfiles

from nsis.testing import Harness


def rlocation(path):
    return Runfiles.Create().Rlocation(path)


def host_arch():
    machine = platform.machine().lower()
    if "arm" in machine:
        return "arm64" if "64" in machine else "arm32"
    return "x86_64" if "64" in machine else "x86_32"


def base(case):
    return case.removeprefix("un_")


def unhandled(case):
    return ValueError(f"Unhandled include API case: {case}")


def uninstall_key(product_code):
    return "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{" + product_code.upper() + "}"


def delete_registry_tree(winreg, path, root=None):
    root = winreg.HKEY_CURRENT_USER if root is None else root
    try:
        with winreg.OpenKey(root, path, 0, winreg.KEY_ALL_ACCESS) as key:
            while True:
                try:
                    child = winreg.EnumKey(key, 0)
                except OSError as error:
                    # ERROR_NO_MORE_ITEMS
                    if getattr(error, "winerror", None) == 259:
                        break
                    raise
                delete_registry_tree(winreg, path + "\\" + child, root)
        winreg.DeleteKey(root, path)
    except FileNotFoundError:
        pass


def assert_key_missing(winreg, path, root=None):
    root = winreg.HKEY_CURRENT_USER if root is None else root
    try:
        winreg.OpenKey(root, path)
    except FileNotFoundError:
        return
    raise AssertionError(f"registry key exists: {path}")


def main(run_case):
    """Runs the case named by the test arguments: CASE HARNESS DESCRIPTION [ARGS...]."""
    case, binary, description, *args = sys.argv[1:]
    with Harness(rlocation(binary), rlocation(description), directory=os.environ["TEST_TMPDIR"]) as harness:
        run_case(case, harness, args)
