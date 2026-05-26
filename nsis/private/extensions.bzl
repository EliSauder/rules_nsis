load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_NSIS_SRC_BUILD_FILE = """
load("@rules_nsis//nsis/private:dirrule.bzl", "dirrule")

filegroup(
  name = "nsis_src_files",
  srcs = glob(["**"]),
)

dirrule(
    name = "nsis_src_files_dir",
    srcs = [":nsis_src_files"],
    visibility = ["//visibility:public"],
)

genrule(
  name = "nsis_bin",
  executable = True,
  srcs = [
    "@zlib_nsis//:bin",
    ":nsis_src_files_dir",
  ],
  cmd = \"\"\"
ls external
prefix="$$(realpath "$$(dirname "$(OUTS)")")"
$(execpath @rules_nsis//nsis/toolchain:scons_bin) SKIPSTUBS=all SKIPPLUGINS=all SKIPUTILS=all SKIPMISC=all \
  NSIS_CONFIG_CONST_DATA_PATH=no PREFIX="$$prefix" -C "$(location :nsis_src_files_dir)" \
  VERSION="{version}" install-compiler

\"\"\",
  outs = ["bin/makensis"],
  toolchains = [
    "@bazel_tools//tools/cpp:toolchain_type",
    "@rules_python//python:current_py_toolchain",
  ],
  tools = [
    "@rules_nsis//nsis/toolchain:scons_bin",
  ],
  compatible_with = [
    "@platforms//os:linux",
    "@platforms//os:osx",
  ],
  visibility = ["//visibility:public"],
)

alias(
    name = "makensis",
    actual = "bin/makensis",
    visibility = ["//visibility:public"],
)
"""

_NSIS_WIN_BUILD_FILE = """
load("@rules_nsis//nsis/private:dirrule.bzl", "dirrule")

exports_files(
  ["Bin/makensis.exe"],
  visibility = ["//visibility:public"],
)

filegroup(
  name = "nsis_files",
  srcs = glob(["**"]),
  visibility = ["//visibility:public"],
)

dirrule(
  name = "nsis_files_dir",
  srcs = [":nsis_files"],
  visibility = ["//visibility:public"],
)

alias(
  name = "makensis",
  actual = "Bin/makensis.exe",
  visibility = ["//visibility:public"],
)
"""

def _nsis_tool_alias_repo_impl(repository_ctx):
  os_name = repository_ctx.name.lower()

  if os_name.startswith("windows"):
    actual = "@{}//:makensis".format(repository_ctx.attr.nsis_win_repo)
    nsis_files = "@{}//:nsis_files".format(repository_ctx.attr.nsis_win_repo)
    nsis_files_dir = "@{}//:nsis_files_dir".format(repository_ctx.attr.nsis_win_repo)
  else:
    actual = "@{}//:makensis".format(repository_ctx.attr.nsis_src_repo)
    nsis_files = "@{}//:nsis_files".format(repository_ctx.attr.nsis_win_repo)
    nsis_files_dir = "@{}//:nsis_files_dir".format(repository_ctx.attr.nsis_win_repo)

  repository_ctx.file(
    "BUILD.bazel",
    """
alias(
  name = "makensis",
  actual = "{actual}",
  visibility = ["//visibility:public"],
)

alias(
  name = "nsis_files",
  actual = "{nsis_files}",
  visibility = ["//visibility:public"],
)

alias(
  name = "nsis_files_dir",
  actual = "{nsis_files_dir}",
  visibility = ["//visibility:public"],
)
    """.format(actual = actual, nsis_files = nsis_files, nsis_files_dir = nsis_files_dir),
  )

_nsis_tool_alias_repo = repository_rule(
  implementation = _nsis_tool_alias_repo_impl,
  attrs = {
    "nsis_src_repo": attr.string(mandatory = True),
    "nsis_win_repo": attr.string(mandatory = True),
  },
  local = True,
)

def _nsis_toolchains_repo_impl(repository_ctx):
    os_name = repository_ctx.os.name.lower()
    if os_name.startswith("windows"):
      args_style = "slash"
    else:
      args_style = "dash"

    repository_ctx.file(
        "BUILD.bazel",
        """
load("@rules_nsis//nsis:toolchains.bzl", "nsis_toolchain")

nsis_toolchain(
    name = "nsis_toolchain_impl",
    makensis = "@{tool_repo}//:makensis",
    nsis_files = "@{tool_repo}//:nsis_files",
    nsis_dir = "@{tool_repo}//:nsis_files_dir",
    args_style = "{args_style}",
)

toolchain(
    name = "toolchain",
    toolchain = ":nsis_toolchain_impl",
    toolchain_type = "@rules_nsis//nsis/toolchain:toolchain_type",
    target_compatible_with = [
        "@platforms//os:windows",
    ],
    visibility = ["//visibility:public"],
)
        """.format(tool_repo = repository_ctx.attr.tool_repo,
        args_style = args_style,
        ),
    )

