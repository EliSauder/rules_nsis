import ctypes
import os
import uuid
import hashlib
import time
import psutil
import json
import pathlib
import shutil
import subprocess
import sys
import unittest
import winreg
import logging
from contextlib import contextmanager, nullcontext
from ctypes import wintypes

from python.runfiles import Runfiles

TEST_TMPDIR = None
TEST_ID = None

def _print_directory_tree(indir: str) -> str:
    out = indir + os.path.sep + "\n"
    for root, dirs, files in os.walk(indir):
        level = root.replace(indir, '').count(os.sep)
        indent = ' ' * 4 * (level + 1)
        out = out + '{}{}{}\n'.format(indent, os.path.basename(root), os.path.sep)
        subindent = ' ' * 4 * (level + 2)
        for f in files:
            out = out + '{}{}\n'.format(subindent, f)

    return out

def _print_environ() -> str:
    out = ""
    for k, v in os.environ.items():
        out = out + "{}={}\n".format(k, v)
    return out

def _print_args() -> str:
    out = ""
    for a in sys.argv:
        out = out + "{}\n".format(a)
    return out

print("cwd=", os.getcwd())
print("dircontent=\n", _print_directory_tree(os.getcwd()))
print("environment=\n", _print_environ())
print("args=\n", _print_args())

RUNFILES = Runfiles.Create()
if RUNFILES == None:
    raise SystemExit("runfiles is none")

env = os.environ.copy()
env.update(RUNFILES.EnvVars())

INSTALLER=None
CONFIG=None

def _get_sub_path(product_path, vendor_path, install_path) -> str:
    subpath = ""
    if install_path != None:
        subpath = str(install_path)

    if product_path == None:
        raise SystemError("both install path and product path can not be None")

    if vendor_path != None:
        subpath = f"{str(vendor_path)}\\{str(product_path)}"
    else:
        subpath = str(product_path)

    return subpath

def _get_reg_paths(subpath, appkey) -> (str, str):
    return (
        f"Software\\{subpath}\\{TEST_ID}",
        f"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{{{appkey.upper()}}}\\{TEST_ID}"
    )

def _get_reg_db(execution_level: str) -> int:
    if execution_level == "admin":
        return winreg.HKEY_LOCAL_MACHINE
    if execution_level == "user":
        return winreg.HKEY_CURRENT_USER

    raise OSError(f"unsupported execution_level {execution_level}")

def _get_reg_view(bitwidth: str) -> int:
    if bitwidth == "32":
        return winreg.KEY_WOW64_32KEY
    if bitwidth == "64":
        return winreg.KEY_WOW64_64KEY

    raise OSError(f"unsupported bitwidth {bitwidth}")

def _get_reg_access(bitwidth: str) -> int:
    access = winreg.KEY_READ | winreg.KEY_QUERY_VALUE
    access |= _get_reg_view(bitwidth)
    return access

def _reg_open(root_db: int, path: str, view: int):
    try:
        return winreg.OpenKey(root_db, path, 0, view)
    except FileNotFoundError as e:
        raise FileNotFoundError(f"error opening key {path}: {e}")

def _reg_value(root: int, path: str, view: int, name: str):
    with _reg_open(root, path, view) as hkey:
        value, value_type = winreg.QueryValueEx(hkey, name)
        return value, value_type

def _validate_removed_reg(testcase: unittest.TestCase, config: dict, subpath: str, appkey: str):
    exlvl = (config["expected_execution_level"] or "admin")
    root = _get_reg_db(exlvl)

    inpath, unpath = _get_reg_paths(subpath, appkey)
    access = _get_reg_access(config["expected_bitwidth"] or "64")

    for path in _state_registry_paths(config, subpath):
        _assert_registry_absent(testcase, root, path, access)

    try:
        with _reg_open(root, inpath, access):
            testcase.fail(f"Registry key {inpath} still exists")
    except FileNotFoundError:
        pass

    try:
        with _reg_open(root, unpath, access):
            testcase.fail(f"Registry key {inpath} still exists")
    except FileNotFoundError:
        pass

    try:
        _reg_value(root, inpath, access, "InstallDir")
        testcase.fail(f"Registry key {inpath} with value InstallDir still exists")
    except FileNotFoundError:
        pass
    try:
        _reg_value(root, inpath, access, "Version")
        testcase.fail(f"Registry key {inpath} with value Version still exists")
    except FileNotFoundError:
        pass
    try:
        _reg_value(root, unpath, access, "DisplayName")
        testcase.fail(f"Registry key {unpath} with value DisplayName still exists")
    except FileNotFoundError:
        pass
    try:
        _reg_value(root, unpath, access, "DisplayVersion")
        testcase.fail(f"Registry key {unpath} with value DisplayVersion still exists")
    except FileNotFoundError:
        pass
    try:
        _reg_value(root, unpath, access, "InstallLocation")
        testcase.fail(f"Registry key {unpath} with value InstallLocatino still exists")
    except FileNotFoundError:
        pass
    try:
        _reg_value(root, unpath, access, "Publisher")
        testcase.fail(f"Registry key {unpath} with value Publisher still exists")
    except FileNotFoundError:
        pass
    try:
        _reg_value(root, unpath, access, "UninstallString")
        testcase.fail(f"Registry key {unpath} with value UninstallString still exists")
    except FileNotFoundError:
        pass
    try:
        _reg_value(root, unpath, access, "NoRepair")
        testcase.fail(f"Registry key {unpath} with value NoRepair still exists")
    except FileNotFoundError:
        pass
    try:
        _reg_value(root, unpath, access, "NoModify")
        testcase.fail(f"Registry key {unpath} with value NoModify still exists")
    except FileNotFoundError:
        pass
    try:
        _reg_value(root, unpath, access, "DisplayIcon")
        testcase.fail(f"Registry key {unpath} with value DisplayIcon still exists")
    except FileNotFoundError:
        pass

