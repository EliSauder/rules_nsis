import os
import json
import pathlib
import shutil
import subprocess
import sys
import unittest

INSTALLER=None
CONFIG=None

class NsisInstallerTest(unittest.TestCase):

    def test_installer(self) -> None:

        installer = INSTALLER
        config = CONFIG

        exp_inst_name = config.get("expected_installer_name", "")
        self.assertTrue(
            os.path.basename(installer) == exp_inst_name,
            f"Installer {installer} does not match expected name {exp_inst_name}",
        )

        test_tmpdir = pathlib.Path(os.environ["TEST_TMPDIR"]).resolve()
        install_root = test_tmpdir / "nsis-install-root"

        if install_root.exists():
            shutil.rmtree(install_root)
        install_root.mkdir(parents=True, exist_ok=True)

        installer_args = list(config.get("installer_args", []))
        cmd = [
            str(installer),
            "/S",
            f"/D={install_root}"
        ] + installer_args

        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            check=False
        )

        if proc.returncode != 0:
            self.fail(
                "Installer failed.\n"
                f"exit_code: {proc.returncode}\n"
                f"cmd: {cmd}\n"
                f"stdout:\n{proc.stdout}\n"
                f"stderr:\n{proc.stderr}\n"
            )

        expected_files = config.get("expected_files", [])
        for path in expected_files:
            if not os.path.isabs(path):
                path = os.path.join(install_root, path)

            self.assertTrue(os.path.exists(path), f"Expected file missing: {path}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemError("Expected argv: <installer_path> <config_json>")

    INSTALLER = sys.argv[1]
    path = pathlib.Path(INSTALLER).resolve()
    if not path.exists():
        raise SystemExit("installer does not exist")

    try:
        CONFIG = json.loads(sys.argv[2])
    except json.JSONDecodeError as e:
        raise SystemExit(f"Invalid config JSON: {e}\nValue: {sys.argv[2]}")
    except:
        raise SystemExit(f"error parsing json parameter: {sys.argv[2]}")

    unittest.main(argv=[sys.argv[0]])
