from tests.includes import common


def run_case(case, harness, args):
    if common.base(case) != "normalize_guid":
        raise common.unhandled(case)
    guid = "aabbccdd-eeff-0011-2233-445566778899"
    expected = "{AABBCCDD-EEFF-0011-2233-445566778899}"
    for value in (guid, "{" + guid + "}"):
        harness.run(value=value).assert_outputs(result=expected)
    for value in ("not-a-guid", guid[:-1] + "z"):
        harness.run(value=value).assert_outputs(result="")


if __name__ == "__main__":
    common.main(run_case)
