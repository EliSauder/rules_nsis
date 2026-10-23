from tests.includes import common


def run_case(case, harness, args):
    base = common.base(case)
    directory = harness.directory
    if base == "move_file":
        source = directory / "source.txt"
        destination = directory / "destination.txt"
        source.write_text("move test", encoding="utf-8")
        harness.run(source=str(source), destination=str(destination), expect_errors=False)
        assert destination.read_text(encoding="utf-8") == "move test"
        assert not source.exists()
        harness.run(source=str(directory / "missing.txt"), destination=str(directory / "never.txt"), expect_errors=True)
        assert not (directory / "never.txt").exists()
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
    elif base == "move_folder":
        source = directory / "source"
        destination = directory / "destination"
        (source / "child").mkdir(parents=True)
        (source / "child" / "source.txt").write_text("move folder test", encoding="utf-8")
        harness.run(source=str(source), destination=str(destination), mask="*.txt")
        assert (destination / "child" / "source.txt").read_text(encoding="utf-8") == "move folder test"
        assert not source.exists()
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
