load("@rules_python//python:defs.bzl", "py_test")

def nsis_installer_test(
    name,
    installer,
    expected_installer_name,
    expected_files,
    installer_args = []):

    test_config = {
        "installer_args": [str(x) for x in (installer_args or [])],
        "expected_files": [str(x) for x in expected_files],
        "expected_installer_name": str(expected_installer_name),
    }

    py_test(
        name = name,
        srcs = [":nsis_install_test.py"],
        main = ":nsis_install_test.py",
        data = [installer],
        args = [
            "$(location {})".format(installer),
            json.encode(test_config),
        ],
        target_compatible_with = ["@platforms//os:windows"],
        timeout = "moderate",
        visibility = ["//visibility:public"],
    )
