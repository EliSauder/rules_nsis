import uuid

from tests.includes import common


def run_case(case, harness, args):
    if common.base(case) != "mutex":
        raise common.unhandled(case)
    assert harness.run(name="RulesNsisIncludeApi-" + str(uuid.uuid4())).returncode == 0


if __name__ == "__main__":
    common.main(run_case)
