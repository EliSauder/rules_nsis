# NSIS API test harnesses

Write an include, describe one entry point with `nsis_symbol`, and build a
standalone test executable. Bazel generates the JSON description automatically;
no handwritten JSON is needed. These harnesses do not use the installer
end-to-end test rule. Existing include tests are unchanged.

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

`kind` is `macro` (`!insertmacro`), `definition` (`${...}`), or `function`
(`Call`). `parameters` is an ordered list of `direction:name[:type]` strings,
where direction is `in`, `out`, or `inout`. Types are `string` (default),
`int`, and `bool`. For example:

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

Macros and callable definitions receive input values and output variable
operands in that order. For constant definitions, set `invocation = "value"`
and declare exactly one output. Definitions otherwise default to callable
shorthand expansion, including output-only helpers. For functions, inputs are
pushed in reverse declaration order (the first input is on top), and outputs
are popped in declaration order (the first output must be on top).
Stack functions use separate input and output parameters.
Declare the actual symbol, including `un.` when appropriate.

`context` defaults to `installer`. For `uninstaller`, the executable first
creates an uninstaller; the Python runner invokes it directly and waits for its
exit. Optional `defines` maps preprocessor names to string values defined before
including the source. Harnesses run at user execution level; they do not elevate.

Standalone JSON files remain accepted by `description` and the generator CLI.
The equivalent standalone description for the Echo example is:

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

## Python tests

Depend on `@rules_nsis//nsis/testing`, add the binary and symbol to test `data`,
resolve their runfile paths, and use the context manager:

```python
from nsis.testing import Harness

with Harness(binary_path, description_path, directory=test_tmpdir) as api:
    result = api.run(text="hello world")
    result.assert_outputs(result="hello world")
    assert result.returncode == 0
    assert result.stderr == ""
```

For the `Typed` example, resolve the typed harness and symbol paths instead:

```python
with Harness(typed_binary_path, typed_description_path, directory=test_tmpdir) as api:
    result = api.run(number=41, enabled=False)
    result.assert_outputs(number=42, enabled=True)
    assert type(result.outputs["number"]) is int
    assert type(result.outputs["enabled"]) is bool
```

`Result.outputs` is a dictionary of `str`, `int`, or `bool` values according to
the declaration. `assert_outputs` checks both values and exact Python types;
expecting `1` for a declared boolean returned as `True` fails.

Each harness instance owns a unique temporary directory, also used as the
process working directory. Files remain available for inspection until context
exit. Use normal Python libraries (`pathlib`, `winreg`, etc.) for assertions;
pass unique file paths and registry keys as inputs and clean up external state
in `finally` blocks. The runner does not redirect or virtualize registry access.
Independent Bazel test targets can run in parallel.

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

`run()` requires exactly the declared input/inout parameters, with their declared
Python types. String outputs preserve whitespace, quotes, newlines and Unicode.
String inputs currently cannot contain literal quotes, newlines or NUL because the
NSIS command-line parser cannot round-trip them reliably. NSIS's compiled string
length limit still applies. Use file inputs for larger or arbitrary data.
`expected_exitcode=N` supports failure tests. A zero exit without an output
record is an error, including an API that silently calls `Abort` or `Quit`.

`Result.stdout` and `Result.stderr` capture inherited process pipes, decoded as
UTF-8 with replacement for invalid bytes. APIs must actually write to those
handles; `DetailPrint` is UI output, not stdout. Console-attachment-only loggers
may need to support inherited handles to be observable. The logging example
demonstrates writing to both handles without a console.

## Generated executable protocol

The executable accepts `/name=value` for each input/inout and `/output=absolute-path`
for its output file. Quote the value, not the entire option:
`/text="hello world"`. Uninstaller bootstrap
accepts `/harness_uninstaller=absolute-path`. The Python runner handles both.
For typed parameters, use decimal integers and `1`/`0` booleans, for example
`/number=41 /enabled=0`. Output records always contain strings on disk; the
Python runner uses the symbol description to convert them to typed values.
Missing arguments exit with 64; changed registers exit with 65; random sentinel
generation failures exit with 70; output creation/write errors exit with 74.
Otherwise, the API's exit code is preserved.

The output file is UTF-16LE without a BOM: `NSIS-HARNESS-1\n` followed by
`name:length:value` records in declared output order. Length is in UTF-16 code
units. This avoids JSON/INI escaping and trimming in NSIS. The runner validates
the complete record sequence and exposes a Python dictionary.
On register corruption, a sibling `.registers` file uses the same encoding for
all before/after snapshots; the runner reports every changed register.

## Examples and checks

```sh
bazel test //nsis/testing:framework_test //nsis/testing/examples:description_test
bazel build //nsis/testing/examples:binaries
# Windows:
bazel test //nsis/testing/examples:all
```

Examples cover macros, shorthand and constant definitions, functions,
uninstallers, typed integer/boolean inout parameters, filesystem and registry
assertions, and captured stdout/stderr. Each example has its own Bazel test
target. See [`examples/BUILD.bazel`](examples/BUILD.bazel) for symbol declarations
and [`examples/example_test.py`](examples/example_test.py) for Python usage.
Two negative examples intentionally corrupt `$0` and `$R9` and assert that the
framework detects both changes, in installer and uninstaller contexts.
