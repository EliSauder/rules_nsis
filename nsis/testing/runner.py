"""Python interface for generated NSIS API harnesses (Windows only)."""

import json
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from .generate import ERRORS_RECORD, HEADER, REGISTERS, STACK_RECORDS, inputs as input_parameters, outputs as output_parameters, validate


def serialize_input(parameter, value):
    name = parameter["name"]
    typ = parameter.get("type", "string")
    if typ == "bool":
        if type(value) is not bool:
            raise ValueError(f"{name} must be a bool")
        return "1" if value else "0"
    if typ == "int":
        if type(value) is not int or not -(2**31) <= value < 2**31:
            raise ValueError(f"{name} must be a signed 32-bit int")
        return str(value)
    if not isinstance(value, str) or any(c in value for c in '\x00\r\n"'):
        raise ValueError(f"{name} must be a single-line string without quotes or NUL")
    return value


def deserialize_output(parameter, value):
    name = parameter["name"]
    typ = parameter.get("type", "string")
    if typ == "bool":
        if value not in ("0", "1"):
            raise ValueError(f"{name}: expected bool output 0 or 1; got {value!r}")
        return value == "1"
    if typ == "int":
        if not re.fullmatch(r"-?[0-9]+", value):
            raise ValueError(f"{name}: expected decimal int output; got {value!r}")
        result = int(value)
        if not -(2**31) <= result < 2**31:
            raise ValueError(f"{name}: int output outside signed 32-bit range: {value!r}")
        return result
    return value


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
    header = f"{HEADER}\n".encode("utf-16-le")
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
    """API outputs converted to declared Python types, plus process diagnostics.

    errors is the NSIS error flag immediately after the API returned, or None
    when the harness exited before reporting outputs.
    """

    outputs: dict[str, str | int | bool]
    errors: bool | None
    returncode: int
    stdout: str
    stderr: str
    directory: Path

    def assert_outputs(self, **expected):
        if self.outputs != expected or any(
            type(value) is not type(expected[name])
            for name, value in self.outputs.items()
        ):
            raise AssertionError(f"Expected {expected!r}; got {self.outputs!r}")
        return self


class Harness:
    """Run an API with typed inputs/outputs; files persist until context exit.

    Parameters default to string. Declared int parameters require signed 32-bit
    Python integers, and bool parameters require Python booleans (NSIS uses 1/0).
    Invalid inputs or malformed typed outputs raise ValueError.
    """

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

    def run(self, *, expected_exitcode=0, expect_errors=None, **inputs):
        """Invoke the API once.

        expect_errors=True/False asserts the NSIS error flag after the call;
        None (default) leaves it unchecked but still reports Result.errors.
        """
        if not (expect_errors is None or type(expect_errors) is bool):
            raise ValueError("expect_errors must be None, True, or False")
        required = {p["name"] for p in input_parameters(self.spec)}
        if inputs.keys() != required:
            raise ValueError(
                f"Expected inputs {sorted(required)}; got {sorted(inputs)}"
            )
        serialized = {
            p["name"]: serialize_input(p, inputs[p["name"]])
            for p in input_parameters(self.spec)
        }
        output = self.directory / "outputs.dat"
        output.unlink(missing_ok=True)
        registers = self.directory / "outputs.dat.registers"
        registers.unlink(missing_ok=True)
        stack = self.directory / "outputs.dat.stack"
        stack.unlink(missing_ok=True)
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
            *(f"/{name}={value}" for name, value in serialized.items()),
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
        if stack.exists():
            snapshot = read_outputs(stack, STACK_RECORDS)
            actual = (
                "the stack was empty" if snapshot["underflow"] == "1"
                else f"found {snapshot['actual']!r}"
            )
            raise AssertionError(
                "NSIS stack is unbalanced: expected the harness sentinel "
                f"{snapshot['expected']!r} on top after the call, but {actual}"
                f"\nstdout: {process.stdout}\nstderr: {process.stderr}"
            )
        if process.returncode != expected_exitcode:
            raise AssertionError(
                f"Expected exit {expected_exitcode}; got {process.returncode}\n"
                f"stdout: {process.stdout}\nstderr: {process.stderr}"
            )
        values = {}
        errors = None
        if output.exists():
            names = [p["name"] for p in output_parameters(self.spec)]
            values = read_outputs(output, [*names, ERRORS_RECORD])
            if values[ERRORS_RECORD] not in ("0", "1"):
                raise ValueError(f"Invalid error flag record {values[ERRORS_RECORD]!r}")
            errors = values[ERRORS_RECORD] == "1"
            values = {
                p["name"]: deserialize_output(p, values[p["name"]])
                for p in output_parameters(self.spec)
            }
        elif expected_exitcode == 0:
            raise AssertionError(
                f"Harness exited without returning outputs\n"
                f"stdout: {process.stdout}\nstderr: {process.stderr}"
            )
        if expect_errors is not None and errors is not expect_errors:
            raise AssertionError(
                f"Expected the NSIS error flag to be "
                f"{'set' if expect_errors else 'clear'}; it was "
                f"{'not reported' if errors is None else 'set' if errors else 'clear'}"
                f"\nstdout: {process.stdout}\nstderr: {process.stderr}"
            )
        return Result(
            values, errors, process.returncode, process.stdout, process.stderr, self.directory
        )
