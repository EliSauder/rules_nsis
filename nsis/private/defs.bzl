load("//nsis/private:transitions.bzl", "windows_source_transition")

_NSIS_TOOLCHAIN_TYPE = "//nsis/toolchain:toolchain_type"

_EDGE_PARENT_KEY = "parent"
_EDGE_CHILD_KEY = "child"

_COMPONENTS_KEY = "Components"
_COMPONENT_GROUPS_KEY = "ComponentGroups"

_COMPONENT_DEPS_KEY = "ComponentDependencies"

toolchains = [
    "//nsis/toolchain:toolchain_type"
]

NsisInstallerInfo = provider(
    doc = "",
    fields = {
        "name": "The name of the installer",
        "product": "The display name of the software being packaged.",
        "product_path": "The path name of the software being packaged.",
        "vendor": "The display name of the vendor providing the software.",
        "vendor_path": "The optional path to use after the root by default. E.g. Company\\Vendor. Defaults to the vendor field.",
        "description": "The descripiton of the software being packaged.",
        "copyright": "The copyright of the software being packaged.",
        "license_file": "The licens file to use for the installer",
        "version": "The numric version for the installer.",
        "install_root": """
The root path to install the software into. Defaults to NSIS's built in
$PROGRAMFILES64 (or $PROGRAMFILES if 32bit) when installed as admin. When
installed as a user, defaults to $LOCALAPPDATA\\Programs.

The final $INSTPATH for the software will be {{.InstallRoot}}\\{{.VendorPath}}.
""",
        "install_path": "Overrides product_path and vendor_path with a specific path.",
        "execution_level": "Set the execution level for the installer.",
        "compressor": "Set the compressor to be used for building the installer.",
        "compressor_dictsize": "Set the compressor dict size for the lzma compression alg.",
        "icon": "The icon file for the installer.",
        "header_image": "The header image to use.",
        "menu_image": "The image to ues for the welcome and finsih installer pages.",
        "install_categories": "The possible install types to use when selecting components.",
        "defines": "The defines to use for the installer.",
        "verbosity": "The verbosity of outupt.",
        "no_config": "Whether to pass /NOCONFIG or not",
        "components": "List of root components and component groups.",
        "outfile": "Specify the outfile.",
        "arch": "The architecture to built the installer for.",
    },
)

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
        "dependencies": "The components this one depends on.",
        "shortcuts": "A list of shortcuts to make.",
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

def _always_make_win_path(value):
    v = str(value)
    if v.startswith("/"):
        v = "C:{}".format(v)
    return v.replace("/", "\\")

def _make_win_path(toolchain, value):
    if toolchain.path_style == "windows":
        return _always_make_win_path(value)
    else:
        return str(value)

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

def _nsis_component_group_impl(ctx):
    edges=[]

    cmpgrp = NsisComponentGroupInfo(
        name = str(ctx.label.name),
        description = str(ctx.attr.description),
        bold = bool(ctx.attr.bold),
        expanded = bool(ctx.attr.expanded),
        display_name = str(ctx.attr.display_name),
        components = edges
    )

    for child in ctx.attr.components:
        if NsisComponentInfo in child:
            edges.append({_EDGE_PARENT_KEY: {NsisComponentGroupInfo: cmpgrp}, _EDGE_CHILD_KEY: child})
        elif NsisComponentGroupInfo in child:
            grp = child[NsisComponentGroupInfo]
            edges.append({_EDGE_PARENT_KEY: {NsisComponentGroupInfo: cmpgrp}, _EDGE_CHILD_KEY: child})
            edges = edges + grp.components

    return cmpgrp


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
            default = "",
            doc = "The display name for the group. Defaults to the rule name converted to Title Case.",
        ),
        "components": attr.label_list(
            mandatory = True,
            allow_empty = False,
            doc = "The list of components or component groups to be apart of this group.",
            providers = [
                [NsisComponentInfo],
                [NsisComponentGroupInfo],
            ],
        ),
    },
)

