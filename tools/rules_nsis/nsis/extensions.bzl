load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@rules_nixpkgs_core//:nixpkgs.bzl", "nixpkgs_git_repository", "nixpkgs_package")

_NSIS_NIX_BUILD_FILE = """
exports_files(
  ["bin/makensis"],
  visibility = ["//visibility:public"],
)

filegroup(
  name = "nsis_files",
  srcs = glob(["**"]),
  visibility = ["//visibility:public"],
)

alias(
    name = "makensis",
    actual = "bin/makensis",
    visibility = ["//visibility:public"],
)
"""

_NSIS_WIN_BUILD_FILE = """
exports_files(
  ["Bin/makensis.exe"],
  visibility = ["//visibility:public"],
)

filegroup(
  name = "nsis_files",
  srcs = glob(["**"]),
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
  else:
    actual = "@{}//:makensis".format(repository_ctx.attr.nsis_nix_repo)
    nsis_files = "@{}//:nsis_files".format(repository_ctx.attr.nsis_nix_repo)

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
    """.format(actual = actual, nsis_files = nsis_files),
  )

_nsis_tool_alias_repo = repository_rule(
  implementation = _nsis_tool_alias_repo_impl,
  attrs = {
    "nsis_nix_repo": attr.string(mandatory = True),
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
    args_style = "{args_style}",
)

toolchain(
    name = "toolchain",
    toolchain = ":nsis_toolchain_impl",
    toolchain_type = "@rules_nsis//nsis:toolchain_type",
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

def _sourceforge_nsis_zip_url(version):
  return "https://downloads.sourceforge.net/project/nsis/NSIS%203/{version}/nsis-{version}.zip".format(
      version = version,
  )

def _sourceforge_nsis_zip_sha256(version):
  mp = {
    "3.11": "",
  }
  if version in mp:
    return mp[version]

  fail("Unknown version {v}, valid versions are: {vs}".format(v = version, vs = mp.keys()))


def _fail_duplicate(kind, name, first_module, second_module):
  fail("Duplicate {} named '{}'. First declared by module '{}', again by module '{}'".format(
    kind, name, first_module, second_module))

def _get_nixdetails_from_version(version):
  mp = {
    "3.11": {
      "remote": "https://github.com/NixOS/nixpkgs",
      "revision": "755f5aa91337890c432639c60b6064bb7fe67769",
      "sha256": "affd300e16c3566c7b1c7ff8c6ef6734a13d61a343981f5c6868a11fbb735db3",
      "attr": "nsis",
    }
  }
  if version in mp:
    return mp[version]

  fail("Unknown version {v}, valid versions are: {vs}".format(v = version, vs = mp.keys()))


def _create_nsis_repositories(module_ctx, mod, toolchain, deps, dev_deps):
    nsis_version = toolchain.version

    nixpkg = _get_nixdetails_from_version(nsis_version)

    nixpkg_repo_name = "nixpkgs_{}".format(toolchain.name)
    nsis_nix_repo_name = "{}_nix".format(toolchain.name)
    nsis_win_repo_name = "{}_win".format(toolchain.name)
    tool_repo_name = "{}_tool".format(toolchain.name)
    toolchains_repo_name = "{}_toolchains".format(toolchain.name)

    sourceforge_sha256 = _sourceforge_nsis_zip_sha256(nsis_version)

    nixpkgs_git_repository(
        name = nixpkg_repo_name,
        remote = nixpkg["remote"],
        revision = nixpkg["revision"],
        sha256 = nixpkg["sha256"],
    )

    nixpkgs_package(
        name = nsis_nix_repo_name,
        attribute_path = nixpkg["attr"],
        repositories = {
            "nixpkgs": "@{}//:default.nix".format(nixpkg_repo_name),
        },
        build_file_content = _NSIS_NIX_BUILD_FILE,
    )

    http_archive(
        name = nsis_win_repo_name,
        urls = [_sourceforge_nsis_zip_url(nsis_version)],
        strip_prefix = "nsis-{}".format(nsis_version),
        sha256 = sourceforge_sha256,
        build_file_content = _NSIS_WIN_BUILD_FILE,
    )

    _nsis_tool_alias_repo(
        name = tool_repo_name,
        nsis_nix_repo = nsis_nix_repo_name,
        nsis_win_repo = nsis_win_repo_name,
    )

    _nsis_toolchains_repo(
        name = toolchains_repo_name,
        tool_repo = tool_repo_name,
    )

    if mod == None or mod.is_root:
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
