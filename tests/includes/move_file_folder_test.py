import contextlib
import os
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from tests.includes import common

_DAY = 24 * 60 * 60


def _write(path, text, age=0):
    """Writes text to path with a modification time age seconds in the past."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    stamp = time.time() - age
    os.utime(path, (stamp, stamp))


def _existing_destination(move, overwrite):
    """Moves onto destinations older, newer, and the same age as the source.

    By default only the older destination is replaced and the source is always
    removed; with $switch_overwrite every destination is replaced.
    """
    for name, source_age, destination_age in [
        ("newer_source", 0, _DAY),
        ("older_source", _DAY, 0),
        ("same_age", 0, 0),
    ]:
        source, destination = move(name, source_age, destination_age)
        replaced = overwrite or name == "newer_source"
        assert destination.read_text(encoding="utf-8") == ("source" if replaced else "destination"), name
        assert not source.exists(), name


def _move_file(harness, directory, overwrite):
    source = directory / "source.txt"
    destination = directory / "destination.txt"
    _write(source, "move test")
    harness.run(source=str(source), destination=str(destination), expect_errors=False)
    assert destination.read_text(encoding="utf-8") == "move test"
    assert not source.exists()
    harness.run(source=str(directory / "missing.txt"), destination=str(directory / "never.txt"), expect_errors=True)
    assert not (directory / "never.txt").exists()

    def move(name, source_age, destination_age):
        source = directory / (name + ".src")
        destination = directory / (name + ".dst")
        _write(source, "source", source_age)
        _write(destination, "destination", destination_age)
        if source_age == destination_age:
            stamp = source.stat().st_mtime_ns
            os.utime(destination, ns=(stamp, stamp))
        harness.run(source=str(source), destination=str(destination), expect_errors=False)
        return source, destination

    _existing_destination(move, overwrite)

    # A failed overwrite must preserve both versions, rather than deleting
    # the source after Rename fails.
    source = directory / "blocked.src"
    destination = directory / "blocked.dst"
    _write(source, "source")
    _write(destination, "destination", _DAY)
    os.chmod(destination, stat.S_IREAD)
    try:
        harness.run(source=str(source), destination=str(destination), expect_errors=True)
        assert source.read_text(encoding="utf-8") == "source"
        assert destination.read_text(encoding="utf-8") == "destination"
    finally:
        os.chmod(destination, stat.S_IREAD | stat.S_IWRITE)

    harness.run(source=str(source), destination=str(source.parent) + "\\.\\" + source.name, expect_errors=False)
    assert source.read_text(encoding="utf-8") == "source"
    destination = directory / "directory_destination"
    destination.mkdir()
    harness.run(source=str(source), destination=str(destination), expect_errors=True)
    assert source.read_text(encoding="utf-8") == "source" and destination.is_dir()

    # Keep the timestamp high words equal while crossing the low word's sign bit.
    ticks = int((time.time() + 11644473600) * 10_000_000) & ~0xFFFFFFFF
    earlier = (ticks + 0x7F000000) / 10_000_000 - 11644473600
    later = (ticks + 0x81000000) / 10_000_000 - 11644473600
    source = directory / "timestamp.src"
    destination = directory / "timestamp.dst"
    _write(source, "newer")
    _write(destination, "older")
    os.utime(source, (later, later))
    os.utime(destination, (earlier, earlier))
    harness.run(source=str(source), destination=str(destination), expect_errors=False)
    assert destination.read_text(encoding="utf-8") == "newer"
    assert not source.exists()
    _write(source, "older")
    _write(destination, "newer")
    os.utime(source, (earlier, earlier))
    os.utime(destination, (later, later))
    harness.run(source=str(source), destination=str(destination), expect_errors=False)
    assert destination.read_text(encoding="utf-8") == ("older" if overwrite else "newer")
    assert not source.exists()


def _move_folder(harness, directory, overwrite):
    source = directory / "source"
    destination = directory / "destination"
    _write(source / "child" / "source.txt", "move folder test")
    harness.run(source=str(source), destination=str(destination), mask="*.txt", expect_errors=False)
    assert (destination / "child" / "source.txt").read_text(encoding="utf-8") == "move folder test"
    assert not source.exists()

    # Files outside the mask stay behind, keeping the source folder.
    _write(source / "child" / "moved.txt", "moved")
    _write(source / "child" / "kept.log", "kept")
    harness.run(source=str(source), destination=str(destination), mask="*.txt", expect_errors=False)
    assert (destination / "child" / "moved.txt").read_text(encoding="utf-8") == "moved"
    assert (source / "child" / "kept.log").read_text(encoding="utf-8") == "kept"
    assert not (destination / "child" / "kept.log").exists()
    assert not (source / "child" / "moved.txt").exists()

    def move(name, source_age, destination_age):
        source = directory / (name + "_source")
        destination = directory / (name + "_destination")
        _write(source / "file.txt", "source", source_age)
        _write(destination / "file.txt", "destination", destination_age)
        if source_age == destination_age:
            stamp = (source / "file.txt").stat().st_mtime_ns
            os.utime(destination / "file.txt", ns=(stamp, stamp))
        harness.run(source=str(source), destination=str(destination), mask="*.*", expect_errors=False)
        return source / "file.txt", destination / "file.txt"

    _existing_destination(move, overwrite)

    source = directory / "failed_source"
    destination = directory / "failed_destination"
    _write(source / "child" / "file.txt", "source")
    _write(source / "first.txt", "moved before failure")
    _write(source / "child" / "deeper" / "unprocessed.txt", "not reached")
    _write(destination / "child" / "file.txt", "destination", _DAY)
    (source / "empty").mkdir()
    (destination / "existing_empty").mkdir()
    blocked = destination / "child" / "file.txt"
    os.chmod(blocked, stat.S_IREAD)
    try:
        harness.run(source=str(source), destination=str(destination), mask="*.txt", expect_errors=True)
        assert (source / "child" / "file.txt").read_text(encoding="utf-8") == "source"
        assert blocked.read_text(encoding="utf-8") == "destination"
        assert (source / "empty").is_dir()
        assert (destination / "existing_empty").is_dir()
        assert (destination / "first.txt").read_text(encoding="utf-8") == "moved before failure"
        assert not (source / "first.txt").exists()
        assert (source / "child" / "deeper" / "unprocessed.txt").read_text(encoding="utf-8") == "not reached"
        assert not (destination / "child" / "deeper" / "unprocessed.txt").exists()
    finally:
        os.chmod(blocked, stat.S_IREAD | stat.S_IWRITE)

    source = directory / "create_failed_source"
    destination = directory / "create_failed_destination"
    _write(source / "child" / "file.txt", "source")
    _write(destination / "child", "existing file")
    harness.run(source=str(source), destination=str(destination), mask="*.txt", expect_errors=True)
    assert (source / "child" / "file.txt").read_text(encoding="utf-8") == "source"
    assert (destination / "child").read_text(encoding="utf-8") == "existing file"

    harness.run(source=str(source), destination=str(source), mask="*.txt", expect_errors=False)
    assert (source / "child" / "file.txt").read_text(encoding="utf-8") == "source"
    nested = source / "nested_destination"
    harness.run(source=str(source), destination=str(nested), mask="*.txt", expect_errors=True)
    assert not nested.exists()
    missing_destination = directory / "missing_destination"
    harness.run(source=str(directory / "missing"), destination=str(missing_destination), mask="*", expect_errors=True)
    assert not missing_destination.exists()


def _move_file_paths(harness, directory):
    for index, name in enumerate(("file with spaces.txt", "\u65e5\u672c\u8a9e.txt", "$literal&[1].bin", ".hidden", "no_extension")):
        source = directory / name
        destination = directory / ("moved " + name)
        payload = b"" if index == 0 else bytes(range(256)) * 4
        source.write_bytes(payload)
        harness.run(source=name, destination=destination.name, expect_errors=False)
        assert destination.read_bytes() == payload, name
        assert not source.exists(), name

    source = directory / "relative.bin"
    destination = directory / "relative_moved.bin"
    source.write_bytes(b"relative")
    (directory / "child").mkdir()
    harness.run(source="child\\..\\relative.bin", destination=".\\relative_moved.bin", expect_errors=False)
    assert destination.read_bytes() == b"relative" and not source.exists()
    harness.run(source=str(destination), destination=str(destination).swapcase(), expect_errors=False)
    assert destination.read_bytes() == b"relative"

    alias = directory / "hard_link.bin"
    os.link(destination, alias)
    harness.run(source=str(destination), destination=str(alias), expect_errors=False)
    assert destination.read_bytes() == alias.read_bytes() == b"relative"

    source = directory / "read_only.bin"
    destination = directory / "read_only_moved.bin"
    source.write_bytes(b"read only")
    os.chmod(source, stat.S_IREAD)
    try:
        harness.run(source=str(source), destination=str(destination), expect_errors=False)
        assert destination.read_bytes() == b"read only" and not source.exists()
    finally:
        os.chmod(destination if destination.exists() else source, stat.S_IREAD | stat.S_IWRITE)


def _move_file_invalid(harness, directory):
    source = directory / "source.txt"
    destination = directory / "destination.txt"
    _write(source, "source")
    _write(destination, "destination", _DAY)
    (directory / "a_directory").mkdir()
    _write(directory / "a_file", "parent file")
    for invalid_source, invalid_destination in [
        ("", str(destination)),
        (str(source), ""),
        (str(directory / "missing.txt"), str(destination)),
        (str(directory / "a_directory"), str(destination)),
        (str(source), str(directory / "missing_parent" / "file.txt")),
        (str(source), str(directory / "a_file" / "file.txt")),
        (str(source), str(directory / "invalid<name>.txt")),
        (str(directory / "*.txt"), str(destination)),
        (str(directory / "*" / ".." / source.name), str(destination)),
        (str(source), str(directory / "?" / ".." / destination.name)),
    ]:
        harness.run(source=invalid_source, destination=invalid_destination, expect_errors=True)
        assert source.read_text(encoding="utf-8") == "source"
        assert destination.read_text(encoding="utf-8") == "destination"
        assert (directory / "a_directory").is_dir()
        assert (directory / "a_file").read_text(encoding="utf-8") == "parent file"
        assert not (directory / "missing_parent").exists()

    harness.run(source=str(source), destination=str(destination), expect_errors=False)
    assert destination.read_text(encoding="utf-8") == "source" and not source.exists()


def _move_file_locked(harness, directory):
    for name in ("source_new_destination", "source_existing_destination", "destination"):
        source = directory / (name + ".src")
        destination = directory / (name + ".dst")
        _write(source, "source", _DAY if name == "source_existing_destination" else 0)
        existing = name != "source_new_destination"
        if existing:
            _write(destination, "destination", 0 if name == "source_existing_destination" else _DAY)
        harness.run(
            source=str(source), destination=str(destination),
            locked=str(destination if name == "destination" else source),
            expect_errors=True,
        )
        assert source.read_text(encoding="utf-8") == "source", name
        if existing:
            assert destination.read_text(encoding="utf-8") == "destination", name
        else:
            assert not destination.exists(), name


def _move_folder_paths(harness, directory):
    source = directory / "source"
    destination = directory / "destination"
    (source / "empty" / "nested").mkdir(parents=True)
    harness.run(source=str(source), destination=str(destination), mask="*", expect_errors=False)
    assert not source.exists() and destination.is_dir()
    assert not list(destination.iterdir())

    _write(source / "nested" / "kept.log", "not selected")
    harness.run(source=str(source), destination=str(destination), mask="*.txt", expect_errors=False)
    assert (source / "nested" / "kept.log").read_text(encoding="utf-8") == "not selected"
    assert not list(destination.iterdir())

    for name in ("with spaces", "\u65e5\u672c\u8a9e", "$literal&[1]"):
        source = directory / name
        destination = directory / (name + " moved")
        _write(source / "child" / "file.txt", name)
        harness.run(
            source=source.name + "\\", destination=destination.name + "\\",
            mask="*.txt", expect_errors=False,
        )
        assert (destination / "child" / "file.txt").read_text(encoding="utf-8") == name
        assert not source.exists()

    source = directory / "case_source"
    _write(source / "keep.txt", "same folder")
    harness.run(source=str(source), destination=str(source).swapcase() + "\\.", mask="*", expect_errors=False)
    assert (source / "keep.txt").read_text(encoding="utf-8") == "same folder"


def _move_folder_invalid(harness, directory):
    source = directory / "source"
    destination = directory / "destination"
    _write(source / "keep.txt", "source")
    _write(destination / "keep.txt", "destination", _DAY)
    _write(directory / "not_a_folder", "file")
    for invalid_source, invalid_destination in [
        ("", str(destination)),
        (str(source), ""),
        (str(directory / "missing"), str(destination)),
        (str(directory / "not_a_folder"), str(destination)),
        (str(source), str(directory / "not_a_folder")),
        (str(source), str(directory / "not_a_folder" / "child")),
        (str(source), str(source / "nested")),
        (str(source), str(source) + "\\child\\..\\nested"),
        (str(source.anchor), str(destination)),
        (str(directory / "*" / ".." / source.name), str(destination)),
        (str(source), str(directory / "?" / ".." / destination.name)),
    ]:
        harness.run(source=invalid_source, destination=invalid_destination, mask="*", expect_errors=True)
        assert (source / "keep.txt").read_text(encoding="utf-8") == "source"
        assert (destination / "keep.txt").read_text(encoding="utf-8") == "destination"
        assert (directory / "not_a_folder").read_text(encoding="utf-8") == "file"
        assert not (source / "nested").exists()
        assert not (source / "child").exists()

    conflict = destination / "keep.txt"
    conflict.unlink()
    conflict.mkdir()
    _write(conflict / "child.txt", "existing directory")
    harness.run(source=str(source), destination=str(destination), mask="*.txt", expect_errors=True)
    assert (source / "keep.txt").read_text(encoding="utf-8") == "source"
    assert (conflict / "child.txt").read_text(encoding="utf-8") == "existing directory"


def _move_folder_merge(harness, directory):
    source = directory / "source"
    destination = directory / "source_sibling"
    _write(source / "root.TXT", "root")
    _write(source / "child" / "nested" / "leaf.txt", "leaf")
    _write(source / "child" / "kept.log", "keep")
    _write(destination / "child" / "destination_only.txt", "existing")
    harness.run(source=str(source), destination=str(destination), mask="*.txt", expect_errors=False)
    assert (destination / "root.TXT").read_text(encoding="utf-8") == "root"
    assert (destination / "child" / "nested" / "leaf.txt").read_text(encoding="utf-8") == "leaf"
    assert (destination / "child" / "destination_only.txt").read_text(encoding="utf-8") == "existing"
    assert (source / "child" / "kept.log").read_text(encoding="utf-8") == "keep"
    assert not (source / "root.TXT").exists()
    assert not (source / "child" / "nested").exists()

    _write(source / "child" / "no_extension", "")
    harness.run(source=str(source), destination=str(destination), mask="*", expect_errors=False)
    assert not source.exists()
    assert (destination / "child" / "no_extension").read_bytes() == b""
    assert (destination / "child" / "kept.log").read_text(encoding="utf-8") == "keep"

    # Moving into an ancestor must not treat successful source cleanup as an error.
    source = directory / "ancestor" / "child"
    destination = source.parent
    _write(source / "nested" / "file.txt", "up")
    _write(destination / "keep.log", "existing ancestor")
    harness.run(source=str(source), destination=str(destination), mask="*", expect_errors=False)
    assert (destination / "nested" / "file.txt").read_text(encoding="utf-8") == "up"
    assert (destination / "keep.log").read_text(encoding="utf-8") == "existing ancestor"
    assert not source.exists()


def _windows_kernel():
    import ctypes
    from ctypes import wintypes

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    kernel.CreateFileW.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.SetFileInformationByHandle.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
    kernel.GetShortPathNameW.argtypes = [wintypes.LPCWSTR, wintypes.LPWSTR, wintypes.DWORD]
    return kernel


def _short_path(path):
    import ctypes

    buffer = ctypes.create_unicode_buffer(32768)
    length = _windows_kernel().GetShortPathNameW(str(path), buffer, len(buffer))
    if not length:
        raise ctypes.WinError(ctypes.get_last_error())
    assert length < len(buffer)
    print(f"Short-name fixture: {path} -> {buffer.value}", flush=True)
    return Path(buffer.value)


def _junction(alias, target):
    subprocess.run(
        ["cmd.exe", "/d", "/c", "mklink", "/J", str(alias), str(target)],
        check=True, capture_output=True, text=True,
    )


def _enable_case_sensitive(path):
    import ctypes

    kernel = _windows_kernel()
    handle = kernel.CreateFileW(str(path), 0x100, 7, None, 3, 0x02000000, None)
    if handle == ctypes.c_void_p(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        flags = ctypes.c_uint32(1)
        if not kernel.SetFileInformationByHandle(handle, 23, ctypes.byref(flags), ctypes.sizeof(flags)):
            raise ctypes.WinError(ctypes.get_last_error())
    finally:
        if not kernel.CloseHandle(handle):
            raise ctypes.WinError(ctypes.get_last_error())


def _move_file_aliases(harness, directory):
    parent = directory / "Long parent directory"
    source = parent / "Long filename.txt"
    _write(source, "only copy")
    harness.run(source=str(source), destination=str(source), expect_errors=False)
    alias = directory / "junction"
    _junction(alias, parent)
    for destination in (alias / source.name, _short_path(source)):
        harness.run(source=str(source), destination=str(destination), expect_errors=False)
        assert source.read_text(encoding="utf-8") == "only copy"
        assert destination.read_text(encoding="utf-8") == "only copy"


def _move_folder_aliases(harness, directory):
    source = directory / "Long source directory"
    _write(source / "child" / "keep.txt", "only copy")
    harness.run(source=str(source), destination=str(source), mask="*", expect_errors=False)
    alias = directory / "junction"
    child_alias = directory / "child_junction"
    _junction(alias, source)
    _junction(child_alias, source / "child")
    short = _short_path(source)
    for destination in (alias, short):
        harness.run(source=str(source), destination=str(destination), mask="*", expect_errors=False)
        assert (source / "child" / "keep.txt").read_text(encoding="utf-8") == "only copy"
    for parent in (alias, child_alias, short):
        harness.run(source=str(source), destination=str(parent / "new" / "nested"), mask="*", expect_errors=True)
        assert (source / "child" / "keep.txt").read_text(encoding="utf-8") == "only copy"
        assert not (source / "new").exists()
        assert not (source / "child" / "new").exists()

    source = directory / "escaping_source"
    outside = directory / "outside"
    _write(source / "keep.txt", "source")
    _write(outside / "keep.txt", "outside")
    _junction(source / "link", outside)
    harness.run(source=str(source), destination=str(source / "link" / "out"), mask="*", expect_errors=True)
    assert not (outside / "out").exists()
    assert (source / "keep.txt").read_text(encoding="utf-8") == "source"
    assert (outside / "keep.txt").read_text(encoding="utf-8") == "outside"

    source = directory / "mapped_source"
    destination = directory / "mapped_destination"
    _write(source / "child" / "item.txt", "first")
    _write(source / "other" / "item.txt", "second", _DAY)
    destination.mkdir()
    _junction(destination / "child", source / "other")
    harness.run(source=str(source), destination=str(destination), mask="*", expect_errors=True)
    assert (source / "child" / "item.txt").read_text(encoding="utf-8") == "first"
    assert (source / "other" / "item.txt").read_text(encoding="utf-8") == "second"

    source = directory / "cyclic_source"
    _write(source / "keep.txt", "cycle")
    _junction(source / "loop", source)
    destination = directory / "cyclic_destination"
    harness.run(source=str(source), destination=str(destination), mask="*", expect_errors=True)
    assert not destination.exists()
    assert (source / "keep.txt").read_text(encoding="utf-8") == "cycle"

    source = directory / "junction_source"
    outside = directory / "external_source"
    _write(outside / "payload.txt", "external")
    source.mkdir()
    _junction(source / "link", outside)
    destination = directory / "junction_destination"
    harness.run(source=str(source), destination=str(destination), mask="*", expect_errors=False)
    assert not source.exists()
    assert outside.is_dir()
    assert (destination / "link" / "payload.txt").read_text(encoding="utf-8") == "external"


def _move_folder_enumeration(harness, directory):
    import ctypes
    from ctypes import wintypes

    source = directory / "probe"
    source.mkdir()
    harness.run(source=str(source), destination=str(source), mask="*", expect_errors=False)
    source = directory / "source"
    restricted = source / "restricted"
    _write(source / "before.txt", "not moved")
    _write(restricted / "file.txt", "restricted")
    destination = directory / "destination"
    command = ["icacls", str(restricted)]
    subprocess.run([*command, "/deny", "*S-1-1-0:(RD)"], check=True, capture_output=True)
    try:
        kernel = _windows_kernel()
        kernel.FindFirstFileW.argtypes = [wintypes.LPCWSTR, ctypes.c_void_p]
        kernel.FindFirstFileW.restype = wintypes.HANDLE
        kernel.FindClose.argtypes = [wintypes.HANDLE]
        buffer = ctypes.create_string_buffer(592)
        handle = kernel.FindFirstFileW(str(restricted / "*"), buffer)
        error = ctypes.get_last_error()
        if handle != ctypes.c_void_p(-1).value:
            kernel.FindClose(handle)
            raise AssertionError("Enumeration-denied fixture remained listable")
        assert error == 5, error
        harness.run(source=str(source), destination=str(destination), mask="*.txt", expect_errors=True)
        assert not destination.exists()
        assert (source / "before.txt").read_text(encoding="utf-8") == "not moved"
    finally:
        subprocess.run([*command, "/remove:d", "*S-1-1-0"], check=True, capture_output=True)
    assert (restricted / "file.txt").read_text(encoding="utf-8") == "restricted"


def _move_folder_drive_root(harness, directory):
    source = directory / "probe"
    source.mkdir()
    harness.run(source=str(source), destination=str(source), working=str(directory), expect_errors=False)
    drives = _windows_kernel().GetLogicalDrives()
    drive = next(f"{chr(65 + index)}:" for index in range(25, 6, -1) if not drives & (1 << index))
    volume = directory / "volume"
    volume.mkdir()
    subprocess.run(["subst", drive, str(volume)], check=True, capture_output=True)
    try:
        root = Path(drive + "\\")
        for index in (0, 1):
            source = root / f"source_{index}"
            working = source if index == 0 else source / "child"
            working.mkdir(parents=True)
            name = f"payload_{index}.txt"
            _write(source / name, "drive root")
            # The current directory may block cleanup, but not payload placement.
            harness.run(source=str(source), destination=str(root), working=str(working), expect_errors=None)
            assert (root / name).read_text(encoding="utf-8") == "drive root"
            assert not (source / name).exists()
    finally:
        subprocess.run(["subst", drive, "/d"], check=True, capture_output=True)


def _move_folder_limits(harness, directory):
    source = directory / "probe"
    source.mkdir()
    harness.run(source=str(source), parent=str(directory), leaf=source.name, expect_errors=False)
    assert os.name == "nt", "Extended-length boundary fixtures require Windows"
    path = str(directory)
    extended = Path("\\\\?\\UNC\\" + path[2:] if path.startswith("\\\\") else "\\\\?\\" + path)
    for folder in (False, True):
        for length in (1023, 1024):
            source = directory / f"source_{folder}_{length}"
            parent = extended / f"destination_{folder}_{length}"
            while 1001 - len(str(parent)) - 1 > 200:
                parent /= "p" * 100
            destination = parent / ("d" * (1001 - len(str(parent)) - 1))
            destination.mkdir(parents=True)
            assert len(str(destination)) == 1001
            name = "x" * (length - 1002)
            entry = source / name
            if folder:
                entry.mkdir(parents=True)
            else:
                _write(entry, "source")
            if length == 1024:
                sentinel = destination / name[:-1]
                _write(sentinel / "keep.txt" if folder else sentinel, "sentinel", _DAY)
            harness.run(
                source=str(source), parent=str(destination.parent), leaf=destination.name,
                expect_errors=length == 1024,
            )
            if length == 1024:
                assert entry.exists()
                assert (sentinel / "keep.txt" if folder else sentinel).read_text(encoding="utf-8") == "sentinel"
                if not folder:
                    assert entry.read_text(encoding="utf-8") == "source"
            else:
                assert not source.exists()
                if not folder:
                    assert (destination / name).read_text(encoding="utf-8") == "source"


def _move_file_case_sensitive(harness, directory):
    source = directory / "file.txt"
    _write(source, "probe")
    harness.run(source=str(source), destination=str(source), expect_errors=False)
    directory = directory / "case_sensitive"
    directory.mkdir()
    _enable_case_sensitive(directory)
    source = directory / "file.txt"
    destination = directory / "FILE.txt"
    _write(source, "source")
    _write(destination, "destination", _DAY)
    assert not os.path.samefile(source, destination)
    harness.run(source=str(source), destination=str(destination), expect_errors=False)
    assert not source.exists()
    assert destination.read_text(encoding="utf-8") == "source"


def _move_folder_case_sensitive(harness, directory):
    source = directory / "folder"
    _write(source / "moved.txt", "source")
    harness.run(source=str(source), destination=str(source), mask="*", expect_errors=False)
    directory = directory / "case_sensitive"
    directory.mkdir()
    _enable_case_sensitive(directory)
    source = directory / "folder"
    _write(source / "moved.txt", "source")
    destination = directory / "FOLDER"
    _write(destination / "keep.txt", "destination")
    assert not os.path.samefile(source, destination)
    harness.run(source=str(source), destination=str(destination), mask="*", expect_errors=False)
    assert not source.exists()
    assert (destination / "moved.txt").read_text(encoding="utf-8") == "source"
    assert (destination / "keep.txt").read_text(encoding="utf-8") == "destination"
    _write(source / "nested.txt", "distinct sibling")
    harness.run(source=str(source), destination=str(destination / "nested"), mask="*", expect_errors=False)
    assert not source.exists()
    assert (destination / "nested" / "nested.txt").read_text(encoding="utf-8") == "distinct sibling"


@contextlib.contextmanager
def _second_volume(directory):
    parent = os.environ.get("NSIS_TEST_SECOND_VOLUME") or str(Path(os.environ["SystemRoot"]) / "Temp")
    with tempfile.TemporaryDirectory(prefix="nsis-move-", dir=parent) as other:
        other = Path(other)
        if directory.stat().st_dev == other.stat().st_dev:
            raise unittest.SkipTest("No second volume; configure NSIS_TEST_SECOND_VOLUME to exercise cross-volume moves")
        yield other


def _move_file_cross_volume(harness, directory):
    probe = directory / "probe.txt"
    _write(probe, "probe")
    harness.run(source=str(probe), destination=str(probe), locked=str(probe), expect_errors=False)
    with _second_volume(directory) as other:
        source = directory / "success.txt"
        destination = Path(other) / "success.txt"
        _write(source, "moved across volumes")
        harness.run(source=str(source), destination=str(destination), locked=str(probe), expect_errors=False)
        assert not source.exists()
        assert destination.read_text(encoding="utf-8") == "moved across volumes"
        for existing in (False, True):
            source = directory / f"source_{existing}.txt"
            destination = Path(other) / f"destination_{existing}.txt"
            _write(source, "retained source")
            if existing:
                _write(destination, "older destination", _DAY)
            harness.run(source=str(source), destination=str(destination), locked=str(source), expect_errors=True)
            assert source.read_text(encoding="utf-8") == "retained source"
            if existing:
                assert destination.read_text(encoding="utf-8") == "older destination"
            else:
                assert not destination.exists()


def _move_folder_cross_volume(harness, directory):
    source = directory / "source"
    locked = source / "first.txt"
    _write(locked, "retained source")
    _write(source / "child" / "later.txt", "not reached")
    harness.run(source=str(source), destination=str(source), locked=str(locked), expect_errors=False)
    with _second_volume(directory) as other:
        destination = Path(other) / "destination"
        harness.run(source=str(source), destination=str(destination), locked=str(locked), expect_errors=True)
        assert locked.read_text(encoding="utf-8") == "retained source"
        assert not (destination / "first.txt").exists()
        assert (source / "child" / "later.txt").read_text(encoding="utf-8") == "not reached"
        assert not (destination / "child" / "later.txt").exists()


def _move_file_copy_only(harness, directory):
    for existing in (False, True):
        source = directory / f"source_{existing}.txt"
        destination = directory / f"destination_{existing}.txt"
        _write(source, "retained source")
        if existing:
            _write(destination, "older destination", _DAY)
        harness.run(source=str(source), destination=str(destination), expect_errors=True)
        assert source.read_text(encoding="utf-8") == "retained source"
        assert destination.read_text(encoding="utf-8") == "retained source"


def _move_folder_copy_only(harness, directory):
    source = directory / "source"
    destination = directory / "destination"
    _write(source / "first.txt", "retained source")
    _write(source / "child" / "later.txt", "not reached")
    harness.run(source=str(source), destination=str(destination), mask="*", expect_errors=True)
    assert (source / "first.txt").read_text(encoding="utf-8") == "retained source"
    assert (destination / "first.txt").read_text(encoding="utf-8") == "retained source"
    assert (source / "child" / "later.txt").read_text(encoding="utf-8") == "not reached"
    assert not (destination / "child" / "later.txt").exists()


def _backup_file(harness, directory):
    # Dots in parent directories and leading dots are not file extensions.
    parent = directory / "parent.with.dots"
    for name, stem, extension in [
        ("file.txt", "file", ".txt"),
        ("archive.tar.gz", "archive.tar", ".gz"),
        ("no_extension", "no_extension", ""),
        (".hidden", ".hidden", ""),
    ]:
        source = parent / name
        for number in range(1, 4):
            _write(source, f"backup {number}")
            harness.run(source=str(source), expect_errors=False)
            suffix = "" if number == 1 else f" ({number})"
            backup = parent / f"{stem} - Backup{suffix}{extension}"
            assert backup.read_text(encoding="utf-8") == f"backup {number}"
            assert not source.exists()
        assert (parent / f"{stem} - Backup{extension}").read_text(encoding="utf-8") == "backup 1"

    # A directory with the target filename is also a collision, even if empty.
    source = directory / "collision.txt"
    (directory / "collision - Backup.txt").mkdir()
    _write(source, "file after directory")
    harness.run(source=str(source), expect_errors=False)
    assert (directory / "collision - Backup (2).txt").read_text(encoding="utf-8") == "file after directory"
    assert (directory / "collision - Backup.txt").is_dir()

    harness.run(source=str(directory / "missing.txt"), expect_errors=True)
    harness.run(source=str(parent), expect_errors=True)
    harness.run(source="", expect_errors=True)
    assert parent.is_dir()

    parent = directory / "wildcards"
    for name in ("keep.txt", "other.txt"):
        _write(parent / name, name)
    for pattern in ("*.txt", "keep.?xt", "*\\..\\keep.txt", "?\\..\\keep.txt"):
        harness.run(source=str(parent / pattern), expect_errors=True)
        assert sorted(path.name for path in parent.iterdir()) == ["keep.txt", "other.txt"]
        for name in ("keep.txt", "other.txt"):
            assert (parent / name).read_text(encoding="utf-8") == name

    # A valid source filename whose backup exceeds the filesystem's component
    # limit must report the rename failure without deleting the source.
    source = directory / ("a" * 244 + ".txt")
    if os.name == "nt":
        path = str(source)
        source = Path("\\\\?\\UNC\\" + path[2:] if path.startswith("\\\\") else "\\\\?\\" + path)
    _write(source, "keep on failure")
    harness.run(source=str(source), expect_errors=True)
    assert source.read_text(encoding="utf-8") == "keep on failure"


def _backup_folder(harness, directory):
    source = directory / "folder.with.dots"
    for number in range(1, 4):
        _write(source / "child" / "file.txt", f"backup {number}")
        (source / "empty").mkdir()
        harness.run(source=str(source) + "\\", expect_errors=False)
        suffix = "" if number == 1 else f" ({number})"
        backup = directory / f"folder.with.dots - Backup{suffix}"
        assert (backup / "child" / "file.txt").read_text(encoding="utf-8") == f"backup {number}"
        assert (backup / "empty").is_dir()
        assert not source.exists()
    assert (directory / "folder.with.dots - Backup" / "child" / "file.txt").read_text(encoding="utf-8") == "backup 1"

    source = directory / "collision"
    _write(directory / "collision - Backup", "existing file")
    source.mkdir()
    harness.run(source=str(source), expect_errors=False)
    assert (directory / "collision - Backup (2)").is_dir()
    assert (directory / "collision - Backup").read_text(encoding="utf-8") == "existing file"
    assert not source.exists()

    harness.run(source=str(directory / "missing"), expect_errors=True)
    harness.run(source=str(directory / "collision - Backup"), expect_errors=True)
    harness.run(source=str(directory.anchor), expect_errors=True)
    assert (directory / "collision - Backup").read_text(encoding="utf-8") == "existing file"

    parent = directory / "wildcards"
    for name in ("keep", "other"):
        _write(parent / name / "payload.txt", name)
    for pattern in ("keep*", "?ther", "*\\..\\keep", "?\\..\\keep"):
        harness.run(source=str(parent / pattern), expect_errors=True)
        assert sorted(path.name for path in parent.iterdir()) == ["keep", "other"]
        for name in ("keep", "other"):
            assert (parent / name / "payload.txt").read_text(encoding="utf-8") == name


def _backup_limits(harness, directory, folder):
    source = directory / "probe"
    if folder:
        source.mkdir()
    else:
        _write(source, "probe")
    harness.run(parent=str(source.parent), leaf=source.name, expect_errors=False)
    assert os.name == "nt", "Extended-length boundary fixtures require Windows"
    path = str(directory)
    directory = Path("\\\\?\\UNC\\" + path[2:] if path.startswith("\\\\") else "\\\\?\\" + path)
    for length, number in ((1023, 1), (1024, 1), (1023, 2), (1024, 2)):
        suffix = " - Backup" if number == 1 else " - Backup (2)"
        source_length = length - len(suffix)
        parent = directory / f"length_{length}_{number}"
        while source_length - len(str(parent)) - 1 > 200:
            parent /= "p" * 100
        source = parent / ("x" * (source_length - len(str(parent)) - 1))
        destination = source.with_name(source.name + suffix)
        assert len(str(source)) == source_length
        assert len(str(destination)) == length
        if folder:
            _write(source / "payload.txt", "source")
        else:
            _write(source, "source")
        if number == 2:
            first = source.with_name(source.name + " - Backup")
            _write(first / "payload.txt" if folder else first, "first backup")
        harness.run(parent=str(source.parent), leaf=source.name, expect_errors=length == 1024)
        retained = source if length == 1024 else destination
        assert (retained / "payload.txt" if folder else retained).read_text(encoding="utf-8") == "source"
        assert source.exists() == (length == 1024)
        assert destination.exists() == (length == 1023)
        if number == 2:
            assert (first / "payload.txt" if folder else first).read_text(encoding="utf-8") == "first backup"


def run_case(case, harness, args):
    base = common.base(case)
    directory = harness.directory
    edge_cases = {
        "move_file_paths": _move_file_paths,
        "move_file_invalid": _move_file_invalid,
        "move_file_locked": _move_file_locked,
        "move_folder_paths": _move_folder_paths,
        "move_folder_invalid": _move_folder_invalid,
        "move_folder_merge": _move_folder_merge,
        "move_file_aliases": _move_file_aliases,
        "move_folder_aliases": _move_folder_aliases,
        "move_file_case_sensitive": _move_file_case_sensitive,
        "move_folder_case_sensitive": _move_folder_case_sensitive,
        "move_folder_enumeration": _move_folder_enumeration,
        "move_folder_drive_root": _move_folder_drive_root,
        "move_folder_limits": _move_folder_limits,
        "move_file_cross_volume": _move_file_cross_volume,
        "move_folder_cross_volume": _move_folder_cross_volume,
        "move_file_copy_only": _move_file_copy_only,
        "move_folder_copy_only": _move_folder_copy_only,
    }
    if base.removesuffix("_overwrite") in edge_cases:
        edge_cases[base.removesuffix("_overwrite")](harness, directory)
        return
    if base in ("move_file", "move_file_overwrite"):
        _move_file(harness, directory, base.endswith("_overwrite"))
    elif base == "move_file_twice":
        files = [directory / name for name in ("a.txt", "b.txt", "c.txt", "d.txt")]
        files[0].write_text("first", encoding="utf-8")
        files[2].write_text("second", encoding="utf-8")
        harness.run(
            first_source=str(files[0]), first_destination=str(files[1]),
            second_source=str(files[2]), second_destination=str(files[3]),
            expect_errors=False,
        )
        assert files[1].read_text(encoding="utf-8") == "first"
        assert files[3].read_text(encoding="utf-8") == "second"
        assert not files[0].exists() and not files[2].exists()
    elif base in ("move_folder", "move_folder_overwrite"):
        _move_folder(harness, directory, base.endswith("_overwrite"))
    elif base == "move_folder_cleanup_failure":
        source = directory / "source"
        # Simulate a file appearing after Locate classified the directory as
        # empty. A failed removal must not advance the cleanup progress count.
        _write(source / "keep.txt", "keep")
        harness.run(source=str(source), expect_errors=True).assert_outputs(removed=0)
        assert (source / "keep.txt").read_text(encoding="utf-8") == "keep"
    elif base == "move_folder_locked_directory":
        source = directory / "source"
        destination = directory / "destination"
        (source / "empty").mkdir(parents=True)
        harness.run(source=str(source), destination=str(destination), expect_errors=True)
        assert source.is_dir()
        assert (destination / "empty").is_dir()
    elif base in ("move_file_recovery", "move_folder_recovery"):
        source = directory / "source"
        destination = directory / "destination"
        source_file = source / "child.txt" if base == "move_folder_recovery" else source
        destination_file = destination / "child.txt" if base == "move_folder_recovery" else destination
        _write(source_file, "recovered")
        harness.run(source=str(source), destination=str(destination), expect_errors=False).assert_outputs(first_failed=True)
        assert destination_file.read_text(encoding="utf-8") == "recovered"
        assert not source.exists()
    elif base == "backup_file":
        _backup_file(harness, directory)
    elif base == "backup_folder":
        _backup_folder(harness, directory)
    elif base in ("backup_file_limits", "backup_folder_limits"):
        _backup_limits(harness, directory, base == "backup_folder_limits")
    elif base == "backup_twice":
        source_file = directory / "file.txt"
        source_folder = directory / "folder"
        _write(source_file, "file")
        _write(source_folder / "child.txt", "folder")
        harness.run(first_source=str(source_file), second_source=str(source_folder), expect_errors=False)
        assert (directory / "file - Backup.txt").read_text(encoding="utf-8") == "file"
        assert (directory / "folder - Backup" / "child.txt").read_text(encoding="utf-8") == "folder"
        assert not source_file.exists() and not source_folder.exists()
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    result = unittest.TextTestRunner().run(unittest.FunctionTestCase(lambda: common.main(run_case)))
    sys.exit(0 if result.wasSuccessful() else 1)