def _get_eventlog_registry_path(key: str, src: str) -> str:
    return f"SYSTEM\\CurrentControlSet\\Services\\EventLog\\{key}\\{src}\\{TEST_ID}"

def _validate_eventlog(testcase: unittest.TestCase, config: dict, appkey: str):
    exlvl = (config["expected_execution_level"] or "admin")
    if exlvl != "admin":
        return

    root = _get_reg_db("admin") # Event log registry is always against local machine
    access = winreg.KEY_READ | winreg.KEY_QUERY_VALUE


    for k, v in config["expected_eventlog"].items():
        reg_path = _get_eventlog_registry_path(v["key"], v["source"])
        with _reg_open(root, reg_path, access): pass

        st = 0
        for t in v["supported_types"]:
            if t == "error":
                st = st + 1
            elif t == "warning":
                st = st + 2
            elif t == "information":
                st = st + 4


        valEmh, typEmh = _reg_value(root, reg_path, access, "EventMessageFile")
        emf = ";".join(v["event_message_files"])
        testcase.assertEqual(
            valEmh,
            emf,
            f"EventMessageFile {valEmh} != '{emf}'"
        )
        testcase.assertEqual(typEmh, winreg.REG_EXPAND_SZ)

        valTs, typTs = _reg_value(root, reg_path, access, "TypesSupported")
        testcase.assertEqual(
            valTs,
            st,
            f"TypesSupported {valTs} != {st} (1 | 2 | 4 [Error | Warn | Info])"
        )
        testcase.assertEqual(typTs, winreg.REG_DWORD)

        cmf = ";".join(v["category_message_files"])
        if cmf and len(cmf) > 0:
            valcmf, typcmf = _reg_value(root, reg_path, access, "CategoryMessageFile")
            testcase.assertEqual(
                valcmf,
                cmf,
                f"CategoryMessageFile {valcmf} != {cmf}"
            )
            testcase.assertEqual(typcmf, winreg.REG_EXPAND_SZ)
        pmf = ";".join(v["parameter_message_files"])
        if pmf and len(pmf) > 0:
            valpmf, typpmf = _reg_value(root, reg_path, access, "ParameterMessageFile")
            testcase.assertEqual(
                valpmf,
                pmf,
                f"ParameterMessageFile {valpmf} != {pmf}"
            )
            testcase.assertEqual(typpmf, winreg.REG_EXPAND_SZ)


def _validate_removed_eventlog(testcase: unittest.TestCase, config: dict, appkey: str):
    exlvl = (config["expected_execution_level"] or "admin")
    if exlvl != "admin":
        return

    root = _get_reg_db("admin") # Event log registry is always against local machine
    access = winreg.KEY_READ | winreg.KEY_QUERY_VALUE

    for k, v in config["expected_eventlog"].items():
        reg_path = _get_eventlog_registry_path(v["key"], v["source"])
        try:
            with _reg_open(root, reg_path, access):
                testcase.fail(f"Registry key {reg_path} still exists")
        except FileNotFoundError:
            pass


