import os
import sys
import unittest
import uuid

from python.runfiles import Runfiles

from nsis.testing import Harness


def main():
    name, binary, description = sys.argv[1:]
    runfiles = Runfiles.Create()
    with Harness(
        runfiles.Rlocation(binary), runfiles.Rlocation(description),
        directory=os.environ["TEST_TMPDIR"],
    ) as harness:
        if name in ("corruption", "uninstaller_corruption"):
            with unittest.TestCase().assertRaisesRegex(
                AssertionError, r"(?s)NSIS registers changed:.*\$0:.*\$R9:"
            ):
                harness.run()
        elif name == "typed":
            for number, enabled in [(-2147483648, False), (-1, True), (2147483646, False)]:
                harness.run(number=number, enabled=enabled).assert_outputs(
                    number=number + 1, enabled=not enabled
                )
        elif name == "definition":
            harness.run().assert_outputs(result="42")
        elif name == "file":
            path = harness.directory / "a file.txt"
            harness.run(path=str(path)).assert_outputs(result=str(path))
            assert path.read_text() == "hello"
        elif name == "logging":
            result = harness.run(text="hello")
            assert result.stdout == "hello", result.stdout
            assert result.stderr == "hello", result.stderr
        elif name == "inout":
            harness.run(value="hello").assert_outputs(value="hello-appended")
        elif name == "registry":
            import winreg

            key = str(uuid.uuid4())
            path = "Software\\RulesNsisFrameworkTests\\" + key
            try:
                harness.run(key=key, value="hello registry").assert_outputs(result=key)
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, path) as handle:
                    assert winreg.QueryValueEx(handle, "Value") == ("hello registry", winreg.REG_SZ)
            finally:
                try:
                    winreg.DeleteKey(winreg.HKEY_CURRENT_USER, path)
                except FileNotFoundError:
                    pass
        else:
            for value in ["", "hello world", "Unicode: \u03bb", "dollars $ and ; = %", "  whitespace  "]:
                harness.run(text=value).assert_outputs(result=value)


if __name__ == "__main__":
    main()
