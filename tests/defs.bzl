load("@rules_python//python:py_test.bzl", "py_test")
load("@bazel_skylib//lib:shell.bzl", "shell")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(
    "//nsis/private:defs.bzl",
    "NsisInstallerInfo",
    "NsisComponentInfo",
    "NsisComponentGroupInfo",
    "NsisEventLogSourceInfo",
)
load("@aspect_bazel_lib//lib:paths.bzl", "to_rlocation_path")

def _uninstall_tree_fixture_impl(ctx):
    tree = ctx.actions.declare_directory(ctx.label.name + ".dir")
    ctx.actions.run_shell(
        inputs = [ctx.file.src],
        outputs = [tree],
        arguments = [tree.path, ctx.file.src.path],
        command = """
mkdir -p "$1/nested"
cp "$2" "$1/README.md"
cp "$2" "$1/nested/file with spaces.txt"
cp "$2" "$1/"'${LITERAL}.txt'
""",
    )
    return [DefaultInfo(files = depset([tree]))]

uninstall_tree_fixture = rule(
    implementation = _uninstall_tree_fixture_impl,
    attrs = {"src": attr.label(allow_single_file = True, mandatory = True)},
)

def _signing_env_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [action for action in analysistest.target_actions(env) if action.mnemonic == "MakeNSIS"]
    asserts.equals(env, 1, len(actions))
    if actions:
        action_env = actions[0].env
        asserts.equals(env, "test-password", action_env.get("RULES_NSIS_TEST_PASSWORD"))
        asserts.equals(env, "en_US.UTF-8", action_env.get("LANG"))
        asserts.true(env, "NSISDIR" in action_env)
        asserts.true(env, "RUNFILES_DIR" in action_env)
    return analysistest.end(env)

signing_env_test = analysistest.make(
    _signing_env_test_impl,
    config_settings = {
        "//command_line_option:action_env": ["RULES_NSIS_TEST_PASSWORD=test-password"],
    },
)

def _get_installer_test_details(ctx, inst, target, unselected_components = []):
    if not inst.testable:
        fail("installer {} must set testable = True to be used by nsis_installer_test".format(inst.name))

    outfile = ""
    if inst.outfile:
        outfile = inst.outfile
    elif inst.vendor:
        outfile = "{} {} Setup.exe".format(inst.vendor, inst.product)
    else:
        outfile = "{} Setup.exe".format(inst.product)

    files = set()
    ds = dict()
    services = dict()
    elsrcs =dict()
    path_dirs = []
    absent_files = set()
    absent_path_dirs = []
    shortcuts = []
    components = {}

    for dep in inst.components:
        if NsisComponentInfo in dep:
            components[dep[NsisComponentInfo].name] = dep[NsisComponentInfo]
        elif NsisComponentGroupInfo in dep:
            for edge in dep[NsisComponentGroupInfo].components:
                for node in [edge["parent"], edge["child"]]:
                    if node != None and NsisComponentInfo in node:
                        components[node[NsisComponentInfo].name] = node[NsisComponentInfo]
        else:
            fail("not component or group", dep)

    if not components:
        fail("no components defined")
    for name in unselected_components:
        if name not in components:
            fail("unknown unselected component: " + name)

    for cmp in components.values():
        selected = cmp.name not in unselected_components
        component_files = files if selected else absent_files
        for f in cmp.srcs.to_list():
            # Tree artifacts cannot be enumerated until execution. Use
            # must_have_files for their contents.
            if not f.is_directory:
                component_files.add("{}\\{}".format(cmp.directory, f.basename) if cmp.directory else f.basename)
        if cmp.add_to_path:
            (path_dirs if selected else absent_path_dirs).append(cmp.directory)
        for shortcut in cmp.shortcuts:
            shortcuts.append({
                "component": cmp.name,
                "selected": selected,
                "link_name": shortcut.link_name,
                "start_menu": shortcut.start_menu,
                "desktop": shortcut.desktop,
                "start_menu_subfolder": shortcut.start_menu_subfolder,
            })
        if not selected:
            continue
        for d in cmp.dirs:
            ds[d.path] = d
        if cmp.eventlog != None and NsisEventLogSourceInfo in cmp.eventlog:
            elg = cmp.eventlog[NsisEventLogSourceInfo]
            elsrcs["{}/{}".format(elg.key, elg.source)] = elg
        if cmp.service:
            services[cmp.name] = {
                "start_type": cmp.service_start_type,
                "display_name": "{}{}{}".format(
                    inst.vendor + " " if inst.vendor else "",
                    inst.product + " ",
                    cmp.display_name,
                ),
                "description": cmp.description if cmp.description else "",
                "executable": "{}{}".format(
                    (cmp.directory + "\\" if cmp.directory else ""),
                    cmp.service_executable[DefaultInfo].files.to_list()[0].basename,
                ),
                "args": cmp.service_args,
            }

    bitwidth = "64" if inst.arch in ["x86_64", "arm64"] else "32"

    instf = target[DefaultInfo].files.to_list()[0]

    return {
        "installer_path": to_rlocation_path(ctx, instf),
        "installer_args": [],
        "expected_file_contents": {},
        "expected_uninstall_file_contents": {},
        "expected_files": files,
        "absent_files": [f for f in absent_files if f not in files],
        "component_names": list(components),
        "expected_shortcuts": shortcuts,
        "expected_dirs": ds,
        "expected_installer_name": outfile,
        "expected_uninstaller_name": inst.uninstaller_name,
        "expected_product_path": inst.product_path or "",
        "expected_product": inst.product or "",
        "expected_vendor_path": inst.vendor_path or "",
        "expected_vendor": inst.vendor or "",
        "expected_install_path": inst.install_path or "",
        "expected_install_root": inst.install_root or "",
        "expected_id": inst.id or "",
        "expected_bitwidth": bitwidth,
        "expected_icon": inst.icon != None,
        "expected_execution_level": inst.execution_level,
        "expected_services": services,
        "expected_eventlog": elsrcs,
        "expected_path_dirs": path_dirs,
        "absent_path_dirs": [d for d in absent_path_dirs if d not in path_dirs],
        "expected_installer_exitcode": 0,
    }