def _validate_reg(testcase: unittest.TestCase, config: dict, inst_root: str, subpath: str, appkey: str):
    exlvl = (config["expected_execution_level"] or "admin")
    root = _get_reg_db(exlvl)

    inpath, unpath = _get_reg_paths(subpath, appkey)
    access = _get_reg_access(config["expected_bitwidth"] or "64")

    with _reg_open(root, inpath, access): pass
    with _reg_open(root, unpath, access): pass

    instdirval, instdirtyp = _reg_value(root, inpath, access, "InstallDir")
    versionval, versiontyp = _reg_value(root, inpath, access, "Version")
    _reg_value(root, unpath, access, "DisplayName")
    unversionval, unversiontyp = _reg_value(root, unpath, access, "DisplayVersion")
    _reg_value(root, unpath, access, "Publisher")
    unstr, unstrtyp = _reg_value(root, unpath, access, "UninstallString")
    _reg_value(root, unpath, access, "NoRepair")
    _reg_value(root, unpath, access, "NoModify")
    instlocval, instloctyp = _reg_value(root, unpath, access, "InstallLocation")

    if config.get("expected_icon"):
        iconval, icontyp = _reg_value(root, unpath, access, "DisplayIcon")
        testcase.assertEqual(icontyp, winreg.REG_SZ)
        testcase.assertEqual(
            f"{inst_root}\\{config['expected_uninstaller_name']},0",
            iconval,
            f"expected {unpath}\\DisplayIcon to reference the uninstaller icon",
        )

    testcase.assertEqual(
        inst_root,
        instdirval,
        f"expected {inpath}\\InstallDir to equal install path",
    )
    testcase.assertEqual(
        f"{inst_root}\\{config['expected_uninstaller_name']}",
        unstr,
        f"expected {unpath}\\UninstallString to reference the uninstaller",
    )
    testcase.assertEqual(
        versionval,
        unversionval,
        f"expected install version {versionval} to equal uninstall version {unversionval}",
    )
    testcase.assertEqual(
        inst_root,
        instlocval,
        f"expected {unpath}\\InstallLocation to equal install path",
    )

def _get_pre_install_root(hs: int, init: bool = True):
    rt = f"{TEST_TMPDIR}\\pre-install-{hs}"

    if init:
        pth = pathlib.Path(rt).resolve()
        if pth.exists():
            shutil.rmtree(pth)
        pth.mkdir(parents=True, exist_ok=True)

    return rt

def _get_install_root():
    install_root = f"{TEST_TMPDIR}\\nsis-install-root"

    pth = pathlib.Path(install_root).resolve()

    if pth.exists():
        shutil.rmtree(pth)
    pth.mkdir(parents=True, exist_ok=True)

    return install_root

_CSIDL_LOCAL_APPDATA = 0x1C

def _local_appdata() -> str:
    # Same API NSIS uses for $LOCALAPPDATA; the test env may not carry the variable.
    buf = ctypes.create_unicode_buffer(260)
    hr = ctypes.windll.shell32.SHGetFolderPathW(None, _CSIDL_LOCAL_APPDATA, None, 0, buf)
    if hr != 0:
        raise OSError(f"SHGetFolderPathW(CSIDL_LOCAL_APPDATA) failed: {hr:#x}")
    return buf.value

def _program_files(bitwidth: str) -> str:
    # NSIS reads $PROGRAMFILES/$PROGRAMFILES64 from this value in the 32/64-bit registry view.
    access = winreg.KEY_READ | _get_reg_view(bitwidth)
    with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion", 0, access) as key:
        return winreg.QueryValueEx(key, "ProgramFilesDir")[0]

def _expand_nsis_vars(path: str) -> str:
    for var, value in [
        ("$LOCALAPPDATA", _local_appdata),
        ("$PROGRAMFILES64", lambda: _program_files("64")),
        ("$PROGRAMFILES", lambda: _program_files("32")),
    ]:
        if var in path:
            path = path.replace(var, value())
    if "$" in path:
        raise ValueError(f"unsupported NSIS variable in install root {path!r}")
    return path

def _get_default_install_dir(config: dict) -> str:
    """The InstallDir an installer uses when run without /D=."""
    root = config["expected_install_root"]
    if not root:
        if (config["expected_execution_level"] or "admin") == "user":
            root = "$LOCALAPPDATA\\Programs"
        elif config["expected_bitwidth"] == "64":
            root = "$PROGRAMFILES64"
        else:
            root = "$PROGRAMFILES"

    subpath = config["expected_install_path"]
    if not subpath:
        subpath = config["expected_product_path"]
        if config["expected_vendor_path"]:
            subpath = f"{config['expected_vendor_path']}\\{subpath}"

    install_dir = f"{_expand_nsis_vars(root)}\\{subpath}"

    # Leftovers from an aborted earlier run would mask a wrong default.
    if os.path.exists(install_dir):
        shutil.rmtree(install_dir)

    return install_dir

