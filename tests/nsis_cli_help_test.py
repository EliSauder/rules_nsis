"""Runtime tests of /HELP, /FORMAT and /HELP-OUT (Windows only).

argv: <testable installer> <installer that is not testable>
"""

import os
import subprocess
import sys
import unittest

from python.runfiles import Runfiles

RUNFILES = Runfiles.Create()
if RUNFILES is None:
    raise SystemExit("could not create runfiles")

ENV = os.environ.copy()
ENV.update(RUNFILES.EnvVars())

TESTABLE = None
PLAIN = None
TMP = os.path.abspath(os.environ["TEST_TMPDIR"])


def _run(installer, *args):
    return subprocess.run(
        [installer, "/S", *args],
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
        env=ENV,
    )


def _read_utf16(path):
    with open(path, "rb") as f:
        return f.read().decode("utf-16").replace("\r\n", "\n")


class CliHelpTest(unittest.TestCase):
    def test_text_help_goes_to_stdout_without_installing(self):
        target = os.path.join(TMP, "never_installed")
        proc = _run(TESTABLE, "/HELP", "/O:advanced_settings.token=hunter2", f"/D={target}")
        self.assertEqual(0, proc.returncode, proc.stderr)
        out = proc.stdout
        for expected in (
            "Usage:",
            "/COMPONENTS=",
            "/TESTID=",
            "Options:",
            "install_settings.enable_extras",
            "Components:",
            "cli_docs",
            "Install types:",
            "<secret>",
        ):
            self.assertIn(expected, out)
        self.assertNotIn("hunter2", out)
        self.assertFalse(os.path.exists(target), "/HELP must not install")

    def test_topic_filters_sections(self):
        proc = _run(TESTABLE, "/HELP=components")
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertIn("Components:", proc.stdout)
        self.assertNotIn("Usage:", proc.stdout)
        self.assertNotIn("Options:", proc.stdout)

    def test_help_reflects_components_argument(self):
        proc = _run(TESTABLE, "/HELP=components", "/COMPONENTS=cli_docs")
        self.assertEqual(0, proc.returncode, proc.stderr)
        lines = {line.split()[0]: line for line in proc.stdout.splitlines() if line.startswith("  cli_")}
        self.assertIn("selected=yes", lines["cli_docs"])
        self.assertIn("selected=yes", lines["cli_tools"])
        self.assertIn("selected=no", lines["cli_samples"])

    def test_testid_listed_only_for_testable_installers(self):
        proc = _run(PLAIN, "/HELP=usage")
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertIn("/COMPONENTS=", proc.stdout)
        self.assertNotIn("/TESTID", proc.stdout)

    def test_invalid_topic_and_format_exit_with_2(self):
        self.assertEqual(2, _run(TESTABLE, "/HELP=bogus").returncode)
        self.assertEqual(2, _run(TESTABLE, "/HELP", "/FORMAT=bogus").returncode)

    def test_help_out_writes_the_file(self):
        out = os.path.join(TMP, "help.txt")
        proc = _run(TESTABLE, "/HELP", f"/HELP-OUT={out}")
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertEqual("", proc.stdout)
        self.assertIn("Usage:", _read_utf16(out))

    def test_ini_round_trips_through_options(self):
        first = os.path.join(TMP, "answers1.ini")
        second = os.path.join(TMP, "answers2.ini")
        proc = _run(
            TESTABLE,
            "/HELP",
            "/FORMAT=ini",
            f"/HELP-OUT={first}",
            "/O:install_settings.port=9090",
            "/O:advanced_settings.token=hunter2",
            "/COMPONENTS=cli_samples",
        )
        self.assertEqual(0, proc.returncode, proc.stderr)
        content = _read_utf16(first)
        self.assertIn("[setup]", content)
        self.assertIn("port=9090", content)
        self.assertNotIn("hunter2", content)
        self.assertIn("components=cli_core,cli_samples", content)

        proc = _run(TESTABLE, "/HELP", "/FORMAT=ini", f"/OPTIONS={first}", f"/HELP-OUT={second}")
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertEqual(content, _read_utf16(second))


if __name__ == "__main__":
    TESTABLE = RUNFILES.Rlocation(sys.argv.pop(1))
    PLAIN = RUNFILES.Rlocation(sys.argv.pop(1))
    unittest.main()
