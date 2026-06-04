_PLATFORMS = {
    ("darwin", "amd64"): {
        "url": "https://github.com/hairyhenderson/gomplate/releases/download/v5.1.0/gomplate_darwin-amd64",
        "sha256": "11a1e205a55703797bfdf66ca820ddbe5007db86f96f441d8db7f0d734633b7a",
        "bin": "gomplate_darwin-amd64",
        "platform": ["@platforms//os:macos", "@platforms//cpu:x86_64"],
    },
    ("darwin", "arm64"): {
        "url": "https://github.com/hairyhenderson/gomplate/releases/download/v5.1.0/gomplate_darwin-arm64",
        "sha256": "19641d717b9e82ce12f65fbca6408f804f8cdbe8ba5975567f19198cfd6a2aec",
        "bin": "gomplate_darwin-arm64",
        "platform": ["@platforms//os:macos", "@platforms//cpu:arm64"],
    },
    ("linux", "amd32"): {
        "url": "https://github.com/hairyhenderson/gomplate/releases/download/v5.1.0/gomplate_linux-386",
        "sha256": "e93e3bbbee88d88158ebdee419e0654c603bcd968437ef5ebafd3809cdde4880",
        "bin": "gomplate_linux-386",
        "platform": ["@platforms//os:linux", "@platforms//cpu:x86_32"],
    },
    ("linux", "amd64"): {
        "url": "https://github.com/hairyhenderson/gomplate/releases/download/v5.1.0/gomplate_linux-amd64",
        "sha256": "b48d0eae35540fa0dff0c69372b59a6f8f146e3cf5df77b775670894e14b3315",
        "bin": "gomplate_linux-amd64",
        "platform": ["@platforms//os:linux", "@platforms//cpu:x86_64"],
    },
    ("linux", "arm64"): {
        "url": "https://github.com/hairyhenderson/gomplate/releases/download/v5.1.0/gomplate_linux-arm64",
        "sha256": "7677c41d171d25f87a0890201f6b261729c4bf1ab793237dbb33a4c1b0585c07",
        "bin": "gomplate_linux-arm64",
        "platform": ["@platforms//os:linux", "@platforms//cpu:arm64"],
    },
    ("windows", "amd32"): {
        "url": "https://github.com/hairyhenderson/gomplate/releases/download/v5.1.0/gomplate_windows-386.exe",
        "sha256": "d0e9129305b52e7a7893906ed5f49b1267cb2b8a4043f566ef648f3e1ba79cab",
        "bin": "gomplate_windows-386.exe",
        "platform": ["@platforms//os:windows", "@platforms//cpu:x86_32"],
    },
    ("windows", "amd64"): {
        "url": "https://github.com/hairyhenderson/gomplate/releases/download/v5.1.0/gomplate_windows-amd64.exe",
        "sha256": "4e089caf4aa57bdbb0017516ad65f74150cc47fd462771778c3b2ee18e3a95b3",
        "bin": "gomplate_windows-amd64.exe",
        "platform": ["@platforms//os:windows", "@platforms//cpu:x86_64"],
    },
}

def _gomplate_repo_impl(ctx):
    os_name = str(ctx.os.name.lower())
    arch = str(ctx.os.arch.lower())

    # Normalize architecture naming
    if arch in ["x86_64", "amd64"]:
        arch = "amd64"
    elif arch in ["x86", "amd32", "x86_32", "i386", "386"]:
        arch = "amd32"
    elif arch in ["aarch64", "arm64"]:
        arch = "arm64"
    else:
        fail("Unsupported architecture: {}".format(arch))

    if "linux" in os_name:
        platform = "linux"
        ext = ""
    elif "windows" in os_name:
        platform = "windows"
        ext = ".exe"
    elif "darwin" in os_name:
        platform = "darwin"
        ext = ""
    elif "mac os x" in os_name:
        platform = "darwin"
        ext = ""
    else:
        fail("Unsupported OS: {}".format(os_name))

    key = (platform, arch)
    if key not in _PLATFORMS:
        fail("Unsupported platform {}".format(str(key)))

    info = _PLATFORMS[key]

    ctx.download(
        url = info["url"],
        output = info["bin"],
        sha256 = info["sha256"],
        executable = True,
    )

#exports_files(["{}"])
    # Create BUILD file
    ctx.file("BUILD.bazel", """
alias(
    name = "gomplate",
    actual = "{}",
    visibility = ["//visibility:public"],
)
""".format(info["bin"]))


gomplate_repository = repository_rule(
    implementation = _gomplate_repo_impl,
)
