from tests.includes import common

_INI = """[first]
Key=one
key=two
Other=x

[Second]
empty=
list=a
"""


def _ini(harness):
    path = harness.directory / "test.ini"
    path.write_text(_INI, encoding="utf-8")
    return str(path)


def run_case(case, harness, args):
    base = common.base(case)
    if base == "ini_read_list":
        path = _ini(harness)
        # A repeated key yields every value, and the names compare case-insensitively.
        harness.run(file=path, section="first", key="KEY").assert_outputs(count="2", first="one", second="two", missing=False)
        harness.run(file=path, section="first", key="other").assert_outputs(count="1", first="x", second="", missing=False)
        harness.run(file=path, section="Second", key="empty").assert_outputs(count="1", first="", second="", missing=False)
        harness.run(file=path, section="first", key="nope").assert_outputs(count="0", first="", second="", missing=True)
        harness.run(file=path, section="nope", key="Key").assert_outputs(count="0", first="", second="", missing=True)
    elif base == "ini_read_str":
        path = _ini(harness)
        harness.run(file=path, section="Second", key="list").assert_outputs(value="a", missing=False)
        harness.run(file=path, section="Second", key="nope").assert_outputs(value="", missing=True)
    elif base == "ini_names":
        path = _ini(harness)
        harness.run(file=path, section="first").assert_outputs(sections="first,Second", keys="Key,key,Other")
        harness.run(file=path, section="nope").assert_outputs(sections="first,Second", keys="")
    elif base == "ini_format_list":
        out = harness.directory / "format.txt"
        for a, b, expected in [
            ("x", "y", "k=x\r\nk=y\r\n"),
            ("x", "", "k=x\r\n"),
            ("", "", "k=\r\n"),
        ]:
            harness.run(a=a, b=b, key="k", out_file=str(out))
            assert out.read_bytes().decode("ascii") == expected, (a, b)
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
