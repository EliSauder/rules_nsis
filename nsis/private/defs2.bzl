load("@bazel_skylib//lib:paths.bzl", "paths")
load("//nsis/private:transitions.bzl", "windows_transition")

_NSIS_TOOLCHAIN_TYPE = "@rules_nsis//nsis:toolchain_type"

toolchains = [
    "@rules_nsis/nsis:toolchain_type"
]

NsisComponentInfo = provider(
    doc = "NSIS Component Information",
    fields = {
        "name": "Component Name",
        "directory": "Optional Sub Directory of the component.",
        "service": "Whether the component is a windows service.",
        "service_executable": "The executable of the service.",
        "service_args": "The arguments for the service.",
        "service_start_type": "The start type of the service.",
        "service_dependencies": "List of other windows services this one depends on.",
        "description": "Description",
        "selection_mode": "How the component is selected.",
        "display_name": "The display name of the group.",
        "install_categories": "The install categories (types) the component is enabled in.",
        "srcs": "The file sources of the component.",
    },
)

NsisComponentGroupInfo = provider(
    doc = "NSIS Component Group Information",
    fields = {
        "name": "Component Name",
        "description": "Description",
        "expanded": "Whether the group is expanded by default or not.",
        "bold": "Whether the group name is bolded or not.",
        "display_name": "The display name of the group.",
        "components": "The list of components or sub groups within the group.",
    },
)


