"""Describe NSIS symbols and build standalone API test harnesses."""

load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//nsis/private:plugins.bzl", "PLUGIN_ATTRS", "plugin_script_lines", "stage_plugins")
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
        if len(parts) not in [2, 3] or parts[0] not in ["in", "out", "inout", "const"] or not parts[1]:
            fail("parameters must use 'direction:name[:type]': " + parameter)
        if parts[1] in names:
            fail("duplicate parameter name: " + parts[1])
        names.append(parts[1])
        if parts[0] == "const":
            if len(parts) == 3:
                fail("const parameters are untyped: " + parameter)
            if parts[1] not in ctx.attr.constants:
                fail("const parameter has no entry in constants: " + parts[1])
            parameters.append({"name": parts[1], "direction": "const", "value": ctx.attr.constants[parts[1]]})
            continue
        typ = parts[2] if len(parts) == 3 else "string"
        if typ not in ["string", "int", "bool"]:
            fail("parameter type must be string, int, or bool: " + parameter)
        parameters.append({"name": parts[1], "direction": parts[0], "type": typ})
    for name in ctx.attr.constants:
        if name not in names:
            fail("constants entry has no const parameter: " + name)
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
A const:name parameter is not supplied at run time: its constants entry is
inserted verbatim as that operand, for values only expressible at compile time.

A condition is a LogicLib test reported as its single out bool parameter. With
the default operand invocation it is used as ${If} ${symbol} [operand] or
${If} operand ${symbol} operand; a statement condition opens the block itself,
as in ${symbol} [operands].

The default output is the generated JSON description consumed by Harness.
""",
    implementation = _symbol_impl,
    attrs = {
        "symbol": attr.string(mandatory = True),
        "kind": attr.string(mandatory = True, values = ["macro", "definition", "function", "condition"]),
        "context": attr.string(default = "installer", values = ["installer", "uninstaller"]),
        "parameters": attr.string_list(
            doc = "Ordered 'direction:name[:type]' operands (in, out, inout, const); type is string (default), int, or bool.",
        ),
        "constants": attr.string_dict(
            doc = "Verbatim NSIS operand text for each const parameter.",
        ),
        "invocation": attr.string(
            default = "",
            values = ["", "call", "value", "operand", "statement"],
            doc = "Definitions: call (default) or value. Conditions: operand (default) or statement.",
        ),
        "defines": attr.string_dict(),
    },
)

def _harness_impl(ctx):
    description = None
    if ctx.attr.description:
        description = (
            ctx.attr.description[NsisSymbolInfo].description
            if NsisSymbolInfo in ctx.attr.description
            else ctx.file.description
        )
    elif ctx.attr.on_init:
        fail("on_init requires a description")
    toolchain = ctx.toolchains["//nsis/toolchain:toolchain_type"].nsis
    script = ctx.actions.declare_file(ctx.label.name + ".nsi")
    binary = ctx.actions.declare_file(ctx.label.name + ".exe")
    args = ctx.actions.args()
    if description:
        args.add("--spec", description)
    args.add("--source", ctx.file.src)
    for name, value in ctx.attr.defines.items():
        args.add("--define=" + name + "=" + value)
    for line in ctx.attr.on_init:
        # One argument, so lines starting with "-" are not parsed as options.
        args.add("--on-init=" + line)
    args.add("--output", script)
    args.add("--include-dir", ctx.file._includes.path)
    for directory in depset([f.dirname for f in ctx.files.includes]).to_list():
        args.add("--include-dir", directory)
    staged = stage_plugins(ctx, [ctx.attr._default_plugins] + ctx.attr.plugins)
    for line in plugin_script_lines(staged, lambda p: p):
        args.add("--plugin-line=" + line)
    ctx.actions.run(
        executable = ctx.executable._generator,
        arguments = [args],
        inputs = ([description] if description else []) + [ctx.file.src] + ctx.files.includes,
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
            transitive = [toolchain.nsis_dir.files, toolchain.nsis_files, staged.files],
        ),
        tools = [toolchain.makensis],
        outputs = [binary],
        env = env,
        mnemonic = "CompileNsisHarness",
    )
    return [DefaultInfo(
        files = depset([binary]),
        executable = binary,
        runfiles = ctx.runfiles(files = [description] if description else []),
    )]

nsis_test_harness = rule(
    doc = """Compile an NSH include using an nsis_symbol target or JSON description.

Without a description the harness only checks that src compiles on its own.
""",
    implementation = _harness_impl,
    executable = True,
    cfg = windows_source_transition,
    toolchains = ["//nsis/toolchain:toolchain_type"],
    attrs = dict(PLUGIN_ATTRS, **{
        "src": attr.label(mandatory = True, allow_single_file = [".nsh"]),
        "description": attr.label(
            allow_single_file = [".json"],
            doc = "An nsis_symbol target, or a standalone JSON description file.",
        ),
        "includes": attr.label_list(allow_files = [".nsh"]),
        "defines": attr.string_dict(
            doc = "Compile-time !defines set before src; may not repeat description defines.",
        ),
        "on_init": attr.string_list(
            doc = "NSIS lines for .onInit, or un.onInit for an uninstaller description.",
        ),
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
    }),
)

def nsis_compile_test(name, src, includes = [], defines = {}, **kwargs):
    """Check that src compiles with only its own !includes.

    The generated script always includes LogicLib.nsh and FileFunc.nsh, so a
    missing include of either cannot be detected.
    """
    nsis_test_harness(
        name = name + "_harness",
        src = src,
        includes = includes,
        defines = defines,
        testonly = True,
    )
    build_test(
        name = name,
        targets = [":" + name + "_harness"],
        **kwargs
    )
