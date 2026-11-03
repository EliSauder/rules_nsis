import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path

from python.runfiles import runfiles


INSTALLER = Path(runfiles.Create().Rlocation(sys.argv.pop(1))).resolve()


def execute(command):
    return subprocess.run(command, capture_output=True, text=True, timeout=120)


class TreeArtifactInstallerTest(unittest.TestCase):
    def test_flat_layout_and_uninstall(self):
        for preserve_user_files in (False, True):
            with self.subTest(preserve_user_files=preserve_user_files):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    installed = root / "installed"
                    test_id = str(uuid.uuid4())
                    result = execute([
                        str(INSTALLER), "/S", f"/TESTID={test_id}",
                        f"/D={installed}",
                    ])
                    self.assertEqual(result.returncode, 0, result.stderr)

                    files = {"README.md", "nested/file with spaces.txt", "${LITERAL}.txt"}
                    directories = {"nested"}
                    expected = files | directories | {"component", "Uninstall.exe"}
                    expected |= {"component/" + path for path in files | directories}
                    self.assertEqual(
                        {path.relative_to(installed).as_posix()
                         for path in installed.rglob("*")},
                        expected,
                    )

                    for directory in (installed, installed / "component"):
                        os.chmod(directory / "README.md", 0o444)
                        if preserve_user_files:
                            (directory / "user.txt").write_text("keep")
                            (directory / "nested" / "user.txt").write_text("keep")

                    uninstaller = root / "uninstall.exe"
                    shutil.copyfile(installed / "Uninstall.exe", uninstaller)
                    result = execute([
                        str(uninstaller), "/S", f"/TESTID={test_id}",
                        f"_?={installed}",
                    ])
                    self.assertEqual(result.returncode, 0, result.stderr)

                    if preserve_user_files:
                        remaining = {
                            "user.txt", "nested", "nested/user.txt", "component",
                            "component/user.txt", "component/nested",
                            "component/nested/user.txt",
                        }
                        self.assertEqual(
                            {path.relative_to(installed).as_posix()
                             for path in installed.rglob("*")},
                            remaining,
                        )
                        for path in installed.rglob("user.txt"):
                            self.assertEqual(path.read_text(), "keep")
                    else:
                        self.assertFalse(installed.exists())


if __name__ == "__main__":
    unittest.main()
