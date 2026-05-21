platform(
    name = "windows_x64",
    constraint_values = [
        "@platforms//os:windows",
        "@platforms//cpu:x86_64",
    ],
)

platform(
    name = "windows_x32",
    constraint_values = [
        "@platforms//os:windows",
        "@platforms//cpu:x86_32",
    ],
)

platform(
    name = "windows_arm64",
    constraint_values = [
        "@platforms//os:windows",
        "@platforms//cpu:arm64",
    ],
)

platform(
    name = "windows_arm32",
    constraint_values = [
        "@platforms//os:windows",
        "@platforms//cpu:arm",
    ],
)
