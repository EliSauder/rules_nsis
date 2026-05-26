load("@rules_python//python:defs.bzl", "py_test")

def nsis_installer_test(
    name,
    installer,
    installer_args,
    expected_installer_name,
    expected_files,
    tags = None,
    visibility = None):

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
            "$(location {})".format(installer)
            json.encode(config),
        ],
        tags = [
            "local",
            "requires-windows",
        ] + (tags or []),
        target_compatible_with = ["@platforms//os:windows"],
        visibility = visibility,
    )
