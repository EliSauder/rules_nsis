import os
import psutil
import json
import pathlib
import shutil
import subprocess
import sys
import unittest
import winreg
import logging

from python.runfiles import runfiles

def _print_directory_tree(indir: str) -> str:
    out = ""
    for dir, dirs, files in os.walk(indir):
        for d in dirs:
            pt = os.path.relpath(d, dir)
            lvl = pt.count(os.sep)
            idnt = ' ' * 4 * (lvl)
            out = out + "{}{}/\n".format(idnt, os.path.basename(pt))
            subindent = ' ' * 4 * (lvl + 1)
            for f in files:
                out = out + '{}{}\n'.format(subindent, f)

    return out

print("cwd=", os.getcwd())
print("dircontent=", _print_directory_tree(os.getcwd()))

RUNFILES = runfiles.Create()
if RUNFILES == None:
    raise SystemExit("runfiles is none")

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

def _get_reg_path(subpath) -> str:
    return f"Software\\{subpath}", f"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{subpath}"

def _get_reg_db(execution_level: str) -> int:
    if execution_level == "admin":
        return winreg.HKEY_LOCAL_MACHINE
    if execution_level == "user":
        return winreg.HKEY_CURRENT_USER

    raise SystemError(f"unsupported execution_level {execution_level}")

def _get_reg_view(bitwidth: str) -> int:
    if bitwidth == "32":
        return winreg.KEY_WOW64_32KEY
    if bitwidth == "64":
        return winreg.KEY_WOW64_64KEY

    raise SystemError(f"unsupported bitwidth {bitwidth}")

def _get_reg_access(bitwidth: str) -> int:
    access = winreg.KEY_READ
    access |= _get_reg_view(bitwidth)
    return access

def _reg_open(root_db: int, path: str, view: int):
    try:
        return winreg.OpenKey(root_db, path, 0, view)
    except:
        raise SystemError(f"error opening key {path}")

def _reg_value(root: int, path: str, view: int, name: str):
    with _reg_open(root, path, view) as hkey:
        value, value_type = winreg.QueryValueEx(hkey, name)
        return value, value_type

def _validate_removed_reg(testcase: unittest.TestCase, config: dict, inst_root: str, inst_subpath: str):
    exlvl = (config["expected_execution_level"] or "admin")
    root = _get_reg_db(exlvl)

    instdir = f"{inst_root}"

    inpath, unpath = _get_reg_path(inst_subpath)
    access = _get_reg_access(config["expected_bitwidth"] or "64")

    try:
        key = _reg_open(root, inpath, access)
        try:
            key.Close()
        except:
            pass
        testcase.fail(f"Registry key {inpath} still exists")
    except:
        pass
    try:
        key = _reg_open(root, unpath, access)
        try:
            key.Close()
        except:
            pass
        testcase.fail(f"Registry key {inpath} still exists")
    except:
        pass

def _validate_reg(testcase: unittest.TestCase, config: dict, inst_root: str, inst_subpath: str):
    exlvl = (config["expected_execution_level"] or "admin")
    root = _get_reg_db(exlvl)

    instdir = f"{inst_root}"

    inpath, unpath = _get_reg_path(inst_subpath)
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
    _reg_value(root, unpath, access, "DisplayIcon")

    testcase.assertEqual(instdir, instdirval, f"expected InstallDir to equal install path")
    testcase.assertEqual(f"{instdir}\\Uninstall.exe", unstr, f"expected UninstallString to equal install path + Uninstall.exe")
    testcase.assertEqual(versionval, unversionval, f"expected install version {versionval} to equal uninstall version {unversionval}")


def _get_install_root():
    test_tmpdir = os.path.abspath(str(os.environ["TEST_TMPDIR"]))
    install_root = f"{test_tmpdir}\\nsis-install-root"

    pth = pathlib.Path(install_root).resolve()

    if pth.exists():
        shutil.rmtree(pth)
    pth.mkdir(parents=True, exist_ok=True)

    return install_root

def _get_install_subpath(config):
    subpath = _get_sub_path(
        config["expected_product_path"] or None,
        config["expected_vendor_path"] or None,
        config["expected_install_path"] or None,
    )
    return subpath

def _get_uninstaller_cmd(install_root):
    cmd = [
        os.path.join(install_root, "Uninstall.exe"),
        "/S"
    ]
    return cmd

