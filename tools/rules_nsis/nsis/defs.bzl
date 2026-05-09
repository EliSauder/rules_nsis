load("@bazel_skylib//lib:paths.bzl", "paths")

toolchains = [
    "@rules_nsis//nsis:toolchain_type",
]

def _quote_nsi_string(value):
  return str(value).replace("\\", "\\\\").replace('"', '\\"')

def _dirname(path):
    parts = path.replace("\\", "/").split("/")
    if len(parts) <= 1:
        return "."
    return "/".join(parts[:-1])

def _parent_dir(path):
    return _dirname(_dirname(path))

def _nsis_flag(args_style, name):
  if args_style == "slash":
    return "/" + name
  return "-" + name

def _nsis_define(args_style, key, value = None):
  prefix = "/D" if args_style == "slash" else "-D"

  if value == None or value == "":
    return prefix + key

  return prefix + key + "=" + _quote_nsi_string(value)

_NSIS_TOOLCHAIN_TYPE = "@rules_nsis//nsis:toolchain_type"

def _nsis_installer_impl(ctx):
  if ctx.attr.verbosity < 0 or ctx.attr.verbosity > 4:
    fail("verbosity must be between 0 and 4")

  script = ctx.file.script
  out = ctx.actions.declare_file(ctx.attr.out)

  nsis_toolchain = ctx.toolchains[_NSIS_TOOLCHAIN_TYPE].nsis
  makensis = nsis_toolchain.makensis
  nsis_dir = nsis_toolchain.nsis_dir
  nsis_files = nsis_toolchain.nsis_files
  args_style = nsis_toolchain.args_style

  args = ctx.actions.args()

  args.add(_nsis_flag(args_style, "V{}".format(ctx.attr.verbosity)))

  if ctx.attr.strict:
    args.add(_nsis_flag(args_style, "WX"))

  if ctx.attr.no_config:
    args.add(_nsis_flag(args_style, "NOCONFIG"))

  if ctx.attr.no_cd:
    args.add(_nsis_flag(args_style, "NOCD"))

  args.add(_nsis_define(args_style, "OUTFILE", _quote_nsi_string(out.path)))

  for key in sorted(ctx.attr.defines.keys()):
    args.add(_nsis_define(args_style, key, ctx.attr.defines[key]))

  makensis_path = makensis.path
  makensis_path_normalized = makensis_path.replace("\\", "/")

  fd_inputs = []

  for target, define in ctx.attr.srcs.items():
    files = target[DefaultInfo].files.to_list()
    if len(files) != 1:
        fail("srcs entry for '{}' must produce exactly one file, but produced {}".format(
            define,
            len(files),
          ))
    file = files[0]
    fd_inputs.append(file)

    args.add(_nsis_define(args_style, define, file.path))

  args.add(script.path)

  inputs = depset(
    direct =  [script] + fd_inputs,
    transitive = [
      nsis_files,
      nsis_dir.files,
    ],
  )

  tools = depset(
    direct = [makensis],
    transitive = [
      nsis_files,
    ],
  )

  ctx.actions.run(
    mnemonic = "MakeNSIS",
    progress_message = "Building NSIS installer {}".format(out.short_path),
    executable = makensis,
    arguments = [args],
    inputs = inputs,
    tools = tools,
    outputs = [out],
    env = {
      "NSISDIR": nsis_dir.files.to_list()[0].path,
    },
    use_default_shell_env = False,
  )

  return [
    DefaultInfo(files = depset([out])),
  ]

nsis_installer = rule(
  implementation = _nsis_installer_impl,
  attrs = {
    "script": attr.label(
      mandatory = True,
      allow_single_file = [".nsi"],
      doc = "Main NSIS .nsi script",
    ),
    "srcs": attr.label_keyed_string_dict(
      allow_files = True,
      doc = "Files referenced by the NSIS script in the format of file labels mapped to NSIS defines. This should be a one to one mapping.",
    ),
    "out": attr.string(
      mandatory = True,
      doc = "Output installer filename, usally ending in .exe."
    ),
    "defines": attr.string_dict(
      default = {},
      doc = "Additional /D preprosessor defines passed to makensis."
    ),
    "verbosity": attr.int(
      default = 2,
      doc = "makensis verbosity: 0 none, 1 errors, 2 warnings, 3 info, 4 all.",
    ),
    "strict": attr.bool(
      default = True,
      doc = "Pass /WX so warnings are treated as errors.",
    ),
    "no_config": attr.bool(
      default = False,
      doc = "Pass /NOCONFIG to disable loading nsisconf.nsi",
    ),
    "no_cd": attr.bool(
      default = True,
      doc = "Pass /NOCD. Leave false if includes are relative to *.nsi file.",
    ),
  },
  toolchains = [
    _NSIS_TOOLCHAIN_TYPE,
  ],
  doc = "Builds a windows installer .exe from an NSIS .nsi script.",
)
