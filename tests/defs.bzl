load("@rules_python//python:defs.bzl", "py_test")
load("//nsis/private:defs.bzl", "NsisInstallerInfo")

def nsis_installer_test(
    name,
    installer,
    expected_installer_name,
    expected_files,
    expected_product_path = None,
    expected_vendor_path = None,
    expected_install_path = None,
    expected_bitwidth = "64",
    expected_execution_level = "admin",
    installer_args = []):

    if expected_product_path == None and expected_install_path == None:
        fail("one of product path or install path must not be None")

    if expected_execution_level != "admin" and expected_execution_level != "user":
        fail("invalid execution level, must be admin or user")

    if expected_bitwidth != "32" and expected_bitwidth != "64":
        fail("invalid bitwidth, must be 32 or 64")

    test_config = {
        "installer_args": [str(x) for x in (installer_args or [])],
        "expected_files": [str(x) for x in expected_files],
        "expected_installer_name": str(expected_installer_name),
        "expected_product_path": expected_product_path,
        "expected_vendor_path": str(expected_vendor_path or ""),
        "expected_install_path": expected_install_path,
        "expected_bitwidth": str(expected_bitwidth or "64"),
        "expected_execution_level": str(expected_execution_level or "admin"),
    }

    f = name + "_config.json"

    native.genrule(
        name = name + "_config",
        outs = [f],
        cmd = """
cat > "$@" << EOF
{}
EOF
""".format(json.encode(test_config)),
    )

    py_test(
        name = name,
        srcs = [":nsis_install_test.py"],
        main = ":nsis_install_test.py",
        data = [installer, f],
        args = [
            "$(location {})".format(installer),
            "$(location {})".format(f),
        ],
        target_compatible_with = ["@platforms//os:windows"],
        timeout = "short",
        visibility = ["//visibility:public"],
    )
