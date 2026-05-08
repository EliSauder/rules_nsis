NsisToolChainInfo = provider(
    doc = "Toolchain provider for NSIS",
    fields = {
        "makensis": "The makensis executable",
        "nsis_files": "Depset of files belonging to the NSIS distribution.",
        "args_style": "The style of arguments to use -arg (dash) or /arg (slash).",
    },
)

def _nsis_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            nsis = NsisToolChainInfo(
                makensis = ctx.executable.makensis,
                nsis_files = ctx.attr.nsis_files[DefaultInfo].files,
                args_style = ctx.attr.args_style,
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
            mandatory = True,
            allow_files = True,
            doc = "All NSIS distribution files.",
        ),
        "args_style": attr.string(
            mandatory = True,
            values = ["slash", "dash"],
            doc = "The possible type of argument prefix. Slash for win and dash for unix.",
        ),
    },
    doc = "Defines an NSIS Bazel toolchain implementation.",
)
