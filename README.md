# NSIS Rules for Bazel

## Contents
1. [Overview](#Overview)
    1. [Usage](#Usage)
    2. [Features](#Features)

## Overview

Aims to support creating a NSIS installer through bazel; inspired by CPack.

### Usage
#### Bzlmod

```bzl
bazel_dep(name = "rules_nsis", version = "<version>")
```

#### Bzlmod With Toolchain

```bzl
bazel_dep(name = "rules_nsis", version = "<version>")

nsis = use_extension("@rules_nsis//nsis:extensions.bzl", "nsis")
# Currently 3.11 is the only supported version.
nsis.executable(name = "nsis", version = "3.11")

use_repo(nsis, "nsis_tool", "nsis_toolchains")

register_toolchains("@nsis_toolchains//:toolchain")
```

#### Define Installer

For a full list of options, see: https://registry.bazel.build/docs/rules_nsis

```bzl
load("//nsis:defs.bzl", "nsis_component", "nsis_component_group", "nsis_installer")

nsis_component(
    name = "my_minimal_component",
    srcs = [":my_files"],
    selection_mode = "default",
)

nsis_component_group(
    name = "my_minimal_group",
    components = [
        ":my_minimal_component"
    ],
)

nsis_installer(
    name = "my_minimal_installer",
    components = [
        ":my_minimal_group",
        ":my_minimal_component",
    ],
    product = "My Minimal Product",
    product_path = "My Minimal Product",
)
```

### Features

- [x] NSIS Toolchain for cross-platform use.
- [x] Define installer attributes (version, product, etc.).
- [x] Support Components and Component Groups.
- [x] Install windows Services (uses `sc.exe`).
- [x] Dependency Based Selections.
- [ ] StartMenu Entries. \[Help Wanted]
- [ ] Desktop Shortcuts. \[Help Wanted]
- [ ] Update Path. \[Help Wanted]
- [ ] Set Environment Variables. \[Help Wanted]
- [ ] Don't prompt for components if all hidden or all required.
- [ ] Enable adding files directly to installer (add to hidden section).
