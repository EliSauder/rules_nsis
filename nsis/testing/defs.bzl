"""Describe NSIS symbols and build standalone API test harnesses."""

load("//nsis/private:transitions.bzl", "windows_source_transition")

NsisSymbolInfo = provider(
    doc = "An NSIS entry point description.",
    fields = {"description": "Generated JSON description file."},
)

def _symbol_impl(ctx):
    parameters = []
    names = []
    for parameter in ctx.attr.parameters:
        parts = parameter.split(":")
        if len(parts) not in [2, 3] or parts[0] not in ["in", "out", "inout"] or not parts[1]:
            fail("parameters must use 'direction:name[:type]': " + parameter)
        typ = parts[2] if len(parts) == 3 else "string"
        if typ not in ["string", "int", "bool"]:
            fail("parameter type must be string, int, or bool: " + parameter)
        if parts[1] in names:
            fail("duplicate parameter name: " + parts[1])
        names.append(parts[1])
        parameters.append({"name": parts[1], "direction": parts[0], "type": typ})
    description = {
        "symbol": ctx.attr.symbol,
        "kind": ctx.attr.kind,
        "context": ctx.attr.context,
        "parameters": parameters,
        "defines": ctx.attr.defines,
    }
    if ctx.attr.invocation:
        description["invocation"] = ctx.attr.invocation
    output = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(output, json.encode(description))
    return [
        DefaultInfo(files = depset([output])),
        NsisSymbolInfo(description = output),
    ]

nsis_symbol = rule(
    doc = """Describe an NSIS symbol without maintaining a JSON file.

Parameters use direction:name[:type]. The Python runner validates and converts
string (default), signed 32-bit int, and bool values; booleans use 1/0 in NSIS.
The default output is the generated JSON description consumed by Harness.
""",
    implementation = _symbol_impl,
    attrs = {
        "symbol": attr.string(mandatory = True),
        "kind": attr.string(mandatory = True, values = ["macro", "definition", "function"]),
        "context": attr.string(default = "installer", values = ["installer", "uninstaller"]),
        "parameters": attr.string_list(
            doc = "Ordered 'direction:name[:type]' operands; type is string (default), int, or bool.",
        ),
        "invocation": attr.string(
            default = "",
            values = ["", "call", "value"],
            doc = "For definitions: callable shorthand (default) or constant value.",
        ),
        "defines": attr.string_dict(),
    },
)

def _harness_impl(ctx):
    description = (
        ctx.attr.description[NsisSymbolInfo].description
        if NsisSymbolInfo in ctx.attr.description
        else ctx.file.description
    )
    toolchain = ctx.toolchains["//nsis/toolchain:toolchain_type"].nsis
    script = ctx.actions.declare_file(ctx.label.name + ".nsi")
    binary = ctx.actions.declare_file(ctx.label.name + ".exe")
    args = ctx.actions.args()
    args.add("--spec", description)
    args.add("--source", ctx.file.src)
    args.add("--output", script)
    args.add("--include-dir", ctx.file._includes.path)
    for directory in depset([f.dirname for f in ctx.files.includes]).to_list():
        args.add("--include-dir", directory)
    ctx.actions.run(
        executable = ctx.executable._generator,
        arguments = [args],
        inputs = [description, ctx.file.src] + ctx.files.includes,
        outputs = [script],
        mnemonic = "GenerateNsisHarness",
    )
    flags = ctx.actions.args()
    prefix = "/" if toolchain.args_style == "slash" else "-"
    flags.add_all([prefix + "V2", prefix + "WX", prefix + "NOCD"])
    flags.add(prefix + "DOUTFILE=" + binary.path)
    flags.add(script)
    env = {
        "NSISDIR": toolchain.nsis_dir.files.to_list()[0].path,
        "LANG": "en_US.UTF-8",
        "LC_ALL": "en_US.UTF-8",
    }
    if toolchain.path_style == "windows":
        env["COMSPEC"] = "cmd.exe"
    ctx.actions.run(
        executable = toolchain.makensis,
        arguments = [flags],
        inputs = depset(
            [script, ctx.file.src, ctx.file._includes] + ctx.files.includes,
            transitive = [toolchain.nsis_dir.files, toolchain.nsis_files],
        ),
        tools = [toolchain.makensis],
        outputs = [binary],
        env = env,
        mnemonic = "CompileNsisHarness",
    )
    return [DefaultInfo(
        files = depset([binary]),
        executable = binary,
        runfiles = ctx.runfiles(files = [description]),
    )]

nsis_test_harness = rule(
    doc = "Compile an NSH include using an nsis_symbol target or JSON description.",
    implementation = _harness_impl,
    executable = True,
    cfg = windows_source_transition,
    toolchains = ["//nsis/toolchain:toolchain_type"],
    attrs = {
        "src": attr.label(mandatory = True, allow_single_file = [".nsh"]),
        "description": attr.label(
            mandatory = True,
            allow_single_file = [".json"],
            doc = "An nsis_symbol target, or a standalone JSON description file.",
        ),
        "includes": attr.label_list(allow_files = [".nsh"]),
        "arch": attr.string(default = "x86_64", values = ["x86_64", "x86_32", "arm64"]),
        "_generator": attr.label(
            default = Label("//nsis/testing:generate"),
            executable = True,
            cfg = "exec",
        ),
        "_includes": attr.label(
            default = Label("//nsis/private/includes:includes_dir"),
            allow_single_file = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = Label("@bazel_tools//tools/allowlists/function_transition_allowlist"),
        ),
    },
)
