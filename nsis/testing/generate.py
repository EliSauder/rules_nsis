"""Generate a standalone NSIS harness from an API description."""

import argparse
import json
import re
from pathlib import Path

REGISTERS = tuple([str(i) for i in range(10)] + [f"R{i}" for i in range(10)])
HEADER = "NSIS-HARNESS-2"
ERRORS_RECORD = "harness.errors"
STACK_RECORDS = ("expected", "actual", "underflow")
KINDS = ("macro", "definition", "function", "condition")
INVOCATIONS = {"definition": ("call", "value"), "condition": ("operand", "statement")}


def inputs(spec):
    """Parameters the caller supplies at run time, in declaration order."""
    return [p for p in spec.get("parameters", []) if p["direction"] in ("in", "inout")]


def outputs(spec):
    """Parameters the harness reports back, in declaration order."""
    return [p for p in spec.get("parameters", []) if p["direction"] in ("out", "inout")]


def validate(spec):
    if not isinstance(spec, dict):
        raise ValueError("API description must be an object")
    unknown = spec.keys() - {
        "symbol", "kind", "context", "parameters", "defines", "invocation",
    }
    if unknown:
        raise ValueError(f"Unknown description fields: {sorted(unknown)}")
    if spec.get("kind") not in KINDS:
        raise ValueError("kind must be macro, definition, function, or condition")
    if "invocation" in spec and spec["invocation"] not in INVOCATIONS.get(spec["kind"], ()):
        raise ValueError(
            "invocation must be call or value for definitions, "
            "or operand or statement for conditions"
        )
    if spec.get("context", "installer") not in ("installer", "uninstaller"):
        raise ValueError("context must be installer or uninstaller")
    if not isinstance(spec.get("symbol"), str) or not re.fullmatch(
        r"[A-Za-z_][A-Za-z0-9_.]*", spec["symbol"]
    ):
        raise ValueError("symbol must be an NSIS identifier")
    parameters = spec.get("parameters", [])
    if not isinstance(parameters, list):
        raise ValueError("parameters must be an array")
    names = set()
    for parameter in parameters:
        if (
            not isinstance(parameter, dict)
            or not {"name", "direction"} <= parameter.keys()
            or parameter.keys() - {"name", "direction", "type", "value"}
        ):
            raise ValueError("Each parameter requires name and direction, with optional type")
        if parameter.get("type", "string") not in ("string", "int", "bool", "list"):
            raise ValueError("Parameter type must be string, int, bool, or list")
        name = parameter["name"]
        if not isinstance(name, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", name):
            raise ValueError("Parameter names must match [a-z][a-z0-9_]*")
        if name in names or name in ("output", "harness_uninstaller", "expected_exitcode", "self", "testid", "test_id"):
            raise ValueError(f"Duplicate or reserved parameter name: {name}")
        names.add(name)
        if parameter["direction"] not in ("in", "out", "inout", "const"):
            raise ValueError(f"Invalid direction for {name}")
        if (parameter["direction"] == "const") != ("value" in parameter):
            raise ValueError(f"Only const parameters, and every const parameter, need a value: {name}")
        if parameter["direction"] == "const" and (
            not isinstance(parameter["value"], str) or "type" in parameter
            or any(c in parameter["value"] for c in "\r\n")
        ):
            raise ValueError(f"const {name} needs a single-line string value and no type")
        if parameter.get("type") == "list" and (
            parameter["direction"] == "const" or spec["kind"] == "function"
            or spec.get("invocation") == "value" or spec["kind"] == "condition"
        ):
            raise ValueError(f"list parameter {name} needs a macro or definition, and not const")
        if spec["kind"] == "function" and parameter["direction"] == "inout":
            raise ValueError("Stack functions use separate in and out parameters")
    if spec.get("invocation") == "value" and (
        len(parameters) != 1 or parameters[0]["direction"] != "out"
    ):
        raise ValueError("A value definition requires exactly one out parameter")
    if spec["kind"] == "condition":
        results = [p for p in parameters if p["direction"] != "in" and p["direction"] != "const"]
        operands = [p for p in parameters if p["direction"] in ("in", "const")]
        if len(results) != 1 or results[0]["direction"] != "out" or results[0].get("type") != "bool":
            raise ValueError("A condition requires exactly one out bool parameter")
        if spec.get("invocation", "operand") == "operand" and len(operands) > 2:
            raise ValueError("An operand condition takes at most two operands")
    defines = spec.get("defines", {})
    if not isinstance(defines, dict):
        raise ValueError("defines must be an object")
    for name, value in defines.items():
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name) or not isinstance(value, str):
            raise ValueError("defines must map identifiers to string values")
    return spec


