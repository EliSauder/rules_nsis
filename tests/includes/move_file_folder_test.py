import os
import stat
import time

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
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