_nsis_toolchains_repo = repository_rule(
    implementation = _nsis_toolchains_repo_impl,
    attrs = {
        "tool_repo": attr.string(mandatory = True),
    },
)

_NSIS_VERSION_SHA = {
    "3.11": {
        "src": "19e72062676ebdc67c11dc032ba80b979cdbffd3886c60b04bb442cdd401ff4b",
        "win": "c7d27f780ddb6cffb4730138cd1591e841f4b7edb155856901cdf5f214394fa1",
    },
}

def _sourceforge_nsis_win_url(version):
  return "https://downloads.sourceforge.net/project/nsis/NSIS%203/{version}/nsis-{version}.zip".format(
      version = version,
  )
def _sourceforge_nsis_src_url(version):
  return "https://downloads.sourceforge.net/project/nsis/NSIS%203/{version}/nsis-{version}-src.tar.bz2".format(
      version = version,
  )

def _sourceforge_nsis_sha256(version):
  if version in _NSIS_VERSION_SHA:
    return _NSIS_VERSION_SHA[version]

  fail("Unknown version {v}, valid versions are: {vs}".format(v = version, vs = _NSIS_VERSION_SHA.keys()))


def _fail_duplicate(kind, name, first_module, second_module):
  fail("Duplicate {} named '{}'. First declared by module '{}', again by module '{}'".format(
    kind, name, first_module, second_module))

def _create_nsis_repositories(module_ctx, mod, toolchain, deps, dev_deps):
    nsis_version = toolchain.version

    nsis_src_repo_name = "{}_src".format(toolchain.name)
    nsis_win_repo_name = "{}_win".format(toolchain.name)
    tool_repo_name = "{}_tool".format(toolchain.name)
    toolchains_repo_name = "{}_toolchains".format(toolchain.name)

    sha = _sourceforge_nsis_sha256(nsis_version)
    sourceforge_win_sha256 = sha["win"]
    sourceforge_src_sha256 = sha["src"]

    http_archive(
        name = nsis_win_repo_name,
        urls = [_sourceforge_nsis_win_url(nsis_version)],
        strip_prefix = "nsis-{}".format(nsis_version),
        sha256 = sourceforge_win_sha256,
        build_file_content = _NSIS_WIN_BUILD_FILE,
    )

    http_archive(
        name = nsis_src_repo_name,
        urls = [_sourceforge_nsis_src_url(nsis_version)],
        strip_prefix = "nsis-{}-src".format(nsis_version),
        sha256 = sourceforge_src_sha256,
        build_file_content = _NSIS_SRC_BUILD_FILE.format(
            version = nsis_version,
            archive = nsis_src_repo_name,
        ),
    )

    _nsis_tool_alias_repo(
        name = tool_repo_name,
        nsis_src_repo = nsis_src_repo_name,
        nsis_win_repo = nsis_win_repo_name,
    )

    _nsis_toolchains_repo(
        name = toolchains_repo_name,
        tool_repo = tool_repo_name,
    )

    if mod != None and module_ctx.is_dev_dependency(toolchain):
        dev_deps.append(tool_repo_name)
        dev_deps.append(toolchains_repo_name)
    else:
        deps.append(tool_repo_name)
        deps.append(toolchains_repo_name)

def _nsis_extension_impl(module_ctx):
  deps = []
  dev_deps = []

  seen = {}

  tc_defined = False

  for mod in module_ctx.modules:
    for toolchain in mod.tags.executable:
      tc_defined = True
      if toolchain.name in seen:
        _fail_duplicate("toolchain", toolchain.name, seen[toolchain.name], mod.name)
      seen[toolchain.name] = mod.name

      nsis_version = toolchain.version

      _create_nsis_repositories(
          module_ctx = module_ctx,
          mod = mod,
          toolchain = toolchain,
          deps = deps,
          dev_deps = dev_deps,
      )
  if not tc_defined:
      default_toolchain = struct(
          name = "nsis",
          version = "3.11",
      )

      _create_nsis_repositories(
          module_ctx = module_ctx,
          mod = None,
          toolchain = default_toolchain,
          deps = deps,
          dev_deps = dev_deps,
      )

  return module_ctx.extension_metadata(
    root_module_direct_dev_deps = dev_deps,
    root_module_direct_deps = deps
  )

_nsis_toolchain_tag = tag_class(
  attrs = {
    "name": attr.string(
      default = "nsis",
      doc = "Generating host-dispatching repository exposing :makensis and :nsis_files.",
    ),
    "version": attr.string(
      default = "3.11",
      doc = "The version of nsis to use.",
    ),
  }
)

nsis = module_extension(
  implementation = _nsis_extension_impl,
  tag_classes = {
    "executable": _nsis_toolchain_tag,
  },
)
