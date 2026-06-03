def _windows_source_transition_impl(settings, attr):
    if attr.arch == "x86_32":
        return {
            "//command_line_option:platforms": "//nsis/private:windows_x32"
        }
    if attr.arch == "x86_64":
        return {
            "//command_line_option:platforms": "//nsis/private:windows_x64"
        }
    if attr.arch == "arm64":
        return {
            "//command_line_option:platforms": "//nsis/private:windows_arm64"
        }
    if attr.arch == "arm32":
        return {
            "//command_line_option:platforms": "//nsis/private:windows_arm32"
        }
    fail("unrecognized arch: {}".format(attr.arch))

windows_source_transition = transition(
    implementation = _windows_source_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _windows_source_impl(ctx):
    return DefaultInfo(files = depset(ctx.files.srcs))

windows_source = rule(
    implementation = _windows_source_impl,
    attrs = {
        "srcs": attr.label_list(
            cfg=windows_source_transition,
        ),
        "arch": attr.string(
            mandatory = False,
            default = "x86_64",
            doc = "The architecture to build the installer for.",
            values = [
                "x86_64",
                "x86_32",
                "arm64",
                "arm32",
            ],
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        )
    },
)
