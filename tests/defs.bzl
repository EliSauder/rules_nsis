load("@rules_python//python:py_test.bzl", "py_test")
load("@bazel_skylib//lib:shell.bzl", "shell")
load(
    "//nsis/private:defs.bzl",
    "NsisInstallerInfo", "NsisComponentInfo", "NsisComponentGroupInfo",
)

def _nsis_test_config_impl(ctx):
    inst = ctx.attr.installer[NsisInstallerInfo]

    outfile = ""
    if inst.outfile:
        outfile = inst.outfile
    elif inst.vendor:
        outfile = "{} {} Setup.exe".format(inst.vendor, inst.product)
    else:
        outfile = "{} Setup.exe".format(inst.product)

    files = set()
    services = dict()

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

    test_config = {
        "installer_args": [],
        "expected_files": files,
        "expected_installer_name": outfile,
        "expected_product_path": inst.product_path or "",
        "expected_vendor_path": inst.vendor_path or "",
        "expected_install_path": inst.install_path or "",
        "expected_bitwidth": arch,
        "expected_execution_level": inst.execution_level,
        "expected_services": services,
        "expected_eventlog": inst.eventlog,
    }

    outf = ctx.actions.declare_file(ctx.attr.name + ".json")

    ctx.actions.write(
        output = outf,
        content = json.encode(test_config),
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
    },
    outputs = {
        "out": "%{name}.json"
    },
)

def _nsis_installer_test_impl(name, visibility, installer, **kwargs):

    _nsis_test_config(
        name = name + "_config",
        installer = installer,
        visibility = ["//visibility:private"],
    )

    f = ":{}_config".format(name)

    tags = kwargs.pop("tags", [])

    py_test(
        name = name,
        srcs = [":nsis_install_test.py"],
        main = ":nsis_install_test.py",
        data = [installer, f],
        args = [
            "$(rlocationpath {})".format(installer),
            "$(rlocationpath {})".format(f),
        ],
        target_compatible_with = ["@platforms//os:windows"],
        timeout = "short",
        visibility = visibility,
        tags = tags,
        deps = [
            "@pypi_dev//psutil",
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
    },
)
