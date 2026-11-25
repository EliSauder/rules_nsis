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
    earlier = (ticks + 0x7FFFFFFF) / 10_000_000 - 11644473600
    later = (ticks + 0x80000000 + 10_000_000) / 10_000_000 - 11644473600
    source = directory / "timestamp.src"
    destination = directory / "timestamp.dst"
    _write(source, "newer")
    _write(destination, "older")
    os.utime(source, (later, later))
    os.utime(destination, (earlier, earlier))
    harness.run(source=str(source), destination=str(destination), expect_errors=False)
    assert destination.read_text(encoding="utf-8") == "newer"
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


def run_case(case, harness, args):
    base = common.base(case)
    directory = harness.directory
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
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
