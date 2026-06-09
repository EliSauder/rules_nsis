# NSIS Rules for Bazel

## Contents
1. [Overview](#Overview)
    1. [Usage](#Usage)
    2. [Features](#Features)
2. [Generated Installer Details](#Generated-Installer-Details)

## Overview

Adds rules for creating NSIS installers for bazel.

This project was originally inspired by CPack, but design and approach has
since started to diverged.

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

For installer examples, see the tests: [./tests/BUILD.bazel](./tests/BUILD.bazel).

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

## Generated Installer Details

- Unicode
- Uninstaller file name: `Uninstaller.exe`
- Writes to Windows Registry `Software\{{.PackagPath}}` or
  `Software\{{.VendorPath}}\{{.PackagePath}}` or `Software\{{.InstallPath}}`
  depending on what values are provided. Writes to subkeys:
    - InstallDir
- Adds uninstaller details to `Software\Microsoft\Windows\CurrentVersion\Uninstall\{{.}}`
  writes to the same package path as above. Writes to subkeys:
    - DisplayName
    - DisplayVersion
    - Publisher
    - UninstallString
    - NoRepair = 1 (Repair not supported)
    - NoModify = 1 (Modify not supported)
    - DisplayIcon
- Writes to `32` or `64` registry depending on arch selected.
- Asserts that the installer is being run on the correct architecture based
  on provided arch.
- Uses MUI for the UI.
- Logs to StdOut if run from a console.
- Ensures only one installer is running using a mutex.
- Installs and updates windows services using `sc.exe`
    - Will always attempt to stop the service before component section runs.
    - All component files are updated before the service is updated or created.
- When `/TESTID={{.TestId}}` is passed, will append TestId to the registry
  keys it uses. This is to handle race conditions while testing installers.

### Component Dependencies

Based on dependencies provided in each component, a dependency graph between
components is created and then embeded in the installer. In the component
selection screen the following behavior will be seen:

1. When a component is selected, all of its dependencies (including transitive
   dependencies) will also be selected.
2. When a component is unselected, the all of its dependencies (including
   transitive dependencies) will be unselected, unless:
   1. They were selected manually.
   2. They are dependend on by another component (either directly or transitively).
3. When a component is unselected, all dependents (either direct or transitive)
   will be unselected (even if they were selected manually).
