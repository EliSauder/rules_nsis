def _windows_transition_impl(settings, attr):
    return {
        "//command_line_options:platforms": str(attr.windows_platform)
    }

windows_transition = transition(
    implementation = _windows_transition_impl,
    inputs = [],
    outputs = ["//command_line_options:platforms"],
)