def _get_app_key_and_subpath(config: dict) -> str:
    subpath = _get_sub_path(
        config["expected_product"] or None,
        config["expected_vendor"] or None,
        None,
    )
    return subpath, (config["expected_id"] or "").replace("\\", " ")


def _nsis_cmdline(args, path_arg):
    """Joins args, appending path_arg (/D= or _?=) last and unquoted.

    NSIS only recognises /D= and _?= unquoted, even with spaces in the path.
    A quoted _?= makes the uninstaller re-launch itself from %TEMP% and exit
    0 before it has uninstalled anything.
    """
    return f"{subprocess.list2cmdline(args)} {path_arg}"

def _get_uninstaller_cmd(install_root, config):
    base_uninstaller = os.path.join(install_root, config["expected_uninstaller_name"])
    new_uninstaller_path = os.path.join(TEST_TMPDIR, "Uninstall.exe")
    shutil.copy(base_uninstaller, new_uninstaller_path)
    return _nsis_cmdline(
        [new_uninstaller_path, "/S", f"/TESTID={TEST_ID}"],
        f"_?={install_root}",
    )

def _get_installer_cmd(installer, install_root, config):
    installer_args = list(config.get("installer_args", []))
    cmd = [
        str(installer),
        "/S",
        f"/TESTID={TEST_ID}",
    ] + installer_args
    if not (config.get("reinstall_without_dir") or config.get("default_install_dir")):
        return _nsis_cmdline(cmd, f"/D={install_root}")
    return cmd

def _validate_removed_files(testcase: unittest.TestCase, config: dict, install_root: str):
    expected_files = [*config.get("expected_files", []), config["expected_uninstaller_name"]]
    dircontent = _print_directory_tree(install_root)

    for path in expected_files:
        if not os.path.isabs(path):
            path = os.path.join(install_root, path)

        testcase.assertFalse(os.path.exists(path), f"File: '{path}' exists after uninstall. Install Root Content: \n{dircontent}")

    if os.path.exists(install_root):
        testcase.fail(f"Install root directory left over {install_root}. Content: {dircontent}")

def _validate_removed_directories(testcase: unittest.TestCase, config):
    expected_dirs = config.get("expected_dirs", {})

    for key, val in expected_dirs.items():
        testcase.assertFalse(os.path.exists(key), f"Directory still exists after uninstall: {key}")

def _validate_directories(testcase: unittest.TestCase, config):
    expected_dirs = config.get("expected_dirs", {})

    for key, val in expected_dirs.items():
        testcase.assertTrue(os.path.exists(key), f"Expected directory does not exist: {key}")
        testcase.assertFalse(os.path.isfile(key), f"Expected directory is actually a file: {key}")
        testcase.assertTrue(os.path.isdir(key), f"Expected directory is not a directory: {key}")


def _validate_files(testcase: unittest.TestCase, config, install_root):
    expected_files = [*config.get("expected_files", []), config["expected_uninstaller_name"]]
    for path in expected_files:
        if not os.path.isabs(path):
            path = os.path.join(install_root, path)

        dir = pathlib.Path(install_root).resolve()
        fs = [x.as_uri() for x in dir.iterdir() if x.is_file()]

        testcase.assertTrue(os.path.exists(path), f"Expected file missing: {path}. Found: {fs}")
        testcase.assertFalse(os.path.isdir(path), f"Expected file is a directory: {path}. Found: {fs}")
        testcase.assertTrue(os.path.isfile(path), f"Expected file is not a file: {path}. Found: {fs}")
    for path in config.get("absent_files", []):
        testcase.assertFalse(os.path.exists(os.path.join(install_root, path)),
                             f"Unselected component installed {path}")


@contextmanager
def _windows_state_lock():
    # PATH and shell folders are shared even when registry keys use /TESTID.
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
    kernel32.CreateMutexW.restype = wintypes.HANDLE
    kernel32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel32.WaitForSingleObject.restype = wintypes.DWORD
    kernel32.ReleaseMutex.argtypes = [wintypes.HANDLE]
    kernel32.ReleaseMutex.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    handle = kernel32.CreateMutexW(None, False, r"Global\rules_nsis_tests_windows_state")
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    acquired = False
    try:
        result = kernel32.WaitForSingleObject(handle, 240000)
        if result == 0xFFFFFFFF:
            raise ctypes.WinError(ctypes.get_last_error())
        if result not in (0, 0x80):  # WAIT_OBJECT_0 or WAIT_ABANDONED
            raise TimeoutError(f"Waiting for Windows state test mutex failed: {result:#x}")
        acquired = True
        yield
    finally:
        if acquired:
            released = kernel32.ReleaseMutex(handle)
            error = ctypes.get_last_error()
        closed = kernel32.CloseHandle(handle)
        if acquired and not released:
            raise ctypes.WinError(error)
        if not closed:
            raise ctypes.WinError(ctypes.get_last_error())


