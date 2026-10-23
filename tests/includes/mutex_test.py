import uuid

from tests.includes import common

# ValidateMutex's exit code when another instance holds the mutex.
_ALREADY_RUNNING = 10


def _hold(name):
    """Holds NAME's mutex as another running instance would; returns its handle."""
    import ctypes
    from ctypes import wintypes

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
    kernel.CreateMutexW.restype = wintypes.HANDLE
    handle = kernel.CreateMutexW(None, False, name + "Mutex")
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    return kernel, handle


def run_case(case, harness, args):
    if common.base(case) != "mutex":
        raise common.unhandled(case)
    name = "RulesNsisIncludeApi-" + str(uuid.uuid4())
    # The mutex is released when each harness process exits, so a second
    # sequential run also succeeds.
    for _ in range(2):
        assert harness.run(name=name).returncode == 0
    kernel, handle = _hold(name)
    try:
        harness.run(name=name, expected_exitcode=_ALREADY_RUNNING)
    finally:
        kernel.CloseHandle(handle)
    assert harness.run(name=name).returncode == 0


if __name__ == "__main__":
    common.main(run_case)