def _get_installer_cmd(installer, install_root, config):
    installer_args = list(config.get("installer_args", []))
    cmd = [
        str(installer),
        "/S",
    ] + installer_args + [
        f"/D={install_root}"
    ]
    return cmd

def _validate_removed_files(testcase: unittest.TestCase, config, install_root):
    expected_files = config.get("expected_files", [])
    expected_files.append("Uninstall.exe")
    dircontent = _print_directory_tree(install_root)

    for path in expected_files:
        if not os.path.isabs(path):
            path = os.path.join(install_root, path)

        testcase.assertFalse(os.path.exists(path), f"File: '{path}' exists after uninstall. Install Root Content: {dircontent}")


def _validate_files(testcase: unittest.TestCase, config, install_root):
    expected_files = config.get("expected_files", [])
    expected_files.append("Uninstall.exe")
    for path in expected_files:
        if not os.path.isabs(path):
            path = os.path.join(install_root, path)

        dir = pathlib.Path(install_root).resolve()
        fs = [x.as_uri() for x in dir.iterdir() if x.is_file()]

        testcase.assertTrue(os.path.exists(path), f"Expected file missing: {path}. Found: {fs}")

def _validate_removed_services(testcase, config, install_root):
    expected_services = config.get("expected_services", {})

    for key, val in expected_services.items():
        try:
            svc = psutil.win_service_get(key)
            testcase.fail(f"Windows service {key}, still exists")
        except:
            continue


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

        testcase.assertEqual(val["description"], svc.description(), f"Description '{svc.description()}' not equal expected '{val['description']}'")

def _validate_install(testcase, install_root, install_subpath, config, installer):
        installer_cmd = _get_installer_cmd(installer, install_root, config)

        proc = subprocess.run(
            installer_cmd,
            capture_output=True,
            text=True,
            timeout=120,
            check=False
        )

        testcase.assertEqual(0, proc.returncode, f"Installer failed.\nexit_code: {proc.returncode}\ncmd: {installer_cmd}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}\n")

        log = logging.getLogger("NsisInstallerTest.test_installer")
        log.debug("nsis stdout=%r", proc.stdout)
        log.debug("nsis stderr=%r", proc.stderr)

        with testcase.subTest(msg="Validate Installed Files"):
            _validate_files(testcase, config, install_root)
        with testcase.subTest(msg="Validate Installed Registry Keys"):
            _validate_reg(testcase, config, install_root, install_subpath)
        with testcase.subTest(msg="Validate Installed Services"):
            _validate_services(testcase, config, install_root)

def _validate_uninstall(testcase, install_root, install_subpath, config):
        uninstaller_cmd = _get_uninstaller_cmd(install_root)

        proc = subprocess.run(
            uninstaller_cmd,
            capture_output=True,
            text=True,
            timeout=120,
            check=False
        )

        testcase.assertEqual(0, proc.returncode, f"Uninstaller failed.\nexit_code: {proc.returncode}\ncmd: {uninstaller_cmd}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}\n")

        log = logging.getLogger("NsisInstallerTest.test_installer")
        log.debug("nsis uninstall stdout=%r", proc.stdout)
        log.debug("nsis uninstall stderr=%r", proc.stderr)

        with testcase.subTest(msg="Validate Removed Files"):
            _validate_removed_files(testcase, config, install_root)
        with testcase.subTest(msg="Validate Removed Registry Keys"):
            _validate_removed_reg(testcase, config, install_root, install_subpath)
        with testcase.subTest(msg="Validate Removed Services"):
            _validate_removed_services(testcase, config, install_root)


class NsisInstallerTest(unittest.TestCase):
    def test_installer(self) -> None:

        installer = INSTALLER
        config = CONFIG

        exp_inst_name = config.get("expected_installer_name", "")
        bn = os.path.basename(installer)
        with self.subTest(msg="Validate Installer Name"):
            self.assertEqual(exp_inst_name, bn,
                f"Installer {bn} does not match expected name {exp_inst_name}",
            )

        install_root = _get_install_root()
        install_subpath = _get_install_subpath(config)

        _validate_install(self, install_root, install_subpath, config, installer)
        _validate_uninstall(self, install_root, install_subpath, config)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemError("Expected argv: <installer_path> <config_json>")

    #INSTALLER = sys.argv[1]
    INSTALLER = RUNFILES.Rlocation(sys.argv[1])
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
