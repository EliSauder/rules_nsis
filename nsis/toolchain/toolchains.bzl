NsisToolChainInfo = provider(
    doc = "Toolchain provider for NSIS",
    fields = {
        "makensis": "The makensis executable",
        "nsis_files": "Depset of files belonging to the NSIS distribution.",
        "nsis_dir": "Directory to the files for NSIS.",
        "args_style": "The style of arguments to use -arg (dash) or /arg (slash).",
        "path_style": "The style of the path to use.",
    },
)

def _nsis_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            nsis = NsisToolChainInfo(
                makensis = ctx.executable.makensis,
                nsis_files = ctx.attr.nsis_files[DefaultInfo].files,
                nsis_dir = ctx.attr.nsis_dir,
                args_style = ctx.attr.args_style,
                path_style = ctx.attr.path_style,
            ),
        ),
    ]

nsis_toolchain = rule(
    implementation = _nsis_toolchain_impl,
    attrs = {
        "makensis": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
            allow_files = True,
            doc = "makensis executable.",
        ),
        "nsis_files": attr.label(
            mandatory = False,
            allow_files = True,
            doc = "All NSIS distribution files.",
        ),
        "nsis_dir": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "The directory for NSISDIR.",
        ),
        "args_style": attr.string(
            mandatory = True,
            values = ["slash", "dash"],
            doc = "The possible type of argument prefix. Slash for win and dash for unix.",
        ),
        "path_style": attr.string(
            mandatory = True,
            values = ["windows", "unix"],
            doc = "The style of path that things should be output as.",
        ),
    },
    doc = "Defines an NSIS Bazel toolchain implementation.",
)
