# NSIS API test harnesses

Unit-test individual NSIS macros, definitions and functions. Describe one entry
point with `nsis_symbol`, build it into a standalone executable with
`nsis_test_harness`, and drive it from a Python test with typed inputs and
outputs. Every call automatically checks that the API preserves all 20 NSIS
registers, leaves the stack balanced, and reports the NSIS error flag.

Harnesses test one API at a time. To test a complete installer built by
`nsis_installer`, use the separate `nsis_installer_test` rule instead.

## Quick start

`BUILD.bazel`:

```starlark
load("@rules_nsis//nsis/testing:defs.bzl", "nsis_symbol", "nsis_test_harness")

nsis_symbol(
    name = "echo_symbol",
    symbol = "Echo",
    kind = "macro",
    parameters = ["in:text:string", "out:result:string"],
)

nsis_test_harness(
    name = "echo",
    src = "example.nsh",
    description = ":echo_symbol",
    includes = [],  # Additional include files needed by example.nsh.
    testonly = True,
)
```

`nsis_symbol` produces a JSON file as its default output, so Python tests can
resolve `$(rlocationpath :echo_symbol)` and pass that path to `Harness`. Add the
symbol target to the Python test's `data` along with the harness binary.
Symbols can be reused by multiple harness targets.

A minimal Python test:

```python
from nsis.testing import Harness

with Harness(binary_path, description_path, directory=test_tmpdir) as api:
    result = api.run(text="hello world")
    result.assert_outputs(result="hello world")
    assert result.returncode == 0
    assert result.stderr == ""
```

## Declaring symbols

`kind` is `macro` (`!insertmacro`), `definition` (`${...}`), `function`
(`Call`), or `condition` (a LogicLib test, see below). `parameters` is an
ordered list of `direction:name[:type]` strings, where direction is `in`,
`out`, `inout`, or `const`. Types are `string` (default), `int`, and `bool`.
Declare the actual symbol, including `un.` when appropriate.

Macros and callable definitions receive input values and output variable
operands in that order. For constant definitions, set `invocation = "value"`
and declare exactly one output. Definitions otherwise default to callable
shorthand expansion, including output-only helpers. For functions, inputs are
pushed in reverse declaration order (the first input is on top), and outputs
are popped in declaration order (the first output must be on top).
Stack functions use separate input and output parameters.

`context` defaults to `installer`. For `uninstaller`, the executable first
creates an uninstaller; the Python runner invokes it directly and waits for its
exit. Optional `defines` maps preprocessor names to string values defined before
including the source. Harnesses run at user execution level; they do not elevate.

### Compile-time constants

A `const:name` parameter is compiled into the harness instead of being passed
at run time. Give its NSIS operand text in `constants`; it is inserted verbatim
in its declared position. Use it for values the command line cannot carry
(quotes, characters such as `${U+00AD}`) or for APIs that only accept literals:

```starlark
nsis_symbol(
    name = "trim_quoted_symbol",
    symbol = "TrimQuotes",
    kind = "macro",
    parameters = ["const:value", "out:result"],
    constants = {"value": '"$\\"quoted$\\""'},
)
```

Constants are untyped single-line strings, and `run()` does not accept them.

### Conditions

`kind = "condition"` tests a LogicLib condition and reports whether it held
through exactly one `out:name:bool` parameter. By default (`invocation =
"operand"`) the symbol is used as an operator: no inputs give `${If} ${Sym}`,
one gives `${If} ${Sym} a`, and two give `${If} a ${Sym} b`. For definitions
that expand to the `${If}` keyword themselves (used as `${IfAdmin}` rather than
`${If} ${IfAdmin}`), set `invocation = "statement"`; inputs follow the symbol.

```starlark
nsis_symbol(
    name = "is_even_symbol",
    symbol = "IsEven",
    kind = "condition",
    parameters = ["in:value:int", "out:even:bool"],
)
```

## Parameter types

Append `:int` or `:bool` to a parameter to give it a Python type:

```starlark
nsis_symbol(
    name = "typed_symbol",
    symbol = "Typed",
    kind = "macro",
    parameters = ["inout:number:int", "inout:enabled:bool"],
)
```

| Declared type | Python input/output | NSIS wire value |
|---|---|---|
| `string` | `str` | Unchanged string |
| `int` | `int`, from -2147483648 through 2147483647 | Decimal string, such as `-42` |
| `bool` | `bool` | Exactly `1` for `True` or `0` for `False` |

