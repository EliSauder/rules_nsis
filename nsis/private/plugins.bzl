"""NSIS plugin declaration and staging."""

# NSIS target to the nsis_plugin attribute holding its DLL. Installers are
# always Unicode, so there is no x86-ansi.
NSIS_TARGETS = {
    "x86-unicode": "x86_unicode",
    "amd64-unicode": "amd64_unicode",
}

NsisPluginInfo = provider(
    doc = "An NSIS plugin.",
    fields = {
        "name": "The plugin name scripts use, as in plugin_name::Func.",
        "dlls": "dict[str, File] keyed by NSIS target name.",
        "includes": "list[File] of headers added with !addincludedir.",
        "license": "File: the license.",
    },
)

def _nsis_plugin_impl(ctx):
    name = ctx.attr.plugin_name or ctx.label.name
    dlls = {}
    for target, attr_name in NSIS_TARGETS.items():
        f = getattr(ctx.file, attr_name)
        if f == None:
            continue
        if f.basename != name + ".dll":
            fail("{}: {} must be named {}.dll, got {}".format(ctx.label, attr_name, name, f.basename))
        dlls[target] = f
    if not dlls:
        fail("{}: at least one of {} is required".format(ctx.label, " or ".join(NSIS_TARGETS.values())))
    return [
        DefaultInfo(files = depset(dlls.values() + ctx.files.includes + [ctx.file.license])),
        NsisPluginInfo(name = name, dlls = dlls, includes = ctx.files.includes, license = ctx.file.license),
    ]

nsis_plugin = rule(
    implementation = _nsis_plugin_impl,
    doc = """Declares a prebuilt NSIS plugin.

Each DLL must be named `<plugin_name>.dll`, because makensis derives the
command prefix from the file name.
""",
    attrs = {
        "plugin_name": attr.string(
            doc = "The name scripts use, as in `plugin_name::Func`. Defaults to the target name.",
        ),
        "x86_unicode": attr.label(allow_single_file = [".dll"], doc = "The x86-unicode build."),
        "amd64_unicode": attr.label(allow_single_file = [".dll"], doc = "The amd64-unicode build."),
        "includes": attr.label_list(allow_files = [".nsh"], doc = "Headers made available with !addincludedir."),
        "license": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The license file, collected in the `plugin_licenses` output group.",
        ),
    },
)

_ZIG_TARGETS = {
    "x86-unicode": "x86-windows-gnu",
    "amd64-unicode": "x86_64-windows-gnu",
}

def _nsis_plugin_dll_impl(ctx):
    zig_target = _ZIG_TARGETS[ctx.attr.target]
    env = {"ZIG_GLOBAL_CACHE_DIR": ".zig-cache"}
    hdrs = [f for f in ctx.files.srcs if f.extension == "h"]
    include_dirs = sorted({f.dirname: True for f in ctx.files.srcs}.keys())

    # Compiled and linked separately: -nostdlib while compiling would also
    # drop the Windows headers.
    objects = []
    for src in ctx.files.srcs:
        if src.extension != "c":
            continue
        obj = ctx.actions.declare_file("{}/{}.o".format(ctx.label.name, src.basename))
        args = ctx.actions.args()
        args.add_all(["cc", "-target", zig_target, "-O2", "-c", "-DUNICODE", "-D_UNICODE"])
        args.add_all(include_dirs, format_each = "-I%s")
        args.add_all(ctx.attr.copts)
        args.add_all([src, "-o", obj])
        ctx.actions.run(
            executable = ctx.executable._zig,
            arguments = [args],
            inputs = depset([src] + hdrs, transitive = [ctx.attr._zig_files.files]),
            outputs = [obj],
            env = env,
            mnemonic = "NsisPluginCompile",
        )
        objects.append(obj)

    # Like the plugins shipped with NSIS, no C runtime: DllMain is the entry
    # point and only kernel32 and user32 are imported.
    dll = ctx.actions.declare_file("{}/{}.dll".format(ctx.label.name, ctx.attr.plugin_name))
    args = ctx.actions.args()
    args.add_all(["cc", "-target", zig_target, "-shared", "-s", "-nostdlib", "-Wl,--entry=DllMain"])
    args.add_all(objects)
    args.add_all(["-lkernel32", "-luser32", "-o", dll])
    ctx.actions.run(
        executable = ctx.executable._zig,
        arguments = [args],
        inputs = depset(objects, transitive = [ctx.attr._zig_files.files]),
        outputs = [dll],
        env = env,
        mnemonic = "NsisPluginDll",
    )
    return [DefaultInfo(files = depset([dll]))]

# Used by nsis_plugin_archive's source builds.
nsis_plugin_dll = rule(
    implementation = _nsis_plugin_dll_impl,
    doc = "Compiles C sources into a Unicode `<plugin_name>.dll` for one NSIS target, without a C runtime.",
    attrs = {
        "plugin_name": attr.string(mandatory = True),
        "target": attr.string(mandatory = True, values = sorted(_ZIG_TARGETS)),
        "srcs": attr.label_list(allow_files = [".c", ".h"]),
        "copts": attr.string_list(),
        "_zig": attr.label(default = "@zlib_zig//:zig", executable = True, allow_single_file = True, cfg = "exec"),
        "_zig_files": attr.label(default = "@zlib_zig//:all", cfg = "exec"),
    },
)