def _nsis_component_impl(ctx):
    files = depset(ctx.files.srcs)

    return NsisComponentInfo(
        name = str(ctx.label.name),
        directory = str(ctx.attr.directory),
        service = bool(ctx.attr.service),
        service_executable = ctx.attr.service_executable,
        service_args = [str(x) for x in ctx.attr.service_args],
        service_start_type = str(ctx.attr.service_start_type),
        service_dependencies = [str(x) for x in ctx.attr.service_dependencies],
        description = str(ctx.attr.description),
        selection_mode = str(ctx.attr.selection_mode),
        display_name = str(ctx.attr.display_name),
        install_categories = [str(x) for x in ctx.attr.install_categories],
        shortcuts = ctx.attr.shortcuts,
        srcs = files,
        dependencies = ctx.attr.dependencies,
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
            executable = True,
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
            default = "",
            doc = "The display name for the component. Defaults to the rule name converted to Title Case.",
        ),
        "install_categories": attr.string_list(
            mandatory = False,
            default = [],
            doc = "The list of install types that the component will be included in.",
        ),
        "srcs": attr.label_list(
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
        "shortcuts": attr.label_list(
            mandatory = False,
            allow_empty = True,
            doc = "A list of files that, when installed, will be created as shortcuts if short cuts are enabled.",
            allow_files = True,
        ),
    },
)

def _get_outfile(ctx):
    if ctx.attr.product == None or ctx.attr.product == "":
        fail("most provide non-empty product attribute")

    if ctx.attr.outfile != None and ctx.attr.outfile != "":
        return ctx.actions.declare_file(ctx.attr.outfile)

    if ctx.attr.vendor == None or ctx.attr.vendor == "":
        return ctx.actions.declare_file("{} Setup.exe".format(ctx.attr.product))

    fileName = "{} {} Setup.exe".format(ctx.attr.vendor, ctx.attr.product)
    return ctx.actions.declare_file(fileName)

def _make_nsis_args(ctx, toolchain, outfile):
    args_style = toolchain.args_style

    args = ctx.actions.args()

    args.add(_nsis_flag(args_style, "V{}".format(ctx.attr.verbosity)))

    args.add(_nsis_flag(args_style, "WX"))

    if ctx.attr.no_config:
        args.add(_nsis_flag(args_style, "NOCONFIG"))

    args.add(_nsis_flag(args_style, "NOCD"))

    args.add(_nsis_define(args_style, "OUTFILE", _quote_nsi_string(outfile.path)))

    return args

def _makensis(ctx, toolchain, script, options_file, inputs):
    if script == None:
        fail("script can not be None")
    if options_file == None:
        fail("options file can not be None")

    outfile = _get_outfile(ctx)
    args = _make_nsis_args(ctx, toolchain, outfile)
    args.add(
        _nsis_define(
            toolchain.args_style,
            "INSTALL_OPTIONS_FILE",
            _quote_nsi_string(_make_win_path(toolchain, options_file.path)),
        ),
    )
    args.add(_make_win_path(toolchain, script.path))

    makensis = toolchain.makensis
    makensis_dir = toolchain.nsis_dir.files.to_list()
    makensis_files = toolchain.nsis_files

    if makensis_dir == None or None in makensis_dir:
        fail("makensis dir is None")
    if makensis_files == None or None in makensis_files.to_list():
        fail("makensis files is None")

    tools = depset(
        direct = [makensis],
        transitive = [makensis_files],
    )

    inputs = depset(
        direct = [script, options_file] + makensis_dir,
        transitive = [
            inputs,
            makensis_files,
        ]
    )

    ctx.actions.run(
        mnemonic = "MakeNSIS",
        progress_message = "Building NSIS installer {}".format(outfile.short_path),
        executable = makensis,
        arguments = [args],
        inputs = inputs,
        tools = tools,
        outputs = [outfile],
        env = {
            "NSISDIR": _make_win_path(toolchain, makensis_dir[0].path),
            "LANG": "en_US.UTF-8",
            "LC_ALL": "en_US.UTF-8",
            "LC_CTYPE": "en_US.UTF-8",
        },
        use_default_shell_env = False,
    )

    return [
        DefaultInfo(
            files = depset([outfile]),
            runfiles = ctx.runfiles(files = [outfile])
        )
    ]

