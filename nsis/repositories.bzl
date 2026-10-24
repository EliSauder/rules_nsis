"""Repository rules for fetching NSIS plugins."""

load("//nsis/private:plugins.bzl", "NSIS_TARGETS")

# Archive folders searched for each NSIS target's DLL, in order.
_TARGET_DIRS = {
    "x86-unicode": ["Plugins/x86-unicode"],
    "amd64-unicode": ["Plugins/amd64-unicode", "Plugins/x64-unicode"],
}

def _nsis_plugin_archive_impl(rctx):
    rctx.download_and_extract(url = rctx.attr.urls, sha256 = rctx.attr.sha256, stripPrefix = rctx.attr.strip_prefix)

    dll = rctx.attr.plugin_name + ".dll"
    attrs = []
    for target, dirs in _TARGET_DIRS.items():
        for d in dirs:
            if rctx.path(d + "/" + dll).exists:
                attrs.append('    {} = "{}/{}",'.format(NSIS_TARGETS[target], d, dll))
                break
    if not attrs:
        fail("no {} found in the archive".format(dll))
    if not rctx.path(rctx.attr.license).exists:
        fail("license file {} not found in the archive".format(rctx.attr.license))

    rctx.file("BUILD.bazel", """load("{defs}", "nsis_plugin")

package(default_visibility = ["//visibility:public"])

exports_files(glob(["**"]))

nsis_plugin(
    name = "plugin",
    plugin_name = "{name}",
{attrs}
    includes = glob(["Include/*.nsh"]),
    license = "{license}",
)
""".format(
        defs = str(Label("//nsis:defs.bzl")),
        name = rctx.attr.plugin_name,
        attrs = "\n".join(attrs),
        license = rctx.attr.license,
    ))

nsis_plugin_archive = repository_rule(
    implementation = _nsis_plugin_archive_impl,
    doc = """Downloads a prebuilt NSIS plugin archive and declares `@<name>//:plugin`.

The archive must have the usual layout: `Plugins/x86-unicode/<plugin_name>.dll`,
`Plugins/amd64-unicode` or `Plugins/x64-unicode` for the 64-bit build, and
headers in `Include/`. For other layouts, use http_archive with a
build_file_content that calls nsis_plugin.
""",
    attrs = {
        "plugin_name": attr.string(mandatory = True, doc = "The name scripts use, as in plugin_name::Func."),
        "urls": attr.string_list(mandatory = True),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "license": attr.string(mandatory = True, doc = "Path of the license file inside the archive."),
    },
)
