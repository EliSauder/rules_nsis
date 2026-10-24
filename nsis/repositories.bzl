"""Repository rules for fetching NSIS plugins."""

_DEFAULT_TARGET_DIRS = {
    "x86-unicode": "Plugins/x86-unicode",
    "x86-ansi": "Plugins/x86-ansi",
    "amd64-unicode": "Plugins/x64-unicode",
}

_ATTR_NAMES = {
    "x86-unicode": "x86_unicode",
    "x86-ansi": "x86_ansi",
    "amd64-unicode": "amd64_unicode",
}

def _nsis_plugin_archive_impl(rctx):
    rctx.download_and_extract(
        url = rctx.attr.urls,
        sha256 = rctx.attr.sha256,
        stripPrefix = rctx.attr.strip_prefix,
    )

    target_dirs = dict(rctx.attr.target_dirs) or dict(_DEFAULT_TARGET_DIRS)
    for target in target_dirs:
        if target not in _ATTR_NAMES:
            fail("unknown NSIS target '{}', expected one of {}".format(target, sorted(_ATTR_NAMES)))

    # makensis names the 64-bit folder amd64-unicode, so prefer it when present.
    if not rctx.attr.target_dirs and rctx.path("Plugins/amd64-unicode").exists:
        target_dirs["amd64-unicode"] = "Plugins/amd64-unicode"

    dll = rctx.attr.plugin_name + ".dll"
    attrs = []
    for target in sorted(target_dirs):
        path = "{}/{}".format(target_dirs[target], dll)
        if rctx.path(path).exists:
            attrs.append('    {} = "{}",'.format(_ATTR_NAMES[target], path))
    if not attrs:
        fail("no {} found in any of {}".format(dll, sorted(target_dirs.values())))

    if not rctx.path(rctx.attr.license).exists:
        fail("license file {} not found in the archive".format(rctx.attr.license))

    rctx.file("BUILD.bazel", """load("{defs}", "nsis_plugin")

package(default_visibility = ["//visibility:public"])

exports_files(glob(["**/*"]))

nsis_plugin(
    name = "plugin",
    plugin_name = "{name}",
{attrs}
    includes = glob(["{includes}/*.nsh"]),
    license = "{license}",
)
""".format(
        defs = str(Label("//nsis:defs.bzl")),
        name = rctx.attr.plugin_name,
        attrs = "\n".join(attrs),
        includes = rctx.attr.includes_dir,
        license = rctx.attr.license,
    ))

nsis_plugin_archive = repository_rule(
    implementation = _nsis_plugin_archive_impl,
    doc = """Downloads an archive of a prebuilt NSIS plugin and declares `@<name>//:plugin`.

Folders for NSIS targets that are missing from the archive are left out. For
archives with another layout, use http_archive with a build_file_content that
calls nsis_plugin.
""",
    attrs = {
        "plugin_name": attr.string(mandatory = True, doc = "The name scripts use, as in plugin_name::Func."),
        "urls": attr.string_list(mandatory = True),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "license": attr.string(mandatory = True, doc = "Path of the license file inside the archive."),
        "target_dirs": attr.string_dict(
            doc = "NSIS target (x86-unicode, x86-ansi, amd64-unicode) to the archive folder holding its DLL. " +
                  "Defaults to Plugins/x86-unicode, Plugins/x86-ansi and Plugins/x64-unicode " +
                  "(Plugins/amd64-unicode is preferred when it exists).",
        ),
        "includes_dir": attr.string(default = "Include", doc = "Folder whose .nsh files are the plugin's headers."),
    },
)
