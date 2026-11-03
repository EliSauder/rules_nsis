"""Python interface for generated NSIS API harnesses (Windows only)."""

import json
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from .generate import ERRORS_RECORD, HEADER, REGISTERS, STACK_RECORDS, inputs as input_parameters, outputs as output_parameters, validate


# NSIS strings, and so the lines of the input file, hold at most 1023 characters.
MAX_INPUT_LINE = 1000


def escape(text):
    """Percent-escapes quotes, control characters and non-ASCII (as UTF-16 code
    units, %uXXXX), so that an input line is plain ASCII with no line break."""
    out = []
    for char in text:
        if char in '%"' or ord(char) < 0x20 or ord(char) > 0x7E:
            if ord(char) < 0x100:
                out.append(f"%{ord(char):02X}")
            else:
                units = char.encode("utf-16-le")
                out += [f"%u{int.from_bytes(units[i:i + 2], 'little'):04X}" for i in range(0, len(units), 2)]
        else:
            out.append(char)
    return "".join(out)


def _check_text(name, value):
    if not isinstance(value, str) or "\0" in value:
        raise ValueError(f"{name} must be a string without NUL")
    return value


def _input_line(name, value):
    line = f"{name}={escape(_check_text(name, value))}"
    if len(line) > MAX_INPUT_LINE:
        raise ValueError(f"{name}: an escaped input value can have at most {MAX_INPUT_LINE - len(name) - 1} characters")
    return line


def serialize_input(parameter, value):
    """The "name=value" line of an input, or one such line per item of a list."""
    name = parameter["name"]
    typ = parameter.get("type", "string")
    if typ == "bool":
        if type(value) is not bool:
            raise ValueError(f"{name} must be a bool")
        return f"{name}={int(value)}"
    if typ == "int":
        if type(value) is not int or not -(2**31) <= value < 2**31:
            raise ValueError(f"{name} must be a signed 32-bit int")
        return f"{name}={value}"
    if typ == "list":
        if isinstance(value, str) or not all(isinstance(item, str) for item in value):
            raise ValueError(f"{name} must be a sequence of strings")
        return [_input_line(name, item) for item in value]
    return _input_line(name, value)


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


class Raw(str):
    """A command line arg passed verbatim, without the harness's quoting."""


def command_line(command):
    # NSIS reads the raw Windows command line, not CRT argv. GetOptions needs
    # /name="value with spaces", not "/name=value with spaces".
    arguments = [subprocess.list2cmdline([command[0]])]
    for argument in command[1:]:
        if isinstance(argument, Raw):
            arguments.append(str(argument))
        elif argument.startswith("/") and "=" in argument:
            name, value = argument.split("=", 1)
            arguments.append(f'{name}="{value}"')
        else:
            arguments.append(argument)
    return " ".join(arguments)


def _take_number(raw, name):
    # Search only aligned UTF-16 code units.
    end = next((i for i in range(0, len(raw), 2) if raw[i:i + 2] == b":\0"), None)
    if end is None:
        raise ValueError(f"Missing output length for {name}")
    text = raw[:end].decode("utf-16-le")
    if not text.isascii() or not text.isdigit():
        raise ValueError(f"Invalid output length for {name}")
    return int(text), raw[end + 2:]


def _take_text(raw, size, name):
    if len(raw) < size * 2:
        raise ValueError(f"Truncated output parameter {name}")
    return raw[:size * 2].decode("utf-16-le"), raw[size * 2:]


def read_outputs(path, names, lists=()):
    """Read length-prefixed UTF-16 records without trimming or interpolation.

    A record is name:length:text. A list in lists is name:count: and then
    length:text for each item.
    """
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
        number, raw = _take_number(raw[len(prefix):], name)
        if name in lists:
            values[name] = []
            for _ in range(number):
                size, raw = _take_number(raw, name)
                item, raw = _take_text(raw, size, name)
                values[name].append(item)
        else:
            values[name], raw = _take_text(raw, number, name)
    if raw:
        raise ValueError("Unexpected trailing harness output")
    return values


@dataclass(frozen=True)
class Result:
    """API outputs converted to declared Python types, plus process diagnostics.

    errors is the NSIS error flag immediately after the API returned, or None
    when the harness exited before reporting outputs.
    """

    outputs: dict[str, str | int | bool | list[str]]
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

    def run(self, *, expected_exitcode=0, expect_errors=None, command_args=(), command_tail=(), **inputs):
        """Invoke the API once.

        expect_errors=True/False asserts the NSIS error flag after the call;
        None (default) leaves it unchecked but still reports Result.errors.
        For APIs that read the command line, command_args are inserted verbatim
        right after the executable, and command_tail is appended verbatim at the very
        end, where NSIS expects a /D= arg. Quoted args must come first because
        GetOptions, which the harness reads its own args with, mishandles
        quoted args that follow a quoted value.
        """
        for name, extra in (("command_args", command_args), ("command_tail", command_tail)):
            if isinstance(extra, str) or not all(isinstance(a, str) for a in extra):
                raise ValueError(f"{name} must be a sequence of strings")
        if not (expect_errors is None or type(expect_errors) is bool):
            raise ValueError("expect_errors must be None, True, or False")
        required = {p["name"] for p in input_parameters(self.spec)}
        if inputs.keys() != required:
            raise ValueError(
                f"Expected inputs {sorted(required)}; got {sorted(inputs)}"
            )
        input_lines = []
        for p in input_parameters(self.spec):
            line = serialize_input(p, inputs[p["name"]])
            input_lines += line if isinstance(line, list) else [line]
        input_file = self.directory / "outputs.dat.inputs"
        input_file.write_bytes("".join(f"{line}\n" for line in input_lines).encode("ascii"))
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
        ]
        # The harness reads its inputs from the file next to the output. The
        # scalars are also passed as options, for APIs that read the command line.
        for p in input_parameters(self.spec):
            if p.get("type") != "list":
                command.append("/" + serialize_input(p, inputs[p["name"]]))
        if self.spec.get("context", "installer") == "uninstaller":
            command.append(f"_?={self.directory}")
        command = [command[0], *map(Raw, command_args), *command[1:], *map(Raw, command_tail)]
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
            lists = {p["name"] for p in output_parameters(self.spec) if p.get("type") == "list"}
            values = read_outputs(output, [*names, ERRORS_RECORD], lists)
            if values[ERRORS_RECORD] not in ("0", "1"):
                raise ValueError(f"Invalid error flag record {values[ERRORS_RECORD]!r}")
            errors = values[ERRORS_RECORD] == "1"
            values = {
                p["name"]: values[p["name"]] if p["name"] in lists else deserialize_output(p, values[p["name"]])
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
