import os
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
    """Moves onto existing destinations, one older and one newer than the source.

    By default only the older destination is replaced and the source is always
    removed; with $switch_overwrite both are replaced.
    """
    for name, source_age, destination_age in [
        ("newer_source", 0, _DAY),
        ("older_source", _DAY, 0),
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
        harness.run(source=str(source), destination=str(destination), expect_errors=False)
        return source, destination

    _existing_destination(move, overwrite)


def _move_folder(harness, directory, overwrite):
    source = directory / "source"
    destination = directory / "destination"
    _write(source / "child" / "source.txt", "move folder test")
    harness.run(source=str(source), destination=str(destination), mask="*.txt")
    assert (destination / "child" / "source.txt").read_text(encoding="utf-8") == "move folder test"
    assert not source.exists()

    # Files outside the mask stay behind, keeping the source folder.
    _write(source / "child" / "moved.txt", "moved")
    _write(source / "child" / "kept.log", "kept")
    harness.run(source=str(source), destination=str(destination), mask="*.txt")
    assert (destination / "child" / "moved.txt").read_text(encoding="utf-8") == "moved"
    assert (source / "child" / "kept.log").read_text(encoding="utf-8") == "kept"
    assert not (destination / "child" / "kept.log").exists()
    assert not (source / "child" / "moved.txt").exists()

    def move(name, source_age, destination_age):
        source = directory / (name + "_source")
        destination = directory / (name + "_destination")
        _write(source / "file.txt", "source", source_age)
        _write(destination / "file.txt", "destination", destination_age)
        harness.run(source=str(source), destination=str(destination), mask="*.*")
        return source / "file.txt", destination / "file.txt"

    _existing_destination(move, overwrite)


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
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