def _shell_folder(csidl):
    buffer = ctypes.create_unicode_buffer(260)
    result = ctypes.windll.shell32.SHGetFolderPathW(None, csidl, None, 0, buffer)
    if result:
        raise OSError(f"SHGetFolderPathW({csidl:#x}) failed: {result:#x}")
    return pathlib.Path(buffer.value)


def _shortcut_paths(config):
    options = config.get("shortcut_options", {})
    if not config.get("expected_shortcuts"):
        return []
    admin = (config["expected_execution_level"] or "admin") == "admin"
    programs = _shell_folder(0x17 if admin else 0x02)
    desktop = _shell_folder(0x19 if admin else 0x10)
    folder = programs / options["start_menu_folder"]
    enabled = options["enabled"] == "1"
    result = []
    for shortcut in config["expected_shortcuts"]:
        for location, base in [
            ("start_menu", folder / shortcut["start_menu_subfolder"]),
            ("desktop", desktop),
        ]:
            if shortcut[location]:
                result.append((
                    shortcut["component"], base / (shortcut["link_name"] + ".lnk"),
                    shortcut["selected"] and enabled and options[location] == "1",
                    programs if location == "start_menu" else desktop,
                ))
    return result


def _state_registry_paths(config, subpath):
    base = f"Software\\{subpath}"
    _, appkey = _get_app_key_and_subpath(config)
    paths = [*_get_reg_paths(subpath, appkey), f"{base}\\Options\\{TEST_ID}"]
    for component in config.get("component_names", []):
        paths.extend([
            f"{base}\\Shortcuts\\{component}\\{TEST_ID}",
            f"{base}\\Components\\{component}\\{TEST_ID}",
        ])
    return paths


def _assert_registry_absent(testcase, root, path, access):
    with testcase.assertRaises(FileNotFoundError, msg=f"Registry key still exists: {path}"):
        with winreg.OpenKey(root, path, 0, access):
            pass


def _registry_values(root, path, access):
    with winreg.OpenKey(root, path, 0, access) as handle:
        return {
            name: (value, kind)
            for name, value, kind in (
                winreg.EnumValue(handle, index)
                for index in range(winreg.QueryInfoKey(handle)[1])
            )
        }


def _validate_options_and_components(testcase, config, subpath):
    root = _get_reg_db(config["expected_execution_level"] or "admin")
    access = _get_reg_access(config["expected_bitwidth"] or "64")
    base = f"Software\\{subpath}"
    expected = dict(config.get("expected_options", {}))
    expected.update({f"shortcuts.{key}": [value]
                     for key, value in config.get("shortcut_options", {}).items()})
    options_path = f"{base}\\Options\\{TEST_ID}"
    for name, value in expected.items():
        testcase.assertEqual(_reg_value(root, options_path, access, name),
                             (value, winreg.REG_MULTI_SZ), name)
    for name in config.get("absent_options", []):
        with testcase.assertRaises(FileNotFoundError, msg=f"Option {name} was persisted"):
            _reg_value(root, options_path, access, name)
    links_by_component = {}
    for component, path, wanted, _ in _shortcut_paths(config):
        links_by_component.setdefault(component, [])
        if wanted:
            links_by_component[component].append(str(path))
    for component in config.get("component_names", []):
        # Component metadata currently consists of shortcut ownership records;
        # the generated installer does not write a separate Components subtree.
        _assert_registry_absent(testcase, root, f"{base}\\Components\\{component}\\{TEST_ID}", access)
        path = f"{base}\\Shortcuts\\{component}\\{TEST_ID}"
        links = links_by_component.get(component, [])
        if not links:
            _assert_registry_absent(testcase, root, path, access)
            continue
        records = _registry_values(root, path, access)
        testcase.assertEqual(
            {name: value for name, value in records.items() if name.isdecimal()},
            {str(index): (link, winreg.REG_SZ) for index, link in enumerate(links)},
        )
        folders = {name: value for name, value in records.items() if not name.isdecimal()}
        count = len(folders) // 2
        testcase.assertEqual(set(folders),
                             {f"{prefix}{index}" for prefix in ("d", "s") for index in range(count)})
        for index in range(count):
            directory, kind = folders[f"d{index}"]
            stop, stop_kind = folders[f"s{index}"]
            testcase.assertEqual((kind, stop_kind), (winreg.REG_SZ, winreg.REG_SZ))
            directory, stop = pathlib.Path(directory), pathlib.Path(stop)
            testcase.assertTrue(directory.is_dir(), str(directory))
            testcase.assertIn(stop, directory.parents)
            testcase.assertTrue(any(pathlib.Path(link).parent == directory for link in links))


