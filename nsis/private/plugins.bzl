"""NSIS plugin declaration and staging."""

# NSIS targets a plugin DLL can be provided for, in the order they are staged.
NSIS_TARGETS = ["x86-ansi", "x86-unicode", "amd64-unicode"]

NsisPluginInfo = provider(
    doc = "An NSIS plugin.",
    fields = {
        "name": "The plugin name scripts use, as in plugin_name::Func.",
        "dlls": "dict[str, File] keyed by NSIS target name.",
        "includes": "depset[File] of headers added with !addincludedir.",
        "licenses": "depset[File] of license files.",
        "transitive": "depset[struct] of this plugin and its deps (label, name, dlls as (target, File) pairs, includes, licenses).",
    },
)

NsisPluginSetInfo = provider(
    doc = "A collection of NSIS plugins.",
    fields = {
        "transitive": "depset[struct] of the plugins, in the format of NsisPluginInfo.transitive.",
    },
)

_DLL_ATTRS = {
    "x86-unicode": "x86_unicode",
    "x86-ansi": "x86_ansi",
    "amd64-unicode": "amd64_unicode",
}

def _nsis_plugin_impl(ctx):
    name = ctx.attr.plugin_name or ctx.label.name
    dlls = {}
    for target, attr_name in _DLL_ATTRS.items():
        f = getattr(ctx.file, attr_name)
        if f == None:
            continue
        if f.basename != name + ".dll":
            fail("{}: {} must be named {}.dll to provide the plugin '{}', got {}".format(
                ctx.label,
                attr_name,
                name,
                name,
                f.basename,
            ))
        dlls[target] = f
    if not dlls:
        fail("{}: at least one of x86_unicode, x86_ansi or amd64_unicode is required".format(ctx.label))
    for include in ctx.files.includes:
        if not include.basename.endswith(".nsh"):
            fail("{}: includes must be .nsh files, got {}".format(ctx.label, include.path))

    includes = depset(ctx.files.includes)
    licenses = depset([ctx.file.license])
    record = struct(
        label = str(ctx.label),
        name = name,
        dlls = tuple(dlls.items()),
        includes = includes,
        licenses = licenses,
    )
    transitive = depset(
        [record],
        transitive = [dep[NsisPluginInfo].transitive for dep in ctx.attr.deps],
    )
    return [
        DefaultInfo(files = depset(dlls.values() + ctx.files.includes + [ctx.file.license])),
        NsisPluginInfo(
            name = name,
            dlls = dlls,
            includes = includes,
            licenses = licenses,
            transitive = transitive,
        ),
    ]

nsis_plugin = rule(
    implementation = _nsis_plugin_impl,
    doc = """Declares a prebuilt NSIS plugin.

At least one DLL must be given. Each DLL must be named `<plugin_name>.dll`
because makensis derives the command prefix from the file name.
""",
    attrs = {
        "plugin_name": attr.string(
            doc = "The name scripts use, as in `plugin_name::Func`. Defaults to the target name.",
        ),
        "x86_unicode": attr.label(allow_single_file = [".dll"], doc = "The x86-unicode build."),
        "x86_ansi": attr.label(allow_single_file = [".dll"], doc = "The x86-ansi build."),
        "amd64_unicode": attr.label(allow_single_file = [".dll"], doc = "The amd64-unicode build."),
        "includes": attr.label_list(
            allow_files = [".nsh"],
            doc = "Headers made available with !addincludedir.",
        ),
        "license": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The license file, collected in the `plugin_licenses` output group.",
        ),
        "deps": attr.label_list(
            providers = [NsisPluginInfo],
            doc = "Plugins whose headers this plugin's headers include.",
        ),
    },
)

def _nsis_plugin_set_impl(ctx):
    return [
        NsisPluginSetInfo(transitive = depset(
            transitive = [p[NsisPluginInfo].transitive for p in ctx.attr.plugins],
        )),
    ]

nsis_plugin_set = rule(
    implementation = _nsis_plugin_set_impl,
    doc = "Forwards a list of nsis_plugin targets as one target.",
    attrs = {
        "plugins": attr.label_list(providers = [NsisPluginInfo]),
    },
)

PLUGIN_ATTRS = {
    "plugins": attr.label_list(
        providers = [[NsisPluginInfo], [NsisPluginSetInfo]],
        doc = "Additional NSIS plugins (nsis_plugin targets) made available to the script.",
    ),
    "_default_plugins": attr.label(
        default = Label("//nsis/plugins:defaults"),
        providers = [NsisPluginSetInfo],
    ),
}

def stage_plugins(ctx, plugin_targets):
    """Stages plugin DLLs into one directory per NSIS target.

    Args:
        ctx: The rule context.
        plugin_targets: Targets providing NsisPluginInfo or NsisPluginSetInfo.

    Returns:
        struct(files, licenses, plugin_dirs, include_dirs) where files is a
        depset of everything the compile needs, licenses a depset, plugin_dirs
        a dict of NSIS target to directory path and include_dirs a sorted list
        of header directories.
    """
    transitives = []
    for t in plugin_targets:
        if NsisPluginInfo in t:
            transitives.append(t[NsisPluginInfo].transitive)
        else:
            transitives.append(t[NsisPluginSetInfo].transitive)

    by_name = {}
    for record in depset(transitive = transitives).to_list():
        previous = by_name.get(record.name)
        if previous == None:
            by_name[record.name] = record
        elif previous.label != record.label:
            fail("{}: plugin name '{}' is provided by both {} and {}".format(
                ctx.label,
                record.name,
                previous.label,
                record.label,
            ))

    staged = []
    plugin_dirs = {}
    include_files = []
    licenses = []
    for name in sorted(by_name):
        record = by_name[name]
        for target in NSIS_TARGETS:
            dll = dict(record.dlls).get(target)
            if dll == None:
                continue
            out = ctx.actions.declare_file("{}.plugins/{}/{}.dll".format(ctx.label.name, target, name))
            ctx.actions.symlink(output = out, target_file = dll)
            staged.append(out)
            plugin_dirs[target] = out.dirname
        include_files += record.includes.to_list()
        licenses += record.licenses.to_list()

    return struct(
        files = depset(staged + include_files),
        licenses = depset(licenses),
        plugin_dirs = plugin_dirs,
        include_dirs = sorted({f.dirname: True for f in include_files}.keys()),
    )

def plugin_script_lines(staged, make_path):
    """Script lines that add the staged plugins and their headers.

    Targets without plugins get no line.
    """
    lines = []
    for target in NSIS_TARGETS:
        if target in staged.plugin_dirs:
            lines.append('!addplugindir /{} "{}"'.format(target, make_path(staged.plugin_dirs[target])))
    for directory in staged.include_dirs:
        lines.append('!addincludedir "{}"'.format(make_path(directory)))
    return lines