def _quote_nsi_string(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"')


def _nsis_flag(args_style, name):
    if args_style == "slash":
        return "/" + name
    return "-" + name

def _nsis_define(args_style, key, value = None):
    prefix = "/D" if args_style == "slash" else "-D"

    if value == None or value == "":
        return prefix + key

    return prefix + key + "=" + _quote_nsi_string(value)

nsis_component_group = rule(
    implementation = _nsis_component_group_impl,
    attrs = {
        "description": attr.string(
            mandatory = False,
            default = "",
            doc = "The description of the group.",
        ),
        "expanded": attr.bool(
            mandatory = False,
            default = True,
            doc = "Whether the group is expanded by default in the UI.",
        ),
        "bold": attr.bool(
            mandatory = False,
            default = True,
            doc = "Whether the group name font is bolded in the UI.",
        ),
        "display_name": attr.string(
            mandatory = False,
            default = None,
            doc = "The display name for the group. Defaults to the rule name converted to Title Case.",
        ),
        "components": attr.label_list(
            mandatory = True,
            allow_empty = False,
            doc = "The list of components or component groups to be apart of this group.",
            providers = [
                NsisComponentInfo,
                NsisComponentGroupInfo,
            ],
        ),
    },
)

nsis_component = rule(
    implementation = _nsis_component_impl,
    attrs = {
        "directory": attr.string(
            mandatory = False,
            default = "",
            doc = "The sub directory path under $INSTPATH where the component will be installed.",
        ),
        "service": attr.bool(
            mandatory = False,
            default = False,
            doc = "Whether the component represents a windows service.",
        ),
        "service_executable": attr.label(
            allow_single_file = True,
            default = None,
            doc = "The executable of the service. Required if service is True.",
            cfg = "target",
        ),
        "service_args": attr.string_list(
            mandatory = False,
            default = [],
            doc = "Command line args to pass to the service executable.",
        ),
        "service_start_type": attr.string(
            mandatory = False,
            default = "auto",
            doc = "Defines the start type to pass into sc.exe start field.",
            values = [
                "auto",
                "demand",
                "disabled",
                "delayed-auto",
            ],
        ),
        "service_dependencies": attr.string_list(
            mandatory = False,
            default = [],
            doc = "Defines the list of windows services this service depends on.",
        ),
        "description": attr.string(
            mandatory = False,
            default = "",
            doc = "The description of the component being installed.",
        ),
        "selection_mode": attr.string(
            mandatory = False,
            default = "required",
            doc = """
Defines how the component shows up in the UI when selecting.

hidden: The component will always be installed and is hidden from the user.
required: The compenent is visible to the user, but will always be selected.
default: The component is optional but will be selected by default.
optional: The component is optional but will be deselected by default.
""",
            values = [
                "hidden",
                "default",
                "required",
                "optional",
            ],
        ),
        "display_name": attr.string(
            mandatory = False,
            default = None,
            doc = "The display name for the component. Defaults to the rule name converted to Title Case.",
        ),
        "install_categories": attr.string_list(
            mandatory = False,
            default = [],
            doc "The list of install types that the component will be included in.",
        ),
        "srcs": = attr.label_list(
            mandatory = True,
            allow_empty = False,
            allow_files = True,
            cfg = "target",
        ),
        "dependencies": attr.label_list(
            mandatory = False,
            allow_empty = True,
            doc = "A list of components this one depends on.",
            providers = [
                NsisComponentInfo,
            ],
        ),
    },
)

def _get_outfile(ctx):
    if ctx.attr.product == None or ctx.attr.product == "":
        fail("most provide non-empty product attribute")

    if ctx.attr.outfile != None and ctx.attr.outfile != "":
        return ctx.actions.declare_file(ctx.attr.outfile)

    if ctx.vendor == None or ctx.attr.vendor == "":
        return ctx.actions.declare_file("{} Setup.exe".format(ctx.attr.product))

    fileName = "{} {} Setup.exe".format(ctx.attr.vendor, ctx.attr.product)
    return ctx.actions.declare_file(fileName)

def _make_nsis_args(ctx, toolchain, outfile):
    args_style = nsis_toolchain.args_style

    args = ctx.actions.args()

    args.add(_nsis_flag(args_style, "V{}".format(ctx.attr.verbosity)))

    if ctx.attr.strict:
        args.add(_nsis_flag(args_style, "WX"))

    if ctx.attr.no_config:
        args.add(_nsis_flag(args_style, "NOCONFIG"))

    args.add(_nsis_flag(args_style, "NOCD"))

    args.add(_nsis_define(args_style, "OUTFILE", _quote_nsi_string(outfile)))

    return args

def _makensis(ctx, script, inputs):
    toolchain = ctx.toolchains[_NSIS_TOOLCHAIN_TYPE].nsis

    outfile = _get_outfile(ctx)
    args = _make_nsis_args(ctx, toolchain, outfile)
    args.add(script.path)

    makensis = toolchain.makensis
    makensis_dir = toolchain.nsis_dir.files.to_list()[0].path
    makensis_files = toolchain.nsis_files

    tools = depset(
        direct = [makensis],
        transitive = [makensis_files],
    )

    inputs = depset(
        direct = [script] + inputs,
        transitive = [
            nsis_files,
            nsis_dir.files,
        ]
    )

    ctx.actions.run(
        mnemonic = "MakeNSIS",
        progress_message = "Building NSIS installer {}".format(outfile.short_path),
        executable = makensis,
        args = [args],
        inputs = inputs,
        tools = tools,
        outputs = [outfile],
        env = {
            "NSISDIR": makensis_dir,
        },
        use_default_shell_env = False,
    )

    return [
        DefaultInfo(files = depset([out]))
    ]

def _build_data_structure_group_group(group, inst_cat):
    data = {
        "Name": str(label.name),
        "DisplayName": str(group.display_name),
        "Description": str(group.description),
        "Expanded": bool(group.expanded),
        "Bold": bool(group.expanded),
        "Components": [],
        "ComponentGroups": [],
    }

    for dep in group.components:
        if NsisComponentInfo in dep:
            cmp = dep[NsisComponentInfo]
            data["Components"].append(_build_data_structure_component(cmp, inst_cat))
        if NsisComponentGroupInfo in dep:
            grp = dep[NsisComponentGroupInfo]
            data["ComponentGroups"].append(_build_data_structure_component_group(grp, inst_cat))
        else:
            fail("provided dependency is not a component or a component group.")

    return data


def _build_data_structure_component(component, inst_cat):
    data = {
        "Name": str(component.name),
        "Directory": str(component.directory),
        "Service": bool(component.service),
        "ServiceExecutable": str(component.service_executable.path),
        "ServiceArgs": " ".join(component.service_args),
        "ServiceDependencies": "\\".join(component.service_dependencies),
        "ServiceStartType": str(component.service_start_type),
        "SelectionMode": str(component.selection_mode),
        "DisplayName": str(component.display_name),
        "Description": str(component.description),
        "InstallCategories": " ".join([str(inst_cat.index(x)) for x in component.install_categories])
        "Files": [],
        "Directories": [],
        "Dependencies": [str(x[NsisComponentInfo].name) for x in component.dependencies],
    }

    for file in component.srcs.to_list():
        if file.is_directory:
            data["Directories"].append(str(file.path))
        else:
            data["Files"].append({
                "Name": str(file.basename),
                "Source": str(file.path),
            })

    return data

def _vendor_path(ctx):
    if ctx.attr.vendor_path == None or ctx.attr.vendor_path == "":
        return ctx.attr.vendor
    return ctx.attr.vendor_path

def _build_data_structure(ctx):
    data = {
        "Name": str(ctx.attr.name),
        "Product": str(ctx.attr.directory),
        "Vendor": str(ctx.attr.vendor),
        "VendorPath": str(_vendor_path(ctx)),
        "Description": str(ctx.attr.description),
        "Copyright": str(ctx.attr.copyright),
        "LicenseFile": str(ctx.attr.license_file.path),
        "Version": str(ctx.attr.versiont),
        "Architecture": str(ctx.attr.architecture),
        "InstallRoot": str(ctx.attr.install_root),
        "InstallPath": str(ctx.attr.install_path),
        "ExecutionLevel": str(ctx.attr.execution_level),
        "InstallCategories": [str(x) for x in ctx.attr.install_categories],
        "Compressor": str(ctx.attr.compressor),
        "CompressorDictSize": int(ctx.attr.compressor_dictsize),
        "Icon": str(ctx.attr.icon.path),
        "HeaderImage": str(ctx.attr.header_image.path),
        "MenuImage": str(ctx.attr.menu_image.path),
        "Components": [],
        "ComponentGroups": [],
    }

    # TODO: Add default logic into the lib and use go template cli for rendering
    #       template

    inst_cat = ctx.attr.install_categories

    for dep in ctx.attr.components:
        if NsisComponentInfo in dep:
            cmp = dep[NsisComponentInfo]
            data["Components"].append(_build_data_structure_component(cmp, inst_cat))
        if NsisComponentGroupInfo in dep:
            grp = dep[NsisComponentGroupInfo]
            data["ComponentGroups"].append(_build_data_structure_component_group(grp, inst_cat))
        else:
            fail("provided dependency is not a component or a component group.")

    return data

def _all_files_group(group):
    srcs = None

    for dep in group.components:
        if NsisComponentInfo in dep:
            cmp = dep[NsisComponentInfo]
            srcs = depset(
                direct = [cmp.service_executable],
                transitive = [
                    cmp.files,
                    srcs,
                ],
            )
        if NsisComponentGroupInfo in dep:
            grp = dep[NsisComponentGroupInfo]
            srcs = depset(
                transitive = [
                    _all_files_group(grp),
                    srcs,
                ],
            )
        else:
            fail("provided dependency is not a component or a component group.")

    return srcs

def _all_files(ctx):
    srcs = depset(
        direct = [
            ctx.attr.license_file,
            ctx.attr.icon,
            ctx.attr.header_image,
            ctx.attr.menu_image,
        ],
    )

    for dep in ctx.attr.components:
        if NsisComponentInfo in dep:
            cmp = dep[NsisComponentInfo]
            srcs = depset(
                direct = [cmp.service_executable],
                transitive = [
                    cmp.files,
                    srcs,
                ],
            )
        if NsisComponentGroupInfo in dep:
            grp = dep[NsisComponentGroupInfo]
            srcs = depset(
                transitive = [
                    _all_files_group(grp),
                    srcs,
                ],
            )
        else:
            fail("provided dependency is not a component or a component group.")

    return srcs

def _build_script(ctx):
    data = _build_data_structure(ctx)
    srcs = _all_files(ctx)

    args = ctx.actions.args()

    ctx.actions.run(
        mnemonic = "RenderNsiTemplate",
        progress_message = "Rendering Nsis Template",
        executable = "//nsis/buildtemplate_bin",
        args = [args],
        inputs = inputs,
        tools = tools,
        outputs = [outfile],
        env = {
            "NSISDIR": makensis_dir,
        },
        use_default_shell_env = False,
    )

def _nsis_installer_impl(ctx):
    values = _build_script(ctx)
    return _makensis(ctx, values.script, values.inputs)

nsis_installer = rule(
    implementation = _nsis_installer_impl,
    cfg = windows_transition,

    attrs = {
        "product": attr.string(
            mandatory = True,
            doc = "The display name of the software being packaged.",
        ),
        "vendor": attr.string(
            mandatory = False,
            default = "",
            doc = "The display name of the vendor providing the software.",
        ),
        "vendor_path": attr.string(
            mandatory = False,
            default = "",
            doc = """
The optional path to use below the root by default. E.g. Company\Vendor.
This will default to the provided vendor field.
""",
        ),
        "description": attr.string(
            mandatory = False,
            default = "",
            doc = "The description of the software being packaged.",
        ),
        "copyright": attr.string(
            mandatory = False,
            default = "",
            doc = "The copyright of the software being packaged.",
        ),
        "license_file": attr.label(
            allow_single_file = True,
            mandatory = False,
            default = None,
            doc = "The license file to use for the installer.",
        ),
        "version": attr.string(
            mandatory = False,
            default = "0.0.0.0",
            doc = "The numeric version for the installer.",
        ),
        "install_root": attr.string(
            mandatory = False,
            default = "",
            doc = """
The root path to install the software into. Defaults to NSIS's built in
$PROGRAMFILES64 (or $PROGRAMFILES if 32bit) when installed as admin. When
installed as a user, defaults to $LOCALAPPDATA\\Programs.

The final $INSTPATH for the software will be {{.InstallRoot}}\\{{.VendorPath}}.
""",
        ),
        "install_path": attr.string(
            mandatory = False,
            default = "",
            doc = "Overrides install_root and vendor_path with a specific path.",
        ),
        "execution_level": attr.string(
            mandatory = False,
            default = "admin",
            doc = "Set the execution level for the installer.",
            values = ["admin", "user"],
        ),
        "compressor": attr.string(
            mandatory = False,
            default = "lzma",
            doc = "Set the compressor to be used for building the installer.",
            values = ["lzma", "zlib", "bzip2"]
        ),
        "compressor_dictsize": attr.int(
            mandatory = False,
            default = 8,
            doc = "Set the compressor dict size for the lzma compression algorithm.",
        ),
        "icon": attr.label(
            allow_single_file = [".ico"],
            mandatory = False,
            default = None,
            doc = "The icon to use for the installer."
        ),
        "header_image": attr.label(
            allow_single_file = [".bmp"],
            mandatory = False,
            default = None,
            doc = "The image to use for the installer header.",
        ),
        "menu_image": attr.label(
            allow_single_file = [".bmp"],
            mandatory = False,
            default = None,
            doc = "The image to use for the welcome and finish installer pages.",
        ),
        "install_categories": attr.string_list(
            mandatory = False,
            default = ["Full", "Typical", "Minimal"],
            doc = "The possible install types to use when selecting components.",
        ),
        "defines": attr.string_dict(
            mandatory = False,
            default = {},
            doc = "A list of additional defines to include in the installer.",
        ),
        "verbosity": attr.int(
            mandatory = False,
            default = 2,
            doc = "makensis verbosity: 0 none, 1 errors, 2 warnings, 3 info, 4 all.",
            values = [0, 1, 2, 3, 4],
        ),
        "strict": attr.bool(
            mandatory = False,
            default = True,
            doc = "Pass /WX so warnings are treated as errors.",
        ),
        "no_config": attr.bool(
            mandatory = False,
            default = False,
            doc = "Pass /NOCONFIG to disable loading nsiconf.nsi",
        ),
        "components": attr.label_list(
            mandatory = True,
            allow_empty = False,
            doc = "The list of components and component groups to install.",
            providers = [
                NsisComponentInfo,
                NsisComponentGroupInfo,
            ],
        ),
        "outfile": attr.string(
            mandatory = False,
            default = None,
            doc = "The outfile to create. Defaults to '{{.Vendor}} {{Product}} Setup.exe'",
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
        )
    },
    toolchains = [
        _NSIS_TOOLCHAIN_TYPE,
    ],
    doc = "Builds a windows installer .exe using NSIS.",
)