def _name_to_displayname(val):
    fin = ""
    for v in val.split("_"):
        v = v.strip().capitalize()
        if len(v) == 0:
            continue
        if len(fin) == 0:
            fin = fin + v
            continue
        fin = fin + " " + v
    return fin

def _add_dep_key(deps, rev_deps, source, dest):
    if source not in deps:
        deps[source] = set()
    if dest not in rev_deps:
        rev_deps[dest] = set()

    deps[source].add(dest)
    rev_deps[dest].add(source)

def _build_flat_dependency_list(verticies):
    deps = {}
    rev_deps = {}

    for key in verticies:
        v = verticies[key]
        if NsisComponentInfo not in v:
            continue

        cc = v[NsisComponentInfo]

        # Add initial A -> B and B -> A mappings for all (A,B) = (component,
        # dependency)
        for dep in cc.dependencies:
            cc_d = dep[NsisComponentInfo]
            _add_dep_key(deps, rev_deps, cc.name, cc_d.name)

            cc_d = dep[NsisComponentInfo]
            if cc_d.name not in deps:
                continue

            for cc_d_d in deps[cc_d.name]:
                _add_dep_key(deps, rev_deps, cc.name, cc_d_d)


        if cc.name not in rev_deps:
            continue

        for parent in rev_deps[cc.name]:
            for curr_deps in deps[cc.name]:
                _add_dep_key(deps, rev_deps, parent, curr_deps)

    return deps, rev_deps


def _build_recursive_structure(inst_ctx, toolchain, inst_cat):
    verticies = {}
    edges = []

    for dep in inst_ctx.attr.components:
        edges.append({_EDGE_PARENT_KEY: None, _EDGE_CHILD_KEY: dep})
        if NsisComponentInfo in dep:
            cmp = dep[NsisComponentInfo]
            verticies[cmp.name] = dep
        elif NsisComponentGroupInfo in dep:
            grp = dep[NsisComponentGroupInfo]
            edges = edges + grp.components
        else:
            fail("invalid providers")


    edges_map = {}
    data_components = []
    data_groups = []
    next_stack = []

    for cmp in edges:
        child = cmp[_EDGE_CHILD_KEY]
        parent = cmp[_EDGE_PARENT_KEY]

        child_name = ""
        if NsisComponentInfo in child:
            child_name = child[NsisComponentInfo].name
        elif NsisComponentGroupInfo in child:
            child_name = child[NsisComponentGroupInfo].name
        else:
            fail("invalid component target")
        verticies[child_name] = child

        if parent == None:
            next_stack.append((child_name, data_components, data_groups))
            edges_map[child_name] = set()
            continue

        parent_name = ""
        if NsisComponentInfo in parent:
            parent_name = parent[NsisComponentInfo].name
        elif NsisComponentGroupInfo in parent:
            parent_name = parent[NsisComponentGroupInfo].name
        else:
            fail("invalid component target")
        verticies[parent_name] = parent

        if parent_name in edges_map:
            edges_map[parent_name].add(child_name)
        else:
            edges_map[parent_name] = set([child_name])

    dep_lst, rev_dep_lst = _build_flat_dependency_list(verticies)

    n_edges = len(edges)
    n_vert = len(verticies)

    path_stack = []

    for i in range(n_edges * n_vert):
        if len(next_stack) == 0:
            break

        current, current_components_data, current_groups_data = next_stack.pop()

        path_stack.append(current)
        v = verticies[current]
        es = edges_map[current] if current in edges_map else {}

        next_components = []
        next_groups = []

        if NsisComponentGroupInfo in v:
            gdata = _get_group_ds(
                toolchain,
                v[NsisComponentGroupInfo],
                inst_cat,
            )

            gdata[_COMPONENT_GROUPS_KEY] = next_groups
            gdata[_COMPONENTS_KEY] = next_components
            current_groups_data.append(gdata)
        elif NsisComponentInfo in v:
            current_components_data.append(
                _get_component_ds(
                    toolchain,
                    v[NsisComponentInfo],
                    inst_cat,
                ),
            )

        for e in es:
            next_stack.append((e, next_components, next_groups))

    return (
        data_components,
        data_groups,
        [{
            "Component": k,
            "Dependencies": dep_lst[k] if k in dep_lst else [],
            "Dependants": rev_dep_lst[k] if k in rev_dep_lst else [],
        } for k, v in verticies.items() if NsisComponentInfo in v],
          #[{"Component": k,"Dependencies": v} for k, v in rev_dep_lst.items()],
    )