def _capture_windows_state(testcase, configs):
    changes_path = any(c.get("expected_path_dirs") or c.get("absent_path_dirs") for c in configs)
    testcase.initial_path = {
        level: _path_entries({"expected_execution_level": level})
        for level in ("user", "admin") if changes_path
    }
    testcase.initial_shortcut_dirs = {}
    testcase.state_registry_keys = []
    for config in configs:
        subpath, _ = _get_app_key_and_subpath(config)
        root = _get_reg_db(config["expected_execution_level"] or "admin")
        access = _get_reg_access(config["expected_bitwidth"] or "64")
        for key in _state_registry_paths(config, subpath):
            _assert_registry_absent(testcase, root, key, access)
            testcase.state_registry_keys.append((root, key, access))
        for _, path, _, boundary in _shortcut_paths(config):
            testcase.assertFalse(path.exists(), f"Test would overwrite shortcut {path}")
            directory = path.parent
            while directory != boundary:
                testcase.initial_shortcut_dirs[directory] = directory.exists()
                directory = directory.parent


def _validate_restored_windows_state(testcase):
    for root, key, access in testcase.state_registry_keys:
        _assert_registry_absent(testcase, root, key, access)
    for level, before in testcase.initial_path.items():
        testcase.assertEqual(_path_entries({"expected_execution_level": level}), before,
                             f"{level} PATH was not restored")
    for directory, existed in testcase.initial_shortcut_dirs.items():
        testcase.assertEqual(directory.exists(), existed,
                             f"Shortcut directory state was not restored: {directory}")

def _path_entries(config):
    if (config["expected_execution_level"] or "admin") == "admin":
        root, key = winreg.HKEY_LOCAL_MACHINE, r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
    else:
        root, key = winreg.HKEY_CURRENT_USER, "Environment"
    try:
        with winreg.OpenKey(root, key) as handle:
            value, _ = winreg.QueryValueEx(handle, "Path")
    except FileNotFoundError:
        return []
    return [x.rstrip("\\").lower() for x in value.split(";") if x]


def _expected_path_entry(install_root, directory):
    return os.path.join(install_root, directory).rstrip("\\").lower()


def _validate_path(testcase, config, install_root):
    entries = _path_entries(config)
    if config.get("expected_path_dirs") or config.get("absent_path_dirs"):
        level = config["expected_execution_level"] or "admin"
        added = {_expected_path_entry(install_root, d)
                 for d in config.get("expected_path_dirs", [])}
        testcase.assertEqual([entry for entry in entries if entry not in added],
                             testcase.initial_path[level],
                             "Installer changed unrelated PATH entries")
        other_level = "user" if level == "admin" else "admin"
        testcase.assertEqual(_path_entries({"expected_execution_level": other_level}),
                             testcase.initial_path[other_level],
                             "Installer changed PATH in the wrong hive")
    for d in config.get("expected_path_dirs", []):
        expected = _expected_path_entry(install_root, d)
        testcase.assertEqual(1, entries.count(expected), f"Expected exactly one PATH entry {expected}. PATH: {entries}")
    for d in config.get("absent_path_dirs", []):
        testcase.assertNotIn(_expected_path_entry(install_root, d), entries)


def _validate_removed_path(testcase, config, install_root):
    entries = _path_entries(config)
    for d in config.get("expected_path_dirs", []) + config.get("absent_path_dirs", []):
        expected = _expected_path_entry(install_root, d)
        testcase.assertNotIn(expected, entries, f"PATH entry {expected} left after uninstall")


def _validate_removed_services(testcase, config, install_root):
    expected_services = config.get("expected_services", {})

    for key, val in expected_services.items():
        try:
            svc = psutil.win_service_get(key)
        except:
            continue
        testcase.fail(f"Windows service {key}, still exists")