Python inputs must match the declared types. Returned values are converted to
the corresponding Python types, including inout parameters. Invalid input
types/ranges and malformed returned values raise `ValueError` identifying the
parameter. Integer outputs must be decimal; hexadecimal and surrounding
whitespace are rejected. Boolean outputs must be exactly `0` or `1`, not
`true`/`false`. Python's `bool` is not accepted as an `int`, and
`assert_outputs` distinguishes them. `in:text` remains equivalent to
`in:text:string` for backward compatibility.

Types describe the Python boundary; NSIS still receives and returns strings.
The generated executable does not independently enforce types when invoked
directly from a shell. The Python runner validates inputs before execution and
converts outputs after reading the result file.

Using the `Typed` harness from Python:

```python
with Harness(typed_binary_path, typed_description_path, directory=test_tmpdir) as api:
    result = api.run(number=41, enabled=False)
    result.assert_outputs(number=42, enabled=True)
    assert type(result.outputs["number"]) is int
    assert type(result.outputs["enabled"]) is bool
```


## Harness options

`nsis_test_harness` also accepts:

- `defines`: preprocessor values defined before the source is included, in
  addition to the symbol's `defines`. Defining the same name in both is an error.
- `on_init`: NSIS lines run in `.onInit` (`un.onInit` for uninstaller symbols)
  before any argument is read, for example to establish state such as a product
  code that the API reads.

```starlark
nsis_test_harness(
    name = "product_code",
    src = "//nsis/private/includes:Product.nsh",
    description = ":product_code_symbol",
    defines = {"TESTABLE_INSTALLER": ""},
    on_init = ['${SetProductCode} "aabbccdd-eeff-0011-2233-445566778899"'],
    testonly = True,
)
```

### Compile-only checks

`nsis_compile_test` builds a harness around a source without invoking any
symbol, then passes if it compiled. Use it to check that an include compiles on
its own, under particular `defines`:

```starlark
load("@rules_nsis//nsis/testing:defs.bzl", "nsis_compile_test")

nsis_compile_test(
    name = "example_compile_test",
    src = "example.nsh",
    defines = {"TESTABLE_INSTALLER": ""},
)
```

The generated script always includes `FileFunc.nsh` and `LogicLib.nsh`, so a
missing include of either is not detected.

## Running an API

`run()` requires exactly the declared input/inout parameters, with their declared
Python types. String outputs preserve whitespace, quotes, newlines and Unicode.
String inputs currently cannot contain literal quotes, newlines or NUL because the
NSIS command-line parser cannot round-trip them reliably. Characters that
Windows string comparison ignores (for example the soft hyphen U+00AD) also
truncate the value, because `GetOptions` treats them as the end of the string;
embed such characters in an adapter macro (for example `${U+00AD}`) instead.
NSIS's compiled string length limit still applies. Use file inputs for larger or arbitrary data.
`expected_exitcode=N` supports failure tests. A zero exit without an output
record is an error, including an API that silently calls `Abort` or `Quit`.

`Result.outputs` is a dictionary of `str`, `int`, or `bool` values according to
the declaration. `assert_outputs` checks both values and exact Python types;
expecting `1` for a declared boolean returned as `True` fails.

Each harness instance owns a unique temporary directory, also used as the
process working directory. Files remain available for inspection until context
exit. Use normal Python libraries (`pathlib`, `winreg`, etc.) for assertions;
pass unique file paths and registry keys as inputs and clean up external state
in `finally` blocks. The runner does not redirect or virtualize registry access.
Independent Bazel test targets can run in parallel.

`Result.stdout` and `Result.stderr` capture inherited process pipes, decoded as
UTF-8 with replacement for invalid bytes. APIs must actually write to those
handles; `DetailPrint` is UI output, not stdout. Console-attachment-only loggers
may need to support inherited handles to be observable. The logging example
demonstrates writing to both handles without a console.


## Built-in checks

### Registers