def _nsis_test_config_impl(ctx):
    inst = ctx.attr.installer[NsisInstallerInfo]
    must_have_files = ctx.attr.must_have_files
    must_have_dirs = ctx.attr.must_have_dirs
    install_first_and_remove = ctx.attr.install_first_and_remove

    det = _get_installer_test_details(ctx, inst, ctx.attr.installer, ctx.attr.unselected_components)

    files = set()
    for p in must_have_files:
        files.add(p)
    for f in det["expected_files"]:
        files.add(f)
    det["expected_files"] = files

    dirs = dict()
    for p in must_have_dirs:
        dirs[p] = None
    for k, v in det["expected_dirs"].items():
        dirs[k] = v
    det["expected_dirs"] = dirs

    preinstall = []
    for i in install_first_and_remove:
        inst = i[NsisInstallerInfo]
        tmp = _get_installer_test_details(ctx, inst, i)
        preinstall.append(tmp)
    det["install_first_and_remove"] = preinstall

    det["expected_installer_exitcode"] = int(ctx.attr.expected_installer_exitcode)
    det["installer_args"] = ctx.attr.installer_args
    det["reinstall_without_dir"] = ctx.attr.reinstall_without_dir
    det["default_install_dir"] = ctx.attr.default_install_dir
    det["expected_file_contents"] = ctx.attr.expected_file_contents
    det["expected_uninstall_file_contents"] = ctx.attr.expected_uninstall_file_contents
    det["expected_options"] = ctx.attr.expected_options
    det["expected_option_types"] = ctx.attr.expected_option_types
    det["absent_options"] = ctx.attr.absent_options
    det["shortcut_options"] = ctx.attr.shortcut_options

    outf = ctx.actions.declare_file(ctx.attr.name + ".json")

    ctx.actions.write(
        output = outf,
        content = json.encode(det),
    )

    return [
        DefaultInfo(files = depset([outf]))
    ]

_nsis_test_config = rule(
    implementation = _nsis_test_config_impl,
    attrs = {
        "installer": attr.label(
            mandatory = True,
            providers = [
                NsisInstallerInfo,
                DefaultInfo,
            ],
        ),
        "must_have_files": attr.string_list(
            default = [],
        ),
        "must_have_dirs": attr.string_list(
            default = [],
        ),
        "install_first_and_remove": attr.label_list(
            default = [],
            providers = [
                NsisInstallerInfo,
                DefaultInfo,
            ],
        ),
        "expected_installer_exitcode": attr.int(
            default = 0,
        ),
        "installer_args": attr.string_list(default = []),
        "reinstall_without_dir": attr.bool(default = False),
        "default_install_dir": attr.bool(default = False),
        "expected_file_contents": attr.string_dict(default = {}),
        "expected_uninstall_file_contents": attr.string_dict(default = {}),
        "unselected_components": attr.string_list(default = []),
        "expected_options": attr.string_list_dict(default = {}),
        "expected_option_types": attr.string_dict(default = {}),
        "absent_options": attr.string_list(default = []),
        "shortcut_options": attr.string_dict(default = {}),
    },
    outputs = {
        "out": "%{name}.json"
    },
)