def _validate_services(testcase, config, install_root):
    expected_services = config.get("expected_services", {})

    for key, val in expected_services.items():
        svc = psutil.win_service_get(key)

        testcase.assertEqual(key, svc.name(), f"Unexpected name {svc.name()}, expected {key}. WTF How did this happen?")

        testcase.assertEqual(val["display_name"], svc.display_name(), f"Display name '{svc.display_name()}' does not equal expected '{val['display_name']}'")

        exe = os.path.join(install_root, val["executable"])
        for arg in list(val["args"]):
            exe = exe + " " + arg
        exe = exe.strip()
        bin = svc.binpath().strip()
        testcase.assertEqual(exe, bin, f"Executable '{bin}' not equal expected '{exe}'")

        expst = ""
        if val["start_type"] == "auto":
            expst = "automatic"
        elif val["start_type"] == "demand":
            expst = "manual"
        else:
            expst = val["start_type"]

        testcase.assertEqual(expst, svc.start_type(), f"Start type {svc.start_type()} not equal expected {expst}")

        expected_description = val["description"].replace("\r\n", "\n")
        actual_description = svc.description().replace("\r\n", "\n")
        testcase.assertEqual(expected_description, actual_description, f"Description '{svc.description()}' not equal expected '{val['description']}'")

def _validate_file_contents(testcase, expected: dict, root: str):
    for path, content in expected.items():
        if not os.path.isabs(path):
            path = os.path.join(root, path)
        testcase.assertTrue(os.path.isfile(path), f"Expected file missing: {path}")
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            actual = f.read().replace("\r\n", "\n")
        testcase.assertEqual(content, actual, f"Unexpected content in {path}")

def _validate_install(testcase, install_root, subpath, appkey, config, installer):
    installer_cmd = _get_installer_cmd(installer, install_root, config)

    proc = subprocess.run(
        installer_cmd,
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
        env=env,
    )

    expcode = config["expected_installer_exitcode"]
    testcase.assertEqual(
        proc.returncode,
        expcode,
        f"Expected exitcode {expcode}, got exit_code: {proc.returncode}\ncmd: {installer_cmd}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}\n",
    )

    if proc.returncode != 0:
        return True

    log = logging.getLogger("NsisInstallerTest.test_installer")
    log.debug("nsis stdout=%r", proc.stdout)
    log.debug("nsis stderr=%r", proc.stderr)

    with testcase.subTest(msg="Validate Installed Files"):
        _validate_files(testcase, config, install_root)
    with testcase.subTest(msg="Validate Installed Directories"):
        _validate_directories(testcase, config)
    with testcase.subTest(msg="Validate Installed File Contents"):
        _validate_file_contents(testcase, config.get("expected_file_contents", {}), install_root)
    with testcase.subTest(msg="Validate Installed Registry Keys"):
        _validate_reg(testcase, config, install_root, subpath, appkey)
    with testcase.subTest(msg="Validate Persisted Options and Component Registry"):
        _validate_options_and_components(testcase, config, subpath)
    with testcase.subTest(msg="Validate Shortcuts"):
        for _, path, wanted, _ in _shortcut_paths(config):
            testcase.assertEqual(path.is_file(), wanted, str(path))
    with testcase.subTest(msg="Validate Installed Services"):
        _validate_services(testcase, config, install_root)
    with testcase.subTest(msg="Validate PATH"):
        _validate_path(testcase, config, install_root)
    with testcase.subTest(msg="Validate EventLog Registry"):
        _validate_eventlog(testcase, config, appkey)

    return False

def _validate_uninstall(testcase, install_root, subpath, appkey, config, runun=True):
    if runun:
        uninstaller_cmd = _get_uninstaller_cmd(install_root, config)

        proc = subprocess.run(
            uninstaller_cmd,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
            env=env,
        )

        testcase.assertEqual(0, proc.returncode, f"Uninstaller failed.\nexit_code: {proc.returncode}\ncmd: {uninstaller_cmd}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}\n")

        log = logging.getLogger("NsisInstallerTest.test_installer")
        log.debug("nsis uninstall stdout=%r", proc.stdout)
        log.debug("nsis uninstall stderr=%r", proc.stderr)

    with testcase.subTest(msg="Validate Uninstall File Contents"):
        _validate_file_contents(testcase, config.get("expected_uninstall_file_contents", {}), TEST_TMPDIR)
    with testcase.subTest(msg="Validate Removed Files"):
        _validate_removed_files(testcase, config, install_root)
    with testcase.subTest(msg="Validate Removed Directories"):
        _validate_removed_directories(testcase, config)
    with testcase.subTest(msg="Validate Removed Registry Keys"):
        _validate_removed_reg(testcase, config, subpath, appkey)
    with testcase.subTest(msg="Validate Removed Shortcuts"):
        for _, path, _, _ in _shortcut_paths(config):
            testcase.assertFalse(path.exists(), f"Shortcut left after uninstall: {path}")
    with testcase.subTest(msg="Validate Removed Services"):
        _validate_removed_services(testcase, config, install_root)
    with testcase.subTest(msg="Validate Removed PATH"):
        _validate_removed_path(testcase, config, install_root)
    with testcase.subTest(msg="Validate Removed EventLog Reg"):
        _validate_removed_eventlog(testcase, config, appkey)

