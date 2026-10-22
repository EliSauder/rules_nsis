"""Build standalone, JSON-described NSIS API harnesses."""

load("//nsis/private:transitions.bzl", "windows_source_transition")

def _harness_impl(ctx):
    toolchain = ctx.toolchains["//nsis/toolchain:toolchain_type"].nsis
    script = ctx.actions.declare_file(ctx.label.name + ".nsi")
    binary = ctx.actions.declare_file(ctx.label.name + ".exe")
    args = ctx.actions.args()
    args.add("--spec", ctx.file.description)
    args.add("--source", ctx.file.src)
    args.add("--output", script)
    args.add("--include-dir", ctx.file._includes.path)
    for directory in depset([f.dirname for f in ctx.files.includes]).to_list():
        args.add("--include-dir", directory)
    ctx.actions.run(
        executable = ctx.executable._generator,
        arguments = [args],
        inputs = [ctx.file.description, ctx.file.src] + ctx.files.includes,
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
        runfiles = ctx.runfiles(files = [ctx.file.description]),
    )]

nsis_test_harness = rule(
    doc = "Compile a standalone API harness from an NSH include and JSON description.",
    implementation = _harness_impl,
    executable = True,
    cfg = windows_source_transition,
    toolchains = ["//nsis/toolchain:toolchain_type"],
    attrs = {
        "src": attr.label(mandatory = True, allow_single_file = [".nsh"]),
        "description": attr.label(mandatory = True, allow_single_file = [".json"]),
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