def literal(value):
    return '"' + value.replace("$", "$$").replace('"', '$\\"').replace(
        "\r", "$\\r"
    ).replace("\n", "$\\n") + '"'


def write_records(path, records):
    """Records are (name, variable), or (name, array, "list") for an nsArray.

    A list is written as "name:count:" followed by "length:item" per item, so
    items need no escaping and the list has no size limit.
    """
    lines = [
        "ClearErrors",
        f'FileOpen $_harness_file "{path}" w',
        "IfErrors harness_output_error",
        f'FileWriteUTF16LE $_harness_file "{HEADER}$\\n"',
        "IfErrors harness_output_error",
    ]
    for number, record in enumerate(records):
        if len(record) == 3:
            name, array, _ = record
            label = str(number)
            lines += [
                "ClearErrors",
                f'nsArray::Length "{array}"',
                f"IfErrors list_missing_{label}",
                "Pop $_harness_count",
                f"Goto list_counted_{label}",
                f"list_missing_{label}:",
                "StrCpy $_harness_count 0",
                f"list_counted_{label}:",
                f'FileWriteUTF16LE $_harness_file "{name}:$_harness_count:"',
                "IfErrors harness_output_error",
                "StrCpy $_harness_index 0",
                f"list_item_{label}:",
                f"IntCmp $_harness_index $_harness_count list_done_{label} 0 list_done_{label}",
                f'nsArray::Get "{array}" /at=$_harness_index',
                "Pop $_harness_item",
                "Pop $_harness_item",
                "StrLen $_harness_length $_harness_item",
                'FileWriteUTF16LE $_harness_file "$_harness_length:"',
                "IfErrors harness_output_error",
                'FileWriteUTF16LE $_harness_file "$_harness_item"',
                "IfErrors harness_output_error",
                "IntOp $_harness_index $_harness_index + 1",
                f"Goto list_item_{label}",
                f"list_done_{label}:",
            ]
            continue
        name, variable = record
        lines += [
            f"StrLen $_harness_length {variable}",
            f'FileWriteUTF16LE $_harness_file "{name}:$_harness_length:"',
            "IfErrors harness_output_error",
            f'FileWriteUTF16LE $_harness_file "{variable}"',
            "IfErrors harness_output_error",
        ]
    return lines + ["FileClose $_harness_file"]


def _array_name(parameter):
    return f'_harness_list_{parameter["name"]}'


def _function_lines(prefix, decode):
    """The function that unescapes inputs (%XX, %uXXXX) read from the input file."""
    lines = []
    if decode:
        lines += [
            f"Function {prefix}_harness_decode",
            "Exch $0",
            "Push $1", "Push $2", "Push $3", "Push $4", "Push $5", "Push $6",
            'StrCpy $1 ""', "StrCpy $2 0", "StrLen $3 $0",
            "decode_loop:",
            "IntCmp $2 $3 decode_done 0 decode_done",
            "StrCpy $4 $0 1 $2",
            'StrCmp $4 "%" 0 decode_plain',
            "IntOp $6 $2 + 1", "StrCpy $5 $0 1 $6",
            'StrCmp $5 "u" 0 decode_byte',
            "IntOp $6 $2 + 2", "StrCpy $5 $0 4 $6",
            'IntOp $5 "0x$5" + 0', 'IntFmt $4 "%c" $5',
            "IntOp $2 $2 + 5", "Goto decode_plain",
            "decode_byte:",
            "StrCpy $5 $0 2 $6",
            'IntOp $5 "0x$5" + 0', 'IntFmt $4 "%c" $5',
            "IntOp $2 $2 + 2",
            "decode_plain:",
            'StrCpy $1 "$1$4"', "IntOp $2 $2 + 1", "Goto decode_loop",
            "decode_done:",
            "StrCpy $0 $1",
            "Pop $6", "Pop $5", "Pop $4", "Pop $3", "Pop $2", "Pop $1",
            "Exch $0",
            "FunctionEnd",
        ]
    return lines


