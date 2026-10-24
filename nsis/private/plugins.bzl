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

PLUGIN_ATTRS = {
    "plugins": attr.label_list(
        providers = [NsisPluginInfo],
        doc = "Additional NSIS plugins (nsis_plugin targets) made available to the script.",
    ),
    "_default_plugins": attr.label_list(
        default = [Label("@nsis_plugin_nsarray//:plugin")],
        providers = [NsisPluginInfo],
    ),
}

def stage_plugins(ctx):
    """Stages the default and the requested plugins, one directory per NSIS target.

    Returns:
        struct(files, licenses, plugin_dirs, include_dirs): files is a depset of
        everything the compile needs, licenses a depset, plugin_dirs a dict of
        NSIS target to directory and include_dirs a sorted list of directories.
    """
    plugins = {}
    for t in ctx.attr._default_plugins + ctx.attr.plugins:
        info = t[NsisPluginInfo]
        previous = plugins.get(info.name)
        if previous and previous.label != t.label:
            fail("{}: plugin name '{}' is provided by both {} and {}".format(ctx.label, info.name, previous.label, t.label))
        plugins[info.name] = t

    staged = []
    plugin_dirs = {}
    includes = []
    licenses = []
    for name in sorted(plugins):
        info = plugins[name][NsisPluginInfo]
        for target, dll in info.dlls.items():
            out = ctx.actions.declare_file("{}.plugins/{}/{}.dll".format(ctx.label.name, target, name))
            ctx.actions.symlink(output = out, target_file = dll)
            staged.append(out)
            plugin_dirs[target] = out.dirname
        includes += info.includes
        licenses.append(info.license)

    return struct(
        files = depset(staged + includes),
        licenses = depset(licenses),
        plugin_dirs = plugin_dirs,
        include_dirs = sorted({f.dirname: True for f in includes}.keys()),
    )

def plugin_script_lines(staged, make_path):
    """Script lines that add the staged plugins and their headers."""
    lines = ['!addplugindir /{} "{}"'.format(t, make_path(d)) for t, d in sorted(staged.plugin_dirs.items())]
    return lines + ['!addincludedir "{}"'.format(make_path(d)) for d in staged.include_dirs]