def _disabled_by_default(mode):
    if mode == "optional":
        return True
    return False

def _required(mode):
    if mode == "required" or mode == "hidden":
        return True
    return False

def _hidden(mode):
    if mode == "hidden":
        return True
    return False

def _get_installer_ds(ctx, toolchain):
    data = {
        "Name": str(ctx.attr.name),
        "Product": str(ctx.attr.product),
        "ProductPath": str(_always_make_win_path(ctx.attr.product_path)),
        "Vendor": str(ctx.attr.vendor),
        "VendorPath": str(_always_make_win_path(_vendor_path(ctx))),
        "Description": str(ctx.attr.description),
        "Copyright": str(ctx.attr.copyright),
        "LicenseFile": (
            str(_make_win_path(toolchain, ctx.attr.license_file.path))
            if ctx.attr.license_file != None
            else None
        ),
        "Version": str(ctx.attr.version),
        "Architecture": str(ctx.attr.arch),
        "ArchitectureIs64": (
            True
            if str(ctx.attr.arch) == "x86_64" or str(ctx.attr.arch) == "arm64"
            else False
        ),
        "InstallRoot": str(_always_make_win_path(ctx.attr.install_root)),
        "InstallPath": str(_always_make_win_path(ctx.attr.install_path)),
        "ExecutionLevel": str(ctx.attr.execution_level),
        "InstallTypes": [str(x) for x in ctx.attr.install_categories],
        "Compressor": str(ctx.attr.compressor),
        "CompressorDictSize": int(ctx.attr.compressor_dictsize),
        "Icon": (
            str(_make_win_path(toolchain, ctx.attr.icon.path))
            if ctx.attr.icon != None
            else None
        ),
        "HeaderImage": (
            str(_make_win_path(toolchain, ctx.attr.header_image.path))
            if ctx.attr.header_image != None
            else None
        ),
        "MenuImage": (
            str(_make_win_path(toolchain, ctx.attr.menu_image.path))
            if ctx.attr.menu_image != None
            else None
        ),
        "Outfile": str(ctx.attr.outfile),
        _COMPONENTS_KEY: [],
        _COMPONENT_GROUPS_KEY: [],
    }

    return data

def _get_group_ds(toolchain, group, inst_cat):
    dispname = group.display_name
    if dispname == None or len(dispname.strip()) == 0:
        dispname = _name_to_displayname(group.name)

    return {
        "Name": str(group.name),
        "DisplayName": str(dispname),
        "Description": str(group.description),
        "Expanded": bool(group.expanded),
        "Bold": bool(group.expanded),
        _COMPONENTS_KEY: [],
        _COMPONENT_GROUPS_KEY: [],
    }