def _read_input(prefix, number, parameter):
    """Reads one input from the input file: a scalar's "name=value" line, or a
    list's "name=item" lines, one per item. Values are percent-escaped, so a
    line never holds CR or LF."""
    name = parameter["name"]
    typ = parameter.get("type", "string")
    marker = f"{name}="
    n = number
    lines = ["FileSeek $_harness_in 0 SET"]
    if typ == "list":
        array = _array_name(parameter)
        lines += [
            f'nsArray::Set "{array}" /key=0 ""',
            f'nsArray::Clear "{array}"',
            "StrCpy $_harness_index 0",
        ]
    else:
        lines += ['StrCpy $_harness_found "0"']
    lines += [
        f"input_scan_{n}:",
        "ClearErrors",
        "FileRead $_harness_in $_harness_line",
        f"IfErrors input_end_{n}",
        f"input_chomp_{n}:",
        "StrCpy $_harness_c $_harness_line 1 -1",
        f'StrCmp $_harness_c "$\\n" input_strip_{n}',
        f'StrCmp $_harness_c "$\\r" input_strip_{n}',
        f"Goto input_chomped_{n}",
        f"input_strip_{n}:",
        "StrCpy $_harness_line $_harness_line -1",
        f"Goto input_chomp_{n}",
        f"input_chomped_{n}:",
        f"StrCpy $_harness_c $_harness_line {len(marker)}",
        f'StrCmpS $_harness_c "{marker}" 0 input_scan_{n}',
        f'StrCpy $_harness_line $_harness_line "" {len(marker)}',
    ]
    if typ == "list":
        lines += [
            "Push $_harness_line", f"Call {prefix}_harness_decode", "Pop $_harness_line",
            f'nsArray::Set "{array}" /key=$_harness_index $_harness_line',
            "IntOp $_harness_index $_harness_index + 1",
            f"Goto input_scan_{n}",
            f"input_end_{n}:",
        ]
        return lines
    if typ == "string":
        lines += ["Push $_harness_line", f"Call {prefix}_harness_decode", "Pop $_harness_line"]
    lines += [
        f"StrCpy $_harness_param_{name} $_harness_line",
        'StrCpy $_harness_found "1"',
        f"input_end_{n}:",
        f'StrCmp $_harness_found "1" input_found_{n}',
        "Goto harness_bad_arguments",
        f"input_found_{n}:",
    ]
    return lines


def _operand(parameter):
    if parameter["direction"] == "const":
        return parameter["value"]
    if parameter.get("type") == "list":
        # The API receives the name of an nsArray the harness fills or reads.
        return f'"{_array_name(parameter)}"'
    # Macro output operands must be variables, not quoted literal values.
    variable = f'$_harness_param_{parameter["name"]}'
    return f'"{variable}"' if parameter["direction"] == "in" else variable


def _invocation(spec):
    symbol = spec["symbol"]
    parameters = spec.get("parameters", [])
    if spec["kind"] == "function":
        pushed = [p for p in parameters if p["direction"] in ("in", "const")]
        return [f"Push {_operand(p)}" for p in reversed(pushed)] + [f"Call {symbol}"]
    if spec.get("invocation") == "value":
        return [f'StrCpy $_harness_param_{outputs(spec)[0]["name"]} "${{{symbol}}}"']
    if spec["kind"] == "condition":
        result = f'$_harness_param_{outputs(spec)[0]["name"]}'
        operands = [_operand(p) for p in parameters if p["direction"] in ("in", "const")]
        if spec.get("invocation") == "statement":
            opening = " ".join([f"${{{symbol}}}", *operands])
        elif len(operands) == 2:
            opening = f"${{If}} {operands[0]} ${{{symbol}}} {operands[1]}"
        else:
            opening = " ".join(["${If}", f"${{{symbol}}}", *operands])
        return [opening, f'StrCpy {result} "1"', "${Else}", f'StrCpy {result} "0"', "${EndIf}"]
    arguments = " ".join(_operand(p) for p in parameters)
    command = f"!insertmacro {symbol}" if spec["kind"] == "macro" else f"${{{symbol}}}"
    return [f"{command} {arguments}".rstrip()]


def _defines(defines):
    lines = []
    for name, value in defines.items():
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            raise ValueError(f"Invalid define name: {name}")
        lines.append(f"!define {name} {literal(value)}")
    return lines


def _on_init(context, on_init):
    name = "un.onInit" if context == "uninstaller" else ".onInit"
    # Includes that use the test id (Testing.nsh) get one for free: every run
    # is passed a unique /TESTID=, so library registry writes never collide.
    return [
        f"Function {name}",
        "!ifdef __INCLUDE_TESTING",
        "${TestIdInit}",
        "!endif",
        *on_init,
        "FunctionEnd",
    ]


