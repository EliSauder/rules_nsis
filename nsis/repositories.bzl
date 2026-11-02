"""Repository rules for fetching NSIS plugins."""

load("//nsis/private:plugins.bzl", "NSIS_TARGETS")

# Archive folders searched for each NSIS target's DLL, in order.
_TARGET_DIRS = {
    "x86-unicode": ["Plugins/x86-unicode"],
    "amd64-unicode": ["Plugins/amd64-unicode", "Plugins/x64-unicode"],
}

def _prebuilt_dlls(rctx):
    dll = rctx.attr.plugin_name + ".dll"
    attrs = []
    for target, dirs in _TARGET_DIRS.items():
        for d in dirs:
            if rctx.path(d + "/" + dll).exists:
                attrs.append('    {} = "{}/{}",'.format(NSIS_TARGETS[target], d, dll))
                break
    if not attrs:
        fail("no {} found in the archive".format(dll))
    return "", attrs

def _source_dlls(rctx):
    source_dir = rctx.attr.source_dir.rstrip("/")
    if not rctx.path(source_dir).exists:
        fail("source_dir {} not found in the archive".format(source_dir))
    rules = ['load("{}", "nsis_plugin_dll")\n'.format(Label("//nsis/private:plugins.bzl"))]
    attrs = []
    for target, attr_name in NSIS_TARGETS.items():
        rules.append("""nsis_plugin_dll(
    name = "{attr}",
    plugin_name = "{name}",
    target = "{target}",
    srcs = glob(["{dir}/*.c", "{dir}/*.h"]),
    copts = {copts},
)
""".format(attr = attr_name, name = rctx.attr.plugin_name, target = target, dir = source_dir, copts = rctx.attr.copts))
        attrs.append('    {} = ":{}",'.format(attr_name, attr_name))
    return "\n".join(rules), attrs

def _nsis_plugin_archive_impl(rctx):
    rctx.download_and_extract(url = rctx.attr.urls, sha256 = rctx.attr.sha256, stripPrefix = rctx.attr.strip_prefix)
    for patch in rctx.attr.patches:
        rctx.patch(patch, strip = rctx.attr.patch_strip)

    dll_rules, attrs = _source_dlls(rctx) if rctx.attr.source_dir else _prebuilt_dlls(rctx)
    if not rctx.path(rctx.attr.license).exists:
        fail("license file {} not found in the archive".format(rctx.attr.license))

    rctx.file("BUILD.bazel", """load("{defs}", "nsis_plugin")
{dll_rules}
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
        dll_rules = dll_rules,
        name = rctx.attr.plugin_name,
        attrs = "\n".join(attrs),
        license = rctx.attr.license,
    ))

nsis_plugin_archive = repository_rule(
    implementation = _nsis_plugin_archive_impl,
    doc = """Downloads an NSIS plugin archive and declares `@<name>//:plugin`.

The archive must have the usual layout: `Plugins/x86-unicode/<plugin_name>.dll`,
`Plugins/amd64-unicode` or `Plugins/x64-unicode` for the 64-bit build, and
headers in `Include/`. With `source_dir`, the DLLs are instead compiled from the
C sources in that folder, after `patches` are applied. For other layouts, use
http_archive with a build_file_content that calls nsis_plugin.
""",
    attrs = {
        "plugin_name": attr.string(mandatory = True, doc = "The name scripts use, as in plugin_name::Func."),
        "urls": attr.string_list(mandatory = True),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "license": attr.string(mandatory = True, doc = "Path of the license file inside the archive."),
        "patches": attr.label_list(doc = "Patches applied after extraction, relative to the archive root."),
        "patch_strip": attr.int(default = 1, doc = "Leading path components stripped from the file names in the patches."),
        "source_dir": attr.string(
            doc = "Folder with the plugin's C sources. When set, both Unicode DLLs are compiled from " +
                  "its .c files with Zig, without a C runtime, instead of taken from the archive.",
        ),
        "copts": attr.string_list(doc = "Compiler flags for a source build."),
    },
)
