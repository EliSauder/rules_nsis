import hashlib
import os
import pathlib
import subprocess
import sys

from python.runfiles import Runfiles


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Expected argv: <NSIS API test binary>")

    runfiles = Runfiles.Create()
    if runfiles is None:
        raise SystemExit("runfiles is none")

    binary = runfiles.Rlocation(sys.argv[1])
    test_tmpdir = pathlib.Path(os.environ["TEST_TMPDIR"])
    install_dir = test_tmpdir / "install"
    test_id = hashlib.sha256(str(test_tmpdir).encode("utf-8")).hexdigest()
    install_dir.mkdir(parents=True, exist_ok=True)

    install = subprocess.run(
        [binary, "/S", f"/TESTID={test_id}", f"/D={install_dir}"],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if install.returncode != 0:
        raise SystemExit(
            f"NSIS API install test failed with {install.returncode}\n"
            f"stdout:\n{install.stdout}\nstderr:\n{install.stderr}"
        )

    uninstaller = install_dir / "Uninstall.exe"
    if not uninstaller.is_file():
        raise SystemExit(f"NSIS API test did not produce {uninstaller}")

    uninstall = subprocess.run(
        [str(uninstaller), "/S", f"/TESTID={test_id}", f"_?={install_dir}"],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if uninstall.returncode != 0:
        raise SystemExit(
            f"NSIS API uninstall test failed with {uninstall.returncode}\n"
            f"stdout:\n{uninstall.stdout}\nstderr:\n{uninstall.stderr}"
        )

if __name__ == "__main__":
    main()