def generate(spec, source, include_dirs=(), defines=None, on_init=(), plugin_lines=()):
    """Generates a harness script; spec=None only checks that source compiles."""
    defines = dict(defines or {})
    if spec is not None:
        validate(spec)
        overlap = defines.keys() & spec.get("defines", {}).keys()
        if overlap:
            raise ValueError(f"Defines set by both the harness and description: {sorted(overlap)}")
        defines.update(spec.get("defines", {}))
    lines = [
        "Unicode true",
        "!pragma warning disable 6001",
        "!pragma warning disable 6010",
        "!pragma warning disable 6020",
        "RequestExecutionLevel user",
        "SilentInstall silent",
        "SilentUnInstall silent",
        'OutFile "${OUTFILE}"',
        '!include "FileFunc.nsh"',
        '!include "LogicLib.nsh"',
    ]
    for directory in include_dirs:
        lines.append(f"!addincludedir {literal(str(directory))}")
    lines += plugin_lines
    lines += _defines(defines)
    # Include by basename: makensis also searches relative to the current script.
    lines += [
        f"!addincludedir {literal(str(Path(source).parent))}",
        f"!include {literal(Path(source).name)}",
    ]
    if spec is None:
        if on_init:
            raise ValueError("on_init requires a description")
        return "\n".join(lines + ["Section", "SectionEnd"]) + "\n"
    context = spec.get("context", "installer")
    lines += _on_init(context, on_init)
    parameters = spec.get("parameters", [])
    prefix = "un." if context == "uninstaller" else ""
    list_inputs = [p for p in inputs(spec) if p.get("type") == "list"]
    list_outputs = [p for p in outputs(spec) if p.get("type") == "list"]
    string_inputs = [p for p in inputs(spec) if p.get("type", "string") == "string"]
    lines += _function_lines(
        prefix,
        decode=bool(string_inputs or list_inputs),
    )
    lines += [
        "Var _harness_args",
        "Var _harness_input",
        "Var _harness_in",
        "Var _harness_line",
        "Var _harness_c",
        "Var _harness_found",
        "Var _harness_index",
        "Var _harness_count",
        "Var _harness_item",
        "Var _harness_output",
        "Var _harness_uninstaller",
        "Var _harness_file",
        "Var _harness_length",
        "Var _harness_exitcode",
        "Var _harness_corrupted",
        "Var _harness_errors",
        "Var _harness_stack_sentinel",
        "Var _harness_stack_actual",
        "Var _harness_stack_underflow",
    ]
    for register in REGISTERS:
        lines += [f"Var _harness_before_{register}", f"Var _harness_after_{register}"]
    lines += [f"Var _harness_param_{p['name']}" for p in parameters if p["direction"] != "const"]
    body = [
        "${GetParameters} $_harness_args",
        "ClearErrors",
        '${GetOptions} $_harness_args "/output=" $_harness_output',
        "IfErrors harness_bad_arguments",
        'StrCmp $_harness_output "" harness_bad_arguments',
    ]
    if inputs(spec):
        body += [
            'StrCpy $_harness_input "$_harness_output.inputs"',
            "ClearErrors",
            'FileOpen $_harness_in "$_harness_input" r',
            "IfErrors harness_bad_arguments",
        ]
    for number, parameter in enumerate(inputs(spec)):
        body += _read_input(prefix, number, parameter)
    if inputs(spec):
        body += ["FileClose $_harness_in"]
    for parameter in list_outputs:
        body += [
            f'nsArray::Set "{_array_name(parameter)}" /key=0 ""',
            f'nsArray::Clear "{_array_name(parameter)}"',
        ]
    # An absent output file distinguishes Abort/Quit from a successful call.
    body += [
        'Delete "$_harness_output"',
        'Delete "$_harness_output.registers"',
        'Delete "$_harness_output.stack"',
    ]
    # Generate every sentinel before assigning registers: even the random-value
    # provider must not be able to disturb a register already seeded for the API.
    for register in REGISTERS:
        body += [
            "System::Call 'ole32::CoCreateGuid(g .s) i.r0'",
            f"Pop $_harness_before_{register}",
            'StrCmp $0 "0" 0 harness_random_error',
            f'StrCmp $_harness_before_{register} "" harness_random_error',
        ]
    body += [
        "System::Call 'ole32::CoCreateGuid(g .s) i.r0'",
        "Pop $_harness_stack_sentinel",
        'StrCmp $0 "0" 0 harness_random_error',
        'StrCmp $_harness_stack_sentinel "" harness_random_error',
    ]
    body += [f"StrCpy ${r} $_harness_before_{r}" for r in REGISTERS]
    # The sentinel sits beneath the API's operands; finding it on top afterwards
    # proves the API neither left extra values nor consumed the caller's values.
    body += ["Push $_harness_stack_sentinel", "SetErrorLevel 0", "ClearErrors"]
    body += _invocation(spec)
    # Capture the error flag before any harness instruction can change it.
    body += [
        'StrCpy $_harness_errors "0"',
        "IfErrors 0 +2",
        'StrCpy $_harness_errors "1"',
        "GetErrorLevel $_harness_exitcode",
    ]
    if spec["kind"] == "function":
        body += [f"Pop $_harness_param_{p['name']}" for p in outputs(spec)]
    body += [
        'StrCpy $_harness_stack_underflow "0"',
        "ClearErrors",
        "Pop $_harness_stack_actual",
        "IfErrors 0 +3",
        'StrCpy $_harness_stack_underflow "1"',
        'StrCpy $_harness_stack_actual ""',
    ]
    body += [f"StrCpy $_harness_after_{r} ${r}" for r in REGISTERS]
    body += ['StrCpy $_harness_corrupted "0"']
    for register in REGISTERS:
        body += [
            f"StrCmpS $_harness_after_{register} $_harness_before_{register} +2",
            'StrCpy $_harness_corrupted "1"',
        ]
    body += write_records(
        "$_harness_output",
        [(p["name"], _array_name(p), "list") if p.get("type") == "list"
         else (p["name"], f'$_harness_param_{p["name"]}') for p in outputs(spec)]
        + [(ERRORS_RECORD, "$_harness_errors")],
    )
    body += ['StrCmp $_harness_corrupted "0" harness_check_stack']
    body += write_records(
        "$_harness_output.registers",
        [(f"{when}_{r}", f"$_harness_{when}_{r}")
         for r in REGISTERS for when in ("before", "after")],
    )
    body += [
        "harness_check_stack:",
        'StrCmp $_harness_stack_underflow "1" harness_stack_imbalanced',
        "StrCmpS $_harness_stack_actual $_harness_stack_sentinel harness_stack_balanced",
        "harness_stack_imbalanced:",
    ]
    body += write_records(
        "$_harness_output.stack",
        [("expected", "$_harness_stack_sentinel"),
         ("actual", "$_harness_stack_actual"),
         ("underflow", "$_harness_stack_underflow")],
    )
    body += [
        'StrCmp $_harness_corrupted "1" harness_corrupted',
        "SetErrorLevel 66",
        "Goto harness_done",
        "harness_stack_balanced:",
        'StrCmp $_harness_corrupted "1" harness_corrupted',
        "SetErrorLevel $_harness_exitcode",
        "Goto harness_done",
        "harness_corrupted:",
        "SetErrorLevel 65",
        "Goto harness_done",
        "harness_random_error:",
        "SetErrorLevel 70",
        "Quit",
        "harness_bad_arguments:",
        "SetErrorLevel 64",
        "Quit",
        "harness_output_error:",
        "FileClose $_harness_file",
        "SetErrorLevel 74",
        "Quit",
        "harness_done:",
    ]
    if context == "uninstaller":
        lines += [
            "Section",
            "${GetParameters} $_harness_args",
            "ClearErrors",
            '${GetOptions} $_harness_args "/harness_uninstaller=" $_harness_uninstaller',
            "IfErrors 0 +3",
            "SetErrorLevel 64",
            "Quit",
            'WriteUninstaller "$_harness_uninstaller"',
            "IfErrors 0 +3",
            "SetErrorLevel 74",
            "Quit",
            "SectionEnd",
            'Section "Uninstall"',
            *body,
            "SectionEnd",
        ]
    else:
        lines += ["Section", *body, "SectionEnd"]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path)
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--include-dir", action="append", default=[])
    parser.add_argument("--plugin-line", action="append", default=[], help="NSIS line")
    parser.add_argument("--define", action="append", default=[], help="NAME=VALUE")
    parser.add_argument("--on-init", action="append", default=[], help="NSIS line")
    args = parser.parse_args()
    defines = {}
    for define in args.define:
        name, _, value = define.partition("=")
        defines[name] = value
    spec = json.loads(args.spec.read_text(encoding="utf-8")) if args.spec else None
    args.output.write_text(
        generate(spec, args.source, args.include_dir, defines, args.on_init, args.plugin_line),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