def _nsis_installer_test_impl(name, visibility, installer, must_have_files, must_have_dirs, install_first_and_remove, expected_installer_exitcode, installer_args, reinstall_without_dir, default_install_dir, expected_file_contents, expected_uninstall_file_contents, unselected_components, expected_options, expected_option_types, absent_options, shortcut_options, timeout, target_compatible_with, **kwargs):
    v = []
    if install_first_and_remove != None:
        v.append(install_first_and_remove)

    _nsis_test_config(
        name = name + "_config",
        installer = installer,
        must_have_files = must_have_files,
        must_have_dirs = must_have_dirs,
        install_first_and_remove = v,
        visibility = ["//visibility:private"],
        expected_installer_exitcode = expected_installer_exitcode,
        installer_args = installer_args,
        reinstall_without_dir = reinstall_without_dir,
        default_install_dir = default_install_dir,
        expected_file_contents = expected_file_contents,
        expected_uninstall_file_contents = expected_uninstall_file_contents,
        unselected_components = unselected_components,
        expected_options = expected_options,
        expected_option_types = expected_option_types,
        absent_options = absent_options,
        shortcut_options = shortcut_options,
    )

    f = ":{}_config".format(name)

    tags = kwargs.pop("tags", [])

    py_test(
        name = name,
        srcs = [
            ":nsis_install_test.py",
            ":__init__.py",
        ],
        main = ":nsis_install_test.py",
        data = [installer, f] + v,
        args = [
            "$(rlocationpath {})".format(installer),
            "$(rlocationpath {})".format(f),
        ],
        target_compatible_with = ["@platforms//os:windows"] + target_compatible_with,
        timeout = timeout,
        visibility = visibility,
        tags = tags,
        deps = [
            "@rules_nsis_pypi_dev//psutil",
            "@rules_python//python/runfiles",
        ],
        **kwargs,
    )


nsis_installer_test = macro(
    implementation = _nsis_installer_test_impl,
    attrs = {
        "installer": attr.label(
            mandatory = True,
            configurable = False,
            providers = [
                NsisInstallerInfo,
                DefaultInfo,
            ],
        ),
        "must_have_files": attr.string_list(
            mandatory = False,
            default = [],
        ),
        "must_have_dirs": attr.string_list(
            mandatory = False,
            default = [],
        ),
        "install_first_and_remove": attr.label(
            mandatory = False,
            default = None,
            configurable = False,
            providers = [
                NsisInstallerInfo,
                DefaultInfo,
            ],
        ),
        "expected_installer_exitcode": attr.int(
            mandatory = False,
            default = 0,
        ),
        "installer_args": attr.string_list(
            mandatory = False,
            default = [],
            doc = "Extra installer arguments, e.g. /O:page.key=value.",
        ),
        "reinstall_without_dir": attr.bool(
            mandatory = False,
            default = False,
            configurable = False,
            doc = "Install into the install root first, then run the tested install without /D= so it must reuse the stored install directory.",
        ),
        "default_install_dir": attr.bool(
            mandatory = False,
            default = False,
            configurable = False,
            doc = "Install without /D= and expect the installer's default InstallDir, derived from install_root, execution_level, arch and the product paths.",
        ),
        "expected_file_contents": attr.string_dict(
            mandatory = False,
            default = {},
            doc = "Install-root relative files and the content they must have after the install.",
        ),
        "expected_uninstall_file_contents": attr.string_dict(
            mandatory = False,
            default = {},
            doc = "Files, relative to the test temp dir (the uninstaller's $EXEDIR), and the content they must have after the uninstall.",
        ),
        "target_compatible_with": attr.label_list(
            mandatory = False,
            default = [],
        ),
        "unselected_components": attr.string_list(
            default = [],
            doc = "Components expected to be unselected; their unique files and PATH entries must be absent.",
        ),
        "expected_options": attr.string_list_dict(
            default = {},
            doc = "Persisted <page>.<key> values (single item for scalars).",
        ),
        "expected_option_types": attr.string_dict(
            default = {},
            doc = "Registry backing kinds: bool, int32, int64, list or string (default).",
        ),
        "absent_options": attr.string_list(
            default = [],
            doc = "Option values that must not be persisted, such as passwords.",
        ),
        "shortcut_options": attr.string_dict(
            default = {},
            doc = "Expected enabled, start_menu, desktop and start_menu_folder shortcut options.",
        ),
        "timeout": attr.string(default = "short", configurable = False),
    },
)
