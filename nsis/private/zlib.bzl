"""Download Windows zlib, falling back to a Windows x86 source build."""

load("@hermetic_cc_toolchain//toolchain:defs.bzl", "toolchains")

_ZLIB_URL = "https://nsis.sourceforge.io/mediawiki/images/c/ca/Zlib-1.2.7-win32-x86.zip"
_ZLIB_SHA256 = "4f2819139f53ac23bfd77b3dca3068174d5c791b3e84f7984aa04a3a3f585eff"
_SOURCES = [
    "adler32.c",
    "compress.c",
    "crc32.c",
    "deflate.c",
    "gzclose.c",
    "gzlib.c",
    "gzread.c",
    "gzwrite.c",
    "infback.c",
    "inffast.c",
    "inflate.c",
    "inftrees.c",
    "trees.c",
    "uncompr.c",
    "zutil.c",
]

def _zlib_repository_impl(ctx):
    archive = "zlib.zip"
    result = ctx.download(
        url = ctx.attr.urls,
        output = archive,
        sha256 = ctx.attr.sha256,
        allow_fail = True,
    ) if ctx.attr.download else None
    if result and result.success:
        ctx.extract(archive)
        ctx.delete(archive)
        ctx.file("BUILD.bazel", """
filegroup(
    name = "bin",
    srcs = glob(["**"]),
    visibility = ["//visibility:public"],
)
""")
    else:
        print("Windows zlib download {}; building from source for Windows x86 with Zig.".format(
            "failed" if ctx.attr.download else "disabled",
        ))
        ctx.file("BUILD.bazel", """
alias(
    name = "bin",
    actual = "{}",
    visibility = ["//visibility:public"],
)
""".format(ctx.attr.source_target))

zlib_repository = repository_rule(
    implementation = _zlib_repository_impl,
    attrs = {
        "urls": attr.string_list(default = [_ZLIB_URL]),
        "sha256": attr.string(default = _ZLIB_SHA256),
        "download": attr.bool(default = True),
        "source_target": attr.label(default = "//nsis/toolchain:zlib_windows"),
    },
)

def _zlib_toolchain_impl(ctx):
    toolchains()
    return ctx.extension_metadata(root_module_direct_deps = ["zig_config"], root_module_direct_dev_deps = [])

zlib_toolchain = module_extension(implementation = _zlib_toolchain_impl)

def _zlib_files_impl(ctx):
    if not ctx.target_platform_has_constraint(ctx.attr._windows[platform_common.ConstraintValueInfo]) or not ctx.target_platform_has_constraint(ctx.attr._x86[platform_common.ConstraintValueInfo]):
        fail("Windows zlib must be built through the Windows x86 platform transition")

    sources = {src.basename: src for src in ctx.files.srcs}
    inputs = depset(ctx.files.srcs + ctx.files._zig_files)
    flags = ["-target", "x86-windows-gnu", "-O2", "-I", sources["zlib.h"].dirname]
    outputs = []
    for name in ["include/zlib.h", "include/zconf.h", "LICENSE"]:
        out = ctx.actions.declare_file(ctx.label.name + "/" + name)
        ctx.actions.symlink(output = out, target_file = sources[name.split("/")[-1]])
        outputs.append(out)

    objects = []
    for name in _SOURCES:
        obj = ctx.actions.declare_file(ctx.label.name + "/_objs/" + name[:-2] + ".obj")
        ctx.actions.run(
            executable = ctx.executable._zig,
            arguments = ["cc"] + flags + ["-c", sources[name].path, "-o", obj.path],
            inputs = inputs,
            outputs = [obj],
            env = {"ZIG_GLOBAL_CACHE_DIR": ".zig-cache"},
            mnemonic = "WindowsZlibCompile",
            progress_message = "Compiling Windows x86 zlib: " + name,
        )
        objects.append(obj)

    archive = ctx.actions.declare_file(ctx.label.name + "/lib/zlib.lib")
    ctx.actions.run(
        executable = ctx.executable._zig,
        arguments = ["ar", "rcs", archive.path] + [obj.path for obj in objects],
        inputs = depset(objects + ctx.files._zig_files),
        outputs = [archive],
        env = {"ZIG_GLOBAL_CACHE_DIR": ".zig-cache"},
        mnemonic = "WindowsZlibArchive",
    )
    dll = ctx.actions.declare_file(ctx.label.name + "/zlib1.dll")
    import_lib = ctx.actions.declare_file(ctx.label.name + "/lib/zdll.lib")
    ctx.actions.run(
        executable = ctx.executable._zig,
        arguments = ["cc"] + flags + [
            "-shared",
            "-DZLIB_DLL",
            "-DZLIB_INTERNAL=",
        ] + [sources[name].path for name in _SOURCES] + [
            "-o",
            dll.path,
            "-Wl,--out-implib," + import_lib.path,
        ],
        inputs = inputs,
        outputs = [dll, import_lib],
        env = {"ZIG_GLOBAL_CACHE_DIR": ".zig-cache"},
        mnemonic = "WindowsZlibLink",
        progress_message = "Linking Windows x86 zlib DLL",
    )
    mingw_import_lib = ctx.actions.declare_file(ctx.label.name + "/lib/libzdll.a")
    ctx.actions.symlink(output = mingw_import_lib, target_file = import_lib)
    return [DefaultInfo(files = depset(outputs + [archive, dll, import_lib, mingw_import_lib]))]

zlib_files = rule(
    implementation = _zlib_files_impl,
    attrs = {
        "srcs": attr.label(
            default = "@zlib_source//:srcs",
            allow_files = True,
        ),
        "_windows": attr.label(default = "@platforms//os:windows"),
        "_x86": attr.label(default = "@platforms//cpu:x86_32"),
        "_zig": attr.label(default = "@zlib_zig//:zig", executable = True, allow_single_file = True, cfg = "exec"),
        "_zig_files": attr.label(default = "@zlib_zig//:all", cfg = "exec"),
    },
)
