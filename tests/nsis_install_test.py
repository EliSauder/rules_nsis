import os
import pathlib
import shutil
import subprocess
import sys
import unittest

class InstallerTest(unittest.TestCase):
    def test_install_files_into_dir(self) -> None:
        if len(sys.argv) < 3:
            self.fail("Expected argv: <installer_path> <config_json>")

        installer = pathlib.Path(sys.argv[1]).resolve()
        config = json.loads(sys.argv[2])
        self.assertTrue(installer.exists(), f"Installer does not exist: {installer}")

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

if __name__ = "__main__":
    unittest.main()
