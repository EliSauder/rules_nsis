load("@rules_python//python:py_test.bzl", "py_test")
load("@bazel_skylib//lib:shell.bzl", "shell")
load(
    "//nsis/private:defs.bzl",
    "NsisInstallerInfo",
    "NsisComponentInfo",
    "NsisComponentGroupInfo",
    "NsisEventLogSourceInfo",
)
load("@aspect_bazel_lib//lib:paths.bzl", "to_rlocation_path")

def _get_installer_test_details(ctx, inst, target):
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

    numcomp = 0

    for dep in inst.components:
        if NsisComponentInfo in dep:
            numcomp = numcomp + 1
            cmp = dep[NsisComponentInfo]
            for f in cmp.srcs.to_list():
                if cmp.directory:
                    files.add("{}\\{}".format(cmp.directory, f.basename))
                else:
                    files.add("{}".format(f.basename))
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

        elif NsisComponentGroupInfo in dep:
            grp = dep[NsisComponentGroupInfo]
            for edge in grp.components:
                chld = edge["child"]

                if NsisComponentInfo not in chld:
                    continue

                cmp = chld[NsisComponentInfo]
                numcomp = numcomp + 1

                for f in cmp.srcs.to_list():
                    if cmp.directory:
                        files.add("{}\\{}".format(cmp.directory, f.basename))
                    else:
                        files.add("{}".format(f.basename))
        else:
            fail("not component or group", dep)

    if numcomp == 0:
        fail("no components defined")

    arch = ""
    if inst.arch in ["x86_64", "arm64"]:
        arch = "64"
    else:
        arch = "32"

    instf = target[DefaultInfo].files.to_list()[0]

    return {
        "installer_path": to_rlocation_path(ctx, instf),
        "installer_args": [],
        "expected_files": files,
        "expected_dirs": ds,
        "expected_installer_name": outfile,
        "expected_product_path": inst.product_path or "",
        "expected_product": inst.product or "",
        "expected_vendor_path": inst.vendor_path or "",
        "expected_vendor": inst.vendor or "",
        "expected_install_path": inst.install_path or "",
        "expected_id": inst.id or "",
        "expected_bitwidth": arch,
        "expected_execution_level": inst.execution_level,
        "expected_services": services,
        "expected_eventlog": elsrcs,
        "expected_installer_exitcode": 0,
    }

def _nsis_test_config_impl(ctx):
    inst = ctx.attr.installer[NsisInstallerInfo]
    must_have_files = ctx.attr.must_have_files
    must_have_dirs = ctx.attr.must_have_dirs
    install_first_and_remove = ctx.attr.install_first_and_remove

    det = _get_installer_test_details(ctx, inst, ctx.attr.installer)

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
    },
    outputs = {
        "out": "%{name}.json"
    },
)

def _nsis_installer_test_impl(name, visibility, installer, must_have_files, must_have_dirs, install_first_and_remove, expected_installer_exitcode, target_compatible_with, **kwargs):
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
        timeout = "short",
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
        "target_compatible_with": attr.label_list(
            mandatory = False,
            default = [],
        ),
    },
)
