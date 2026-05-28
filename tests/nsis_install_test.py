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

def _get_installer_cmd(installer, install_root, config):
    installer_args = list(config.get("installer_args", []))
    cmd = [
        str(installer),
        "/S",
    ] + installer_args + [
        f"/D={install_root}"
    ]
    return cmd

def _validate_files(testcase, config, install_root):
    expected_files = config.get("expected_files", [])
    expected_files.append("Uninstall.exe")
    for path in expected_files:
        if not os.path.isabs(path):
            path = os.path.join(install_root, path)

        dir = pathlib.Path(install_root).resolve()
        fs = [x.as_uri() for x in dir.iterdir() if x.is_file()]

        testcase.assertTrue(os.path.exists(path), f"Expected file missing: {path}. Found: {fs}")

def _validate_services(testcase, config, install_root):
    expected_services = config.get("expected_services", {})

    for key, val in expected_services.items():
        svc = psutil.win_service.get(key)

        testcase.assertEqual(key, svc.name(), f"Unexpected name {svc.name()}, expected {key}. WTF How did this happen?")

        testcase.assertEqual(val["display_name"], svc.display_name(), f"Display name {svc.display_name()} does not equal expected {val["display_name"]}")

        exe = os.path.join(install_root, val["executable"])
        for arg in list(val["args"]):
            exe = exe + " " + arg
        testcase.assertEqual(exe, svc.binpath(), f"Executable {svc.binpath()} not equal expected {exe}")

        testcase.assertEqual(val["start_type"], svc.start_type(), f"Start type {svc.start_type()} not equal expected {val["start_type"]}")

        testcase.assertEqual(val["description"], svc.description(), f"Description {svc.description()} not equal expected {val["description"]}")


class NsisInstallerTest(unittest.TestCase):
    def test_installer(self) -> None:

        installer = INSTALLER
        config = CONFIG

        exp_inst_name = config.get("expected_installer_name", "")
        self.assertTrue(
            os.path.basename(installer) == exp_inst_name,
            f"Installer {installer} does not match expected name {exp_inst_name}",
        )

        install_root = _get_install_root()
        install_subpath = _get_install_subpath(config)
        installer_cmd = _get_installer_cmd(installer, install_root, config)

        proc = subprocess.run(
            installer_cmd,
            capture_output=True,
            text=True,
            timeout=120,
            check=False
        )

        self.assertEqual(0, proc.returncode, f"Installer failed.\nexit_code: {proc.returncode}\ncmd: {installer_cmd}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}\n")

        log = logging.getLogger("NsisInstallerTest.test_installer")
        log.debug("nsis stdout=%r", proc.stdout)
        log.debug("nsis stderr=%r", proc.stderr)

        _validate_files(self, config, install_root)
        _validate_reg(self, config, install_root, install_subpath)
        _validate_services(self, config, install_root)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemError("Expected argv: <installer_path> <config_json>")

    INSTALLER = sys.argv[1]
    if not os.path.exists(INSTALLER):
        raise SystemExit(f"installer '{INSTALLER}' does not exist")

    try:
        with open(sys.argv[2], "r", encoding="utf-8") as f:
            content = f.readall()
            CONFIG = json.loads(content)
    except json.JSONDecodeError as e:
        raise SystemExit(f"Invalid config JSON: {e}\nFile: {sys.argv[2]}\nContent: {content}")
    except:
        raise SystemExit(f"error parsing json parameter: {sys.argv[2]}\nContent: {content}")

    logging.basicConfig(stream=sys.stderr)
    logging.getLogger("NsisInstallerTest.test_installer").setLevel(logging.DEBUG)
    unittest.main(argv=[sys.argv[0]])
