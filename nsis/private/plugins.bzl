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