Every generated harness validates register preservation automatically. It creates
20 fresh random GUID sentinels at runtime using `CoCreateGuid`, fills `$0`–`$9`
and `$R0`–`$R9` immediately before invoking the API, and snapshots and compares
them case-sensitively immediately after it returns. Argument parsing, random
generation and output serialization run outside that boundary. Output arguments
use dedicated named variables, so returning values does not mask register
corruption. Any changed register fails the test, with each register's expected
and actual values in the Python assertion. This applies to installer and
uninstaller calls. APIs that terminate the process cannot reach the post-check;
their exit/output behavior is still checked by the runner.

### Stack balance

The harness also verifies that the API leaves the NSIS stack balanced. It pushes
a 21st random GUID sentinel below the API's inputs; after the call (and after
popping a function's declared outputs) the next pop must return exactly that
sentinel. Values left behind or an extra pop both fail the test with an
`AssertionError` naming the expected and actual top of the stack (or reporting
that the stack was empty).

### Error flag

The NSIS error flag is cleared immediately before the invocation and captured
immediately after it, before outputs are popped. `Result.errors` reports it as
`True`/`False`. By default it is not asserted; pass `expect_errors=True` or
`expect_errors=False` to `run()` to require the flag to be set or clear:

```python
api.run(text="not hex", expect_errors=True)
result = api.run(text="0A")
assert result.errors is False
```


## Example: testing installer behavior with `py_test`

A complete Bazel and Python setup for a macro that creates a file and writes a
registry value. This example also demonstrates
typed inout/output values. The fixture preserves its scratch register; the
harness independently checks all 20 NSIS registers around the API invocation.

`BUILD.bazel`:

```starlark
load("@rules_python//python:py_test.bzl", "py_test")
load("@rules_nsis//nsis/testing:defs.bzl", "nsis_symbol", "nsis_test_harness")

nsis_symbol(
    name = "installer_behavior_symbol",
    symbol = "CreateAndRegister",
    kind = "macro",
    parameters = [
        "in:path",
        "in:key",
        "in:text",
        "inout:count:int",
        "inout:enabled:bool",
        "out:result",
    ],
    testonly = True,
)

nsis_test_harness(
    name = "installer_behavior_harness",
    src = "installer_behavior.nsh",
    description = ":installer_behavior_symbol",
    testonly = True,
)

py_test(
    name = "installer_behavior_test",
    srcs = ["installer_behavior_test.py"],
    main = "installer_behavior_test.py",
    args = [
        "$(rlocationpath :installer_behavior_harness)",
        "$(rlocationpath :installer_behavior_symbol)",
    ],
    data = [":installer_behavior_harness", ":installer_behavior_symbol"],
    deps = ["@rules_nsis//nsis/testing", "@rules_python//python/runfiles"],
    target_compatible_with = ["@platforms//os:windows"],
)
```

`installer_behavior.nsh`:

```nsis
!macro CreateAndRegister PATH KEY TEXT COUNT ENABLED RESULT
    Push $0
    FileOpen $0 "${PATH}" w
    FileWrite $0 "${TEXT}"
    FileClose $0
    WriteRegStr HKCU "Software\RulesNsisExample\${KEY}" "Value" "${TEXT}"
    IntOp ${COUNT} ${COUNT} + 1
    IntOp ${ENABLED} ${ENABLED} ^ 1
    StrCpy ${RESULT} "${PATH}"
    Pop $0
!macroend
```

`installer_behavior_test.py`:

```python
import os
import sys
import uuid

import winreg
from python.runfiles import Runfiles
from nsis.testing import Harness

binary, description = sys.argv[1:]
runfiles = Runfiles.Create()
key = uuid.uuid4().hex
registry_path = "Software\\RulesNsisExample\\" + key
with Harness(
    runfiles.Rlocation(binary),
    runfiles.Rlocation(description),
    directory=os.environ["TEST_TMPDIR"],
) as api:
    output_path = api.directory / "installer output.txt"
    try:
        result = api.run(
            path=str(output_path),
            key=key,
            text="installed by test",
            count=41,
            enabled=False,
        )
        result.assert_outputs(count=42, enabled=True, result=str(output_path))
        assert type(result.outputs["count"]) is int
        assert type(result.outputs["enabled"]) is bool
        assert output_path.read_text(encoding="utf-8") == "installed by test"
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, registry_path) as handle:
            assert winreg.QueryValueEx(handle, "Value") == ("installed by test", winreg.REG_SZ)
    finally:
        try:
            winreg.DeleteKey(winreg.HKEY_CURRENT_USER, registry_path)
        except FileNotFoundError:
            pass
```

