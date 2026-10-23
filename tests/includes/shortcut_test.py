import os
import subprocess

from tests.includes import common

_SCRIPT = (
    "$s = (New-Object -ComObject WScript.Shell).CreateShortcut($env:LNK);"
    "if ($env:TARGET) { $s.TargetPath = $env:TARGET; $s.Save() }"
    "else { $s.TargetPath; $s.Arguments; $s.WorkingDirectory; $s.Description }"
)


def _shell_link(link, target=None):
    """Writes a link to target, or reads the link's fields when target is None."""
    env = dict(os.environ, LNK=str(link), TARGET=str(target or ""))
    result = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", _SCRIPT],
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.splitlines()


def _target(directory):
    target = directory / "app" / "tool.exe"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(b"")
    return target


def _create(harness, directory):
    target = _target(directory)
    link = directory / "menu" / "sub" / "Tool.lnk"
    harness.run(
        link=str(link),
        target=str(target),
        arguments="/flag value",
        icon=str(target),
        description="A tool",
    )
    path, arguments, working, description = _shell_link(link)
    assert path.lower() == str(target).lower()
    assert arguments == "/flag value"
    assert working.lower() == str(target.parent).lower()
    assert description == "A tool"


def _get_target(harness, directory):
    harness.run(link=str(directory / "missing.lnk"), expect_errors=True).assert_outputs(target="")
    garbage = directory / "garbage.lnk"
    garbage.write_text("not a link", encoding="utf-8")
    harness.run(link=str(garbage), expect_errors=True).assert_outputs(target="")
    target = _target(directory)
    link = directory / "Tool.lnk"
    _shell_link(link, target)
    result = harness.run(link=str(link), expect_errors=False)
    assert result.outputs["target"].lower() == str(target).lower()


def _remove_if_owned(harness, directory):
    harness.run(link=str(directory / "missing.lnk"), prefix=str(directory), expect_errors=False)
    install = directory / "install"
    owned = _target(install)
    foreign = _target(directory / "other")
    owned_link = directory / "owned.lnk"
    foreign_link = directory / "foreign.lnk"
    sibling_link = directory / "sibling.lnk"
    _shell_link(owned_link, owned)
    _shell_link(foreign_link, foreign)
    # Shares the prefix text but is not inside the folder.
    sibling = _target(directory / "install2")
    _shell_link(sibling_link, sibling)

    harness.run(link=str(owned_link), prefix=str(install), expect_errors=False)
    assert not owned_link.exists()
    harness.run(link=str(foreign_link), prefix=str(install), expect_errors=True)
    assert foreign_link.exists()
    harness.run(link=str(sibling_link), prefix=str(install), expect_errors=True)
    assert sibling_link.exists()

    # The prefix match ignores case and a trailing separator.
    _shell_link(owned_link, owned)
    harness.run(link=str(owned_link), prefix=str(install).upper() + "\\", expect_errors=False)
    assert not owned_link.exists()


def _remove_empty_dirs(harness, directory):
    stop = directory / "programs"
    leaf = stop / "Vendor" / "Product"
    leaf.mkdir(parents=True)
    harness.run(directory=str(leaf), stop_at=str(stop))
    assert stop.is_dir()
    assert not (stop / "Vendor").exists()

    # A folder holding anything stays, and so does everything above it.
    leaf.mkdir(parents=True)
    (stop / "Vendor" / "other.txt").write_text("x", encoding="utf-8")
    harness.run(directory=str(leaf), stop_at=str(stop) + "\\")
    assert not leaf.exists()
    assert (stop / "Vendor" / "other.txt").exists()

    # Removal is not recursive.
    (leaf / "child").mkdir(parents=True)
    harness.run(directory=str(leaf), stop_at=str(stop))
    assert (leaf / "child").is_dir()

    # Folders outside stop_at are never touched.
    outside = directory / "outside" / "empty"
    outside.mkdir(parents=True)
    harness.run(directory=str(outside), stop_at=str(stop))
    assert outside.is_dir()


def run_case(case, harness, args):
    handlers = {
        "shortcut_create": _create,
        "shortcut_get_target": _get_target,
        "shortcut_remove_if_owned": _remove_if_owned,
        "shortcut_remove_empty_dirs": _remove_empty_dirs,
    }
    handler = handlers.get(common.base(case))
    if handler is None:
        raise common.unhandled(case)
    handler(harness, harness.directory)


if __name__ == "__main__":
    common.main(run_case)
