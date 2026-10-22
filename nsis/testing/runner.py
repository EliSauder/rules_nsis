"""Python interface for generated NSIS API harnesses (Windows only)."""

import json
import os
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from .generate import REGISTERS, validate


def command_line(command):
    # NSIS reads the raw Windows command line, not CRT argv. GetOptions needs
    # /name="value with spaces", not "/name=value with spaces".
    arguments = [subprocess.list2cmdline([command[0]])]
    for argument in command[1:]:
        if argument.startswith("/") and "=" in argument:
            name, value = argument.split("=", 1)
            arguments.append(f'{name}="{value}"')
        else:
            arguments.append(argument)
    return " ".join(arguments)


def read_outputs(path, names):
    """Read length-prefixed UTF-16 records without trimming or interpolation."""
    raw = Path(path).read_bytes()
    header = "NSIS-HARNESS-1\n".encode("utf-16-le")
    if not raw.startswith(header):
        raise ValueError("Invalid harness output header")
    raw = raw[len(header):]
    values = {}
    for name in names:
        prefix = (name + ":").encode("utf-16-le")
        if not raw.startswith(prefix):
            raise ValueError(f"Missing output parameter {name}")
        raw = raw[len(prefix):]
        # Search only aligned UTF-16 code units.
        end = next((i for i in range(0, len(raw), 2) if raw[i:i + 2] == b":\0"), None)
        if end is None:
            raise ValueError(f"Missing output length for {name}")
        size_text = raw[:end].decode("utf-16-le")
        if not size_text.isascii() or not size_text.isdigit():
            raise ValueError(f"Invalid output length for {name}")
        size = int(size_text) * 2
        raw = raw[end + 2:]
        if len(raw) < size:
            raise ValueError(f"Truncated output parameter {name}")
        values[name] = raw[:size].decode("utf-16-le")
        raw = raw[size:]
    if raw:
        raise ValueError("Unexpected trailing harness output")
    return values


@dataclass(frozen=True)
class Result:
    outputs: dict[str, str]
    returncode: int
    stdout: str
    stderr: str
    directory: Path

    def assert_outputs(self, **expected):
        if self.outputs != expected:
            raise AssertionError(f"Expected {expected!r}; got {self.outputs!r}")
        return self


class Harness:
    """Use as a context manager; files remain available until context exit."""

    def __init__(self, binary, description, *, directory=None, timeout=30):
        self.binary = Path(binary).resolve()
        self.spec = validate(
            json.loads(Path(description).read_text(encoding="utf-8"))
            if isinstance(description, (str, Path)) else description
        )
        self.timeout = timeout
        self._temporary = tempfile.TemporaryDirectory(
            prefix="nsis-api-", dir=directory
        )
        self.directory = Path(self._temporary.name)

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    def close(self):
        self._temporary.cleanup()

    def _execute(self, command):
        return subprocess.run(
            command_line(command) if os.name == "nt" else command,
            cwd=self.directory, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=self.timeout, check=False,
        )

    def run(self, *, expected_exitcode=0, **inputs):
        parameters = self.spec.get("parameters", [])
        required = {p["name"] for p in parameters if p["direction"] != "out"}
        if inputs.keys() != required:
            raise ValueError(
                f"Expected inputs {sorted(required)}; got {sorted(inputs)}"
            )
        for name, value in inputs.items():
            if not isinstance(value, str) or any(c in value for c in '\x00\r\n"'):
                raise ValueError(f"{name} must be a single-line string without quotes or NUL")
        output = self.directory / "outputs.dat"
        output.unlink(missing_ok=True)
        registers = self.directory / "outputs.dat.registers"
        registers.unlink(missing_ok=True)
        executable = self.binary
        if self.spec.get("context", "installer") == "uninstaller":
            executable = self.directory / "uninstall.exe"
            prepare = self._execute([
                str(self.binary), "/S", f"/harness_uninstaller={executable}",
            ])
            if prepare.returncode or not executable.is_file():
                raise AssertionError(
                    f"Uninstaller preparation failed ({prepare.returncode}): "
                    f"{prepare.stdout}\n{prepare.stderr}"
                )
        command = [
            str(executable), "/S", f"/output={output}",
            *(f"/{name}={value}" for name, value in inputs.items()),
        ]
        if self.spec.get("context", "installer") == "uninstaller":
            command.append(f"_?={self.directory}")
        process = self._execute(command)
        if registers.exists():
            snapshots = read_outputs(
                registers,
                [f"{when}_{r}" for r in REGISTERS for when in ("before", "after")],
            )
            changes = [
                f"${r}: expected {snapshots[f'before_{r}']!r}, "
                f"got {snapshots[f'after_{r}']!r}"
                for r in REGISTERS
                if snapshots[f"before_{r}"] != snapshots[f"after_{r}"]
            ]
            if not changes:
                raise AssertionError("Harness reported register corruption without changes")
            raise AssertionError(
                "NSIS registers changed:\n" + "\n".join(changes)
                + f"\nstdout: {process.stdout}\nstderr: {process.stderr}"
            )
        if process.returncode != expected_exitcode:
            raise AssertionError(
                f"Expected exit {expected_exitcode}; got {process.returncode}\n"
                f"stdout: {process.stdout}\nstderr: {process.stderr}"
            )
        values = {}
        if output.exists():
            values = read_outputs(
                output, [p["name"] for p in parameters if p["direction"] != "in"]
            )
        elif expected_exitcode == 0:
            raise AssertionError(
                f"Harness exited without returning outputs\n"
                f"stdout: {process.stdout}\nstderr: {process.stderr}"
            )
        return Result(
            values, process.returncode, process.stdout, process.stderr, self.directory
        )