def _get_component_ds(toolchain, component, inst_cat):
    dispname = component.display_name
    if dispname == None or len(dispname.strip()) == 0:
        dispname = _name_to_displayname(component.name)

    data = {
        "Name": str(component.name),
        "Directory": str(_always_make_win_path(component.directory)),
        "Service": bool(component.service),
        "ServiceArgs": " ".join(component.service_args),
        "ServiceDependencies": "\\".join(component.service_dependencies),
        "ServiceStartType": str(component.service_start_type),
        "SelectionMode": str(component.selection_mode),
        "DisabledByDefault": _disabled_by_default(component.selection_mode),
        "Required": _required(component.selection_mode),
        "IsHidden": _hidden(component.selection_mode),
        "DisplayName": str(dispname),
        "Description": str(component.description),
        "InstallCategories": " ".join([str(inst_cat.index(x) + 1) for x in component.install_categories]),
        "Files": [],
        "Directories": [],
        "Dependencies": [str(x[NsisComponentInfo].name) for x in component.dependencies],
        "Shortcuts": [],
    }
    if component.service_executable != None:
        f = component.service_executable[DefaultInfo].files.to_list()[0]

        data["ServiceExecutable"] = {
            "Name": _always_make_win_path(f.basename),
            "Source": _make_win_path(toolchain, f.path),
        }

    for file in component.shortcuts:
        data["Shortcuts"].append({
            "Name": str(_always_make_win_path(toolchain, file.basename)),
            "Source": str(_make_win_path(toolchain, file.path)),
        })

    for file in component.srcs.to_list():
        if file.is_directory:
            data["Directories"].append(
                str(_make_win_path(toolchain, file.path)))
        else:
            data["Files"].append({
                "Name": str(_always_make_win_path(file.basename)),
                "Source": str(_make_win_path(toolchain, file.path)),
            })

    return data

def _vendor_path(ctx):
    if ctx.attr.vendor_path == None or ctx.attr.vendor_path == "":
        return ctx.attr.vendor
    return ctx.attr.vendor_path

def _build_data_structure(ctx, toolchain):

    inst_data = _get_installer_ds(ctx, toolchain)
    inst_cat = ctx.attr.install_categories

    cmps, grps, deps = _build_recursive_structure(ctx, toolchain, inst_cat)

    inst_data[_COMPONENTS_KEY] = cmps
    inst_data[_COMPONENT_GROUPS_KEY] = grps
    inst_data[_COMPONENT_DEPS_KEY] = deps

    return inst_data

def _all_files_component_list(lst):
    transitive = []
    for dep in lst:
        if NsisComponentInfo in dep:
            cmp = dep[NsisComponentInfo]
            transitive.append(_all_files_component(cmp))
        elif NsisComponentGroupInfo in dep:
            grp = dep[NsisComponentGroupInfo]
            transitive.append(_all_files_group(grp))
        else:
            fail("provided dependency is not a component or a component group.")

    return depset(transitive = transitive)


def _all_files_group(group):
    transitive = []
    for d in group.components:
        child = d[_EDGE_CHILD_KEY]

        if NsisComponentInfo in child:
            cmp = child[NsisComponentInfo]
            transitive.append(_all_files_component(cmp))
        elif NsisComponentGroupInfo in child:
            continue
        else:
            fail("provided dep is not a component or a group")

    return depset(transitive = transitive)

def _all_files_component(cmp):
    srcs = depset()
    if cmp.service_executable != None:
        svcexe = cmp.service_executable[DefaultInfo]
        srcs = depset(
            transitive = [
                srcs,
                svcexe.files,
            ],
        )
    srcs = depset(
        direct = [x[DefaultInfo].files for x in cmp.shortcuts],
        transitive = [
            cmp.srcs,
            srcs,
        ],
    )
    return srcs

def _all_files(ctx):
    srcs = depset(
        direct = [x for x in [
            ctx.attr.license_file,
            ctx.attr.icon,
            ctx.attr.header_image,
            ctx.attr.menu_image,
        ] if x != None],
    )

    srcs = depset(
        transitive = [
            _all_files_component_list(ctx.attr.components),
            srcs,
        ],
    )

    return srcs

