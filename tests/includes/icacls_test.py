import os
import re
import subprocess

from tests.includes import common

_CASES = (
    "icacls_grant", "icacls_deny", "icacls_remove_grant",
    "icacls_remove_deny", "icacls_integrity", "icacls_substitute",
)

# Anonymous Logon: a SID that never applies to the test user, so ACEs for it
# cannot affect the harness itself.
_ANONYMOUS = "*S-1-5-7"
_SYSTEM = "*S-1-5-18"


def _icacls_params(base, path):
    params = {"path": str(path), "recursive": 0}
    if base in ("icacls_grant", "icacls_deny", "icacls_remove_grant", "icacls_remove_deny"):
        params["sid"] = _ANONYMOUS
    if base in ("icacls_grant", "icacls_deny"):
        params["permission"] = "R"
    if base == "icacls_integrity":
        params.update(level="Low", inheritance="")
    if base == "icacls_substitute":
        params.update(old_sid=_ANONYMOUS, new_sid=_SYSTEM)
    return params


def _security_descriptor(path):
    """Returns the DACL and mandatory label of PATH as an SDDL string."""
    import ctypes
    from ctypes import wintypes

    advapi = ctypes.WinDLL("advapi32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32")
    advapi.GetNamedSecurityInfoW.argtypes = [
        wintypes.LPCWSTR, ctypes.c_int, wintypes.DWORD, ctypes.c_void_p,
        ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p),
    ]
    advapi.GetNamedSecurityInfoW.restype = wintypes.DWORD
    advapi.ConvertSecurityDescriptorToStringSecurityDescriptorW.argtypes = [
        ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD,
        ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p,
    ]
    kernel.LocalFree.argtypes = [ctypes.c_void_p]
    information = 0x4 | 0x10  # DACL_SECURITY_INFORMATION | LABEL_SECURITY_INFORMATION
    descriptor = ctypes.c_void_p()
    error = advapi.GetNamedSecurityInfoW(str(path), 1, information, None, None, None, None, ctypes.byref(descriptor))
    if error:
        raise ctypes.WinError(error)
    try:
        text = ctypes.c_void_p()
        if not advapi.ConvertSecurityDescriptorToStringSecurityDescriptorW(
            descriptor, 1, information, ctypes.byref(text), None,
        ):
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            return ctypes.wstring_at(text.value)
        finally:
            kernel.LocalFree(text)
    finally:
        kernel.LocalFree(descriptor)


def _aces(path):
    """Parses SDDL ACEs into (type, flags, rights, sid) tuples."""
    aces = []
    for ace in re.findall(r"\(([^)]*)\)", _security_descriptor(path)):
        fields = ace.split(";")
        aces.append((fields[0], fields[1], fields[2], fields[5]))
    return aces


def _explicit(path, ace_type, sids):
    return [ace for ace in _aces(path) if ace[0] == ace_type and ace[3] in sids and "ID" not in ace[1]]


def _icacls(*args):
    subprocess.run(
        [os.path.join(os.environ["SystemRoot"], "System32", "icacls.exe"), *args],
        check=True, capture_output=True,
    )


def run_case(case, harness, args):
    base = common.base(case)
    if base not in _CASES:
        raise common.unhandled(case)
    anonymous = ("AN", "S-1-5-7")
    system = ("SY", "S-1-5-18")
    # Failures must be reported now that icacls no longer runs with /C.
    missing = _icacls_params(base, harness.directory / "missing path")
    assert harness.run(**missing).outputs["result"] not in ("", "0")

    folder = harness.directory / "acl target with spaces"
    folder.mkdir()
    target = folder / "file name.txt"
    target.write_text("acl", encoding="utf-8")
    params = _icacls_params(base, target)
    if base == "icacls_grant":
        harness.run(**params).assert_outputs(result="0")
        assert _explicit(target, "A", anonymous), _aces(target)
        child = folder / "child.txt"
        child.write_text("child", encoding="utf-8")
        assert not _explicit(child, "A", anonymous), _aces(child)
        harness.run(**{**params, "path": str(folder), "recursive": 1}).assert_outputs(result="0")
        assert _explicit(folder, "A", anonymous), _aces(folder)
        assert _explicit(child, "A", anonymous), _aces(child)
    elif base == "icacls_deny":
        harness.run(**params).assert_outputs(result="0")
        assert _explicit(target, "D", anonymous), _aces(target)
    elif base in ("icacls_remove_grant", "icacls_remove_deny"):
        ace_type = "A" if base == "icacls_remove_grant" else "D"
        _icacls(str(target), "/grant" if ace_type == "A" else "/deny", _ANONYMOUS + ":R")
        assert _explicit(target, ace_type, anonymous), _aces(target)
        harness.run(**params).assert_outputs(result="0")
        assert not _explicit(target, ace_type, anonymous), _aces(target)
    elif base == "icacls_integrity":
        harness.run(**params).assert_outputs(result="0")
        labels = [ace for ace in _aces(target) if ace[0] == "ML"]
        assert [ace for ace in labels if ace[3] == "LW" and "OI" not in ace[1]], labels
        harness.run(**{**params, "path": str(folder), "inheritance": "(OI)"}).assert_outputs(result="0")
        labels = [ace for ace in _aces(folder) if ace[0] == "ML"]
        assert [ace for ace in labels if ace[3] == "LW" and "OI" in ace[1]], labels
    elif base == "icacls_substitute":
        _icacls(str(target), "/grant", _ANONYMOUS + ":R")
        harness.run(**params).assert_outputs(result="0")
        assert not _explicit(target, "A", anonymous), _aces(target)
        assert _explicit(target, "A", system), _aces(target)


if __name__ == "__main__":
    common.main(run_case)