Because this example writes to disk and the registry rather than stdout/stderr,
it asserts those side effects directly. Tests for logging APIs can assert
`result.stdout` and `result.stderr` when the API writes to the inherited process
handles.


## Standalone JSON descriptions

`nsis_symbol` generates the JSON description, so no handwritten JSON is needed.
Standalone JSON files are still accepted by `nsis_test_harness.description` and
the generator CLI. The equivalent description for the Echo example is:

```json
{
  "symbol": "Echo",
  "kind": "macro",
  "parameters": [
    {"name": "text", "direction": "in", "type": "string"},
    {"name": "result", "direction": "out", "type": "string"}
  ]
}
```

For typed standalone descriptions, use `"type": "int"` or `"type": "bool"`.
Omitting `type` defaults to `string`, just as in the Bazel rule.

## Generated executable protocol

The executable accepts `/name=value` for each input/inout and `/output=absolute-path`
for its output file. Quote the value, not the entire option:
`/text="hello world"`. Uninstaller bootstrap
accepts `/harness_uninstaller=absolute-path`. The Python runner handles both.
For typed parameters, use decimal integers and `1`/`0` booleans, for example
`/number=41 /enabled=0`. Output records always contain strings on disk; the
Python runner uses the symbol description to convert them to typed values.
Missing arguments exit with 64; changed registers exit with 65; an unbalanced
stack exits with 66 (65 takes precedence when both occur); random sentinel
generation failures exit with 70; output creation/write errors exit with 74.
Otherwise, the API's exit code is preserved.

The output file is UTF-16LE without a BOM: `NSIS-HARNESS-2\n` followed by
`name:length:value` records in declared output order, then a final
`harness.errors` record (`1` when the error flag was set after the call, else
`0`). Length is in UTF-16 code
units. This avoids JSON/INI escaping and trimming in NSIS. The runner validates
the complete record sequence and exposes a Python dictionary.
On register corruption, a sibling `.registers` file uses the same encoding for
all before/after snapshots; the runner reports every changed register.
On stack imbalance, a sibling `.stack` file holds `expected`, `actual` and
`underflow` records describing the sentinel check.


## Examples and checks

```sh
bazel test //nsis/testing:framework_test //nsis/testing/examples:description_test
bazel build //nsis/testing/examples:binaries
# Windows:
bazel test //nsis/testing/examples:all
```

Examples cover macros, shorthand and constant definitions, functions (including
multi-input/output stack order), operand and statement conditions, compile-time
constants, uninstallers, harness `defines` and `on_init`, compile-only checks,
typed integer/boolean inout parameters, filesystem and registry
assertions, and captured stdout/stderr. Each example has its own Bazel test
target. See [`examples/BUILD.bazel`](examples/BUILD.bazel) for symbol declarations
and [`examples/example_test.py`](examples/example_test.py) for Python usage.
Two negative examples intentionally corrupt `$0` and `$R9` and assert that the
framework detects both changes, in installer and uninstaller contexts.

## This repository's include API suite

`//tests/includes:tests` uses this framework to test every public macro,
definition and function in `nsis/private/includes`, with one generated harness
per entry point (and an `un.` variant where applicable) so cases run
independently and in parallel. Each include has its own files in
`tests/includes`:

- `<api>.bzl` declares its cases with `include_api_case` (from `defs.bzl`).
- `<api>_test.py` holds the cases' assertions.
- `<api>_adapters.nsh`, where needed, adds `Harness*` macros for cases a direct
  symbol call cannot express.

Every include also has compile-only tests, with and without
`TESTABLE_INSTALLER`. `service_lifecycle` drives a real stub service
(`service_stub.c`) through every `Sc.nsh` macro; it needs an elevated test run
and skips otherwise.

```sh
bazel build //tests/includes:binaries     # cross-compile on any host
bazel test //tests/includes:tests         # Windows only
bazel test //tests/includes:contract_test # any host
```

The contract test runs every case's dispatch against its generated symbol
without executing Windows binaries, validating input names/types and typed
output expectations.

Numeric and boolean APIs use typed symbols. Service and ACL command results stay
strings because `nsExec` can return `error` or `timeout`, not just decimal exit
codes. Hex conversion emits four bits per hexadecimal digit (`f` becomes
`1111`); invalid digits return an empty string and set the error flag.