def _render_file(ctx, tmpl, data):
    hs = "{}{}".format(hash(ctx.attr.name), hash(tmpl.path))
    datafile = ctx.actions.declare_file("data-{}.json".format(hs))

    ctx.actions.write(
        output = datafile,
        content = json.encode(data),
        mnemonic = "Render Tpl {} - Data File".format(tmpl.short_path),
    )

    outname = "nsistmpl-{}.nsi".format(hs)

    renderedtmpl = ctx.actions.declare_file(str(outname))

    args = ctx.actions.args()
    args.add("--missing-key")
    args.add("error")
    args.add("--file")
    args.add(str(tmpl.path))
    args.add("--datasource")
    args.add("in={}".format(str(datafile.path)))
    args.add("--out")
    args.add(str(renderedtmpl.path))

    inputs = depset(direct = [datafile, tmpl])

    ctx.actions.run(
        mnemonic = "RenderNsiTemplate",
        progress_message = "Rendering Tpl {} - Rendering".format(tmpl.short_path),
        executable = ctx.executable._gomplate,
        arguments = [args],
        inputs = inputs,
        tools = [ctx.executable._gomplate],
        outputs = [renderedtmpl],
        use_default_shell_env = False,
    )

    return renderedtmpl

def _build_rendered_templates(ctx, toolchain):
    data = _build_data_structure(ctx, toolchain)

    script = _render_file(ctx, ctx.file._template, data)
    option = _render_file(ctx, ctx.file._template_options, data)

    return {"Script": script, "Options": option}

def _nsis_installer_impl(ctx):
    toolchain = ctx.toolchains[_NSIS_TOOLCHAIN_TYPE].nsis

    srcs = _all_files(ctx)
    values = _build_rendered_templates(ctx, toolchain)

    return _makensis(ctx, toolchain, values["Script"], values["Options"], srcs) + [
        NsisInstallerInfo(
            name = ctx.attr.name,
            product = ctx.attr.product,
            product_path = ctx.attr.product_path,
            vendor = ctx.attr.vendor,
            vendor_path = ctx.attr.vendor_path,
            description = ctx.attr.description,
            copyright = ctx.attr.copyright,
            license_file = ctx.attr.license_file,
            version = ctx.attr.version,
            install_root = ctx.attr.install_root,
            install_path = ctx.attr.install_path,
            execution_level = ctx.attr.execution_level,
            compressor = ctx.attr.compressor,
            compressor_dictsize = ctx.attr.compressor_dictsize,
            icon = ctx.attr.icon,
            header_image = ctx.attr.header_image,
            menu_image = ctx.attr.menu_image,
            install_categories = ctx.attr.install_categories,
            defines = ctx.attr.defines,
            verbosity = ctx.attr.verbosity,
            no_config = ctx.attr.no_config,
            components = ctx.attr.components,
            outfile = ctx.attr.outfile,
            arch = ctx.attr.arch,
        ),
    ]

nsis_installer = rule(
    implementation = _nsis_installer_impl,
    cfg = windows_source_transition,

    attrs = {
        "product": attr.string(
            mandatory = True,
            doc = "The display name of the software being packaged.",
        ),
        "product_path": attr.string(
            mandatory = True,
            doc = "The path name of the software being packaged.",
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
The optional path to use below the root by default. E.g. Company\\Vendor.
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
            doc = "The icon to use for the installer."
        ),
        "header_image": attr.label(
            allow_single_file = [".bmp"],
            mandatory = False,
            doc = "The image to use for the installer header.",
        ),
        "menu_image": attr.label(
            allow_single_file = [".bmp"],
            mandatory = False,
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
        "no_config": attr.bool(
            mandatory = False,
            default = False,
            doc = "Pass /NOCONFIG to disable loading nsiconf.nsi",
        ),
        "components": attr.label_list(
            mandatory = False,
            allow_empty = False,
            doc = "The list of components and component groups to install.",
            providers = [
                [NsisComponentInfo],
                [NsisComponentGroupInfo],
            ],
        ),
        "outfile": attr.string(
            mandatory = False,
            default = "",
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
        ),
        "_template": attr.label(
            default = Label("//nsis/private/templates:NSIS.template.nsi"),
            allow_single_file = True,
        ),
        "_template_options": attr.label(
            default = Label("//nsis/private/templates:NSIS.InstallOptions.template.ini"),
            allow_single_file = True,
        ),
        "_gomplate": attr.label(
            default = "@gomplate//:gomplate",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = [
        _NSIS_TOOLCHAIN_TYPE,
    ],
    doc = "Builds a windows installer .exe using NSIS.",
)
