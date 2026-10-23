import contextlib
import ctypes
import os
import re
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

from nsis.testing import Harness
from tests.includes import common

# Cases that are given an invalid service name rather than a missing one.
_INVALID_NAME = ("service_create", "service_update", "service_delete", "service_set_description")
_CASES = _INVALID_NAME + ("service_query", "service_start", "service_stop")

# Lifecycle harness arguments, in the order sc.bzl passes them.
_OPERATIONS = ("create", "query", "update", "start", "stop", "delete", "set_description")

_ERROR_SERVICE_DOES_NOT_EXIST = "1060"


def run_case(case, harness, args):
    """Every macro reports sc's failure for a service that cannot exist."""
    base = common.base(case)
    if base not in _CASES:
        raise common.unhandled(case)
    prefix = "RulesNsis/Invalid-" if base in _INVALID_NAME else "RulesNsisMissing-"
    params = {"name": prefix + uuid.uuid4().hex}
    if base in ("service_create", "service_update"):
        params.update(binary=r"C:\Windows\System32\cmd.exe", display_name="Missing", start_type="demand", dependencies="")
    elif base == "service_set_description":
        params["description"] = "Missing service"
    assert harness.run(**params).outputs["result"] not in ("", "0")


def _sc(*args):
    return subprocess.run(
        [os.path.join(os.environ["SystemRoot"], "System32", "sc.exe"), *args],
        capture_output=True, text=True, check=False,
    )


def _field(output, name):
    match = re.search(r"^\s*" + name + r"\s*:\s*(.*?)\s*$", output, re.MULTILINE)
    assert match, output
    return match.group(1)


def _wait_for_state(name, state):
    deadline = time.monotonic() + 30
    while True:
        output = _sc("query", name).stdout
        if state in _field(output, "STATE"):
            return
        assert time.monotonic() < deadline, output
        time.sleep(0.25)


def lifecycle(stub, harnesses, directory):
    name = "RulesNsisStub" + uuid.uuid4().hex
    binary = directory / "service stub" / "service_stub.exe"
    binary.parent.mkdir()
    shutil.copyfile(stub, binary)
    run = {operation: harnesses[operation].run for operation in _OPERATIONS}
    try:
        run["query"](name=name).assert_outputs(result=_ERROR_SERVICE_DOES_NOT_EXIST)
        run["create"](
            name=name, binary=str(binary), display_name="Rules NSIS stub",
            start_type="demand", dependencies="",
        ).assert_outputs(result="0")
        run["query"](name=name).assert_outputs(result="0")
        config = _sc("qc", name).stdout
        assert "DEMAND_START" in _field(config, "START_TYPE"), config
        assert _field(config, "DISPLAY_NAME") == "Rules NSIS stub", config
        assert _field(config, "BINARY_PATH_NAME").strip('"') == str(binary), config

        run["set_description"](name=name, description="Rules NSIS stub service").assert_outputs(result="0")
        description = _sc("qdescription", name).stdout
        assert _field(description, "DESCRIPTION") == "Rules NSIS stub service", description

        run["start"](name=name).assert_outputs(result="0")
        _wait_for_state(name, "RUNNING")
        run["stop"](name=name).assert_outputs(result="0")
        _wait_for_state(name, "STOPPED")

        run["update"](
            name=name, binary=str(binary), display_name="Rules NSIS stub updated",
            start_type="auto", dependencies="",
        ).assert_outputs(result="0")
        config = _sc("qc", name).stdout
        assert "AUTO_START" in _field(config, "START_TYPE"), config
        assert _field(config, "DISPLAY_NAME") == "Rules NSIS stub updated", config

        run["delete"](name=name).assert_outputs(result="0")
        run["query"](name=name).assert_outputs(result=_ERROR_SERVICE_DOES_NOT_EXIST)
    finally:
        _sc("stop", name)
        _sc("delete", name)


def main():
    if not sys.argv[1].endswith("service_lifecycle"):
        common.main(run_case)
        return
    stub, *pairs = sys.argv[2:]
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("Skipping: creating a service requires an elevated test run.")
        return
    assert len(pairs) == len(_OPERATIONS), pairs
    directory = Path(os.environ["TEST_TMPDIR"])
    with contextlib.ExitStack() as stack:
        harnesses = {}
        for operation, pair in zip(_OPERATIONS, pairs):
            binary, description = pair.split("=", 1)
            harnesses[operation] = stack.enter_context(Harness(
                common.rlocation(binary), common.rlocation(description),
                directory=directory,
            ))
        lifecycle(common.rlocation(stub), harnesses, directory)


if __name__ == "__main__":
    main()