def _install_first(testcase: unittest.TestCase, config):
    rt = _get_pre_install_root(hash(config["installer_path"]))
    subpath, appkey = _get_app_key_and_subpath(config)
    installer = RUNFILES.Rlocation(config["installer_path"])
    _validate_install(testcase, rt, subpath, appkey, config, installer)

def _install_first_validate_removed(testcase: unittest.TestCase, config):
    rt = _get_pre_install_root(hash(config["installer_path"]), False)
    subpath, appkey = _get_app_key_and_subpath(config)
    _validate_uninstall(testcase, rt, subpath, appkey, config, False)

class NsisInstallerTest(unittest.TestCase):
    def test_installer(self) -> None:
        configs = [CONFIG, *CONFIG["install_first_and_remove"]]
        shared_state = any(
            c.get("expected_path_dirs") or c.get("absent_path_dirs") or c.get("expected_shortcuts")
            for c in configs
        )
        lock = _windows_state_lock() if shared_state else nullcontext()
        with lock:
            _capture_windows_state(self, configs)
            try:
                self.check_installer()
            finally:
                with self.subTest(msg="Validate Restored Windows State"):
                    _validate_restored_windows_state(self)

    def check_installer(self) -> None:

        installer = INSTALLER
        config = CONFIG

        exp_inst_name = config.get("expected_installer_name", "")
        bn = os.path.basename(installer)
        with self.subTest(msg="Validate Installer Name"):
            self.assertEqual(exp_inst_name, bn,
                f"Installer {bn} does not match expected name {exp_inst_name}",
            )

        for c in config["install_first_and_remove"]:
            _install_first(self, c)

        if config.get("default_install_dir"):
            install_root = _get_default_install_dir(config)
        else:
            install_root = _get_install_root()
        subpath, appkey = _get_app_key_and_subpath(config)

        if config.get("reinstall_without_dir"):
            first = _nsis_cmdline([str(installer), "/S", f"/TESTID={TEST_ID}"], f"/D={install_root}")
            proc = subprocess.run(first, capture_output=True, text=True, timeout=120, check=False, env=env)
            self.assertEqual(proc.returncode, 0, f"First install failed\ncmd: {first}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}\n")

        try:
            res = _validate_install(self, install_root, subpath, appkey, config, installer)
        finally:
            if os.path.isfile(os.path.join(install_root, config["expected_uninstaller_name"])):
                _validate_uninstall(self, install_root, subpath, appkey, config)
        if res:
            return

        if config.get("default_install_dir") and config["expected_install_root"]:
            try:
                os.rmdir(os.path.dirname(install_root))
            except OSError:
                pass

        for c in config["install_first_and_remove"]:
            _install_first_validate_removed(self, c)



if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemError("Expected argv: <installer_path> <config_json>")

    TEST_TMPDIR = os.path.abspath(str(os.environ["TEST_TMPDIR"]))

    m = hashlib.sha256()
    m.update(TEST_TMPDIR.encode('utf-8'))
    TEST_ID = m.hexdigest()

    INSTALLER = RUNFILES.Rlocation(sys.argv[1])
    print("installer path=", INSTALLER)
    print("installer base path=", os.path.dirname(INSTALLER))
    print("installer base path content=", _print_directory_tree(os.path.dirname(INSTALLER)))

    print("installer repr=", repr(INSTALLER))
    print("installer exists=", os.path.exists(INSTALLER))
    print("installer lexists=", os.path.lexists(INSTALLER))
    print("installer is link=", os.path.islink(INSTALLER))
    try:
        print("installer readlink=", os.readlink(INSTALLER))
    except Exception as e:
        print("installer readlink failed=",e)

    if not os.path.exists(INSTALLER):
        dir = os.path.dirname(INSTALLER)

        raise SystemExit(f"installer '{INSTALLER}' does not exist. Files in dir: '{os.listdir(dir)}'")

    content = ""
    try:
        with open(RUNFILES.Rlocation(sys.argv[2]), "r", encoding="utf-8") as f:
            content = f.read()
            CONFIG = json.loads(content)
    except json.JSONDecodeError as e:
        raise SystemExit(f"Invalid config JSON: {e}\nFile: {sys.argv[2]}\nContent: {content}")
    except:
        raise SystemExit(f"error parsing json parameter: {sys.argv[2]}\nContent: {content}")

    logging.basicConfig(stream=sys.stderr)
    logging.getLogger("NsisInstallerTest.test_installer").setLevel(logging.DEBUG)
    unittest.main(argv=[sys.argv[0]])
