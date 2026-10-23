# NSIS Rules for Bazel

## Contents
1. [Overview](#Overview)
    1. [Usage](#Usage)
    2. [Features](#Features)
2. [Options Pages](#Options-Pages)
3. [Command Line](#Command-Line)
4. [Shortcuts](#Shortcuts)
5. [Generated Installer Details](#Generated-Installer-Details)
6. [NSIS API Unit Testing](#nsis-api-unit-testing)

## Overview

Adds rules for creating NSIS installers for bazel.

This project was originally inspired by CPack, but design and approach has
since started to diverged.

### Usage

```bzl
bazel_dep(name = "rules_nsis", version = "<version>")

nsis = use_extension("@rules_nsis//nsis:extensions.bzl", "nsis")
# Currently 3.11 is the only supported version.
nsis.executable(name = "nsis", version = "3.11")

use_repo(nsis, "nsis_tool", "nsis_toolchains")

register_toolchains("@nsis_toolchains//:all")
```

The Windows x86 zlib dependency is downloaded from SourceForge first. If that
download fails, Bazel builds upstream zlib 1.3.1 from GitHub sources with a
Windows x86 platform transition and a pinned Zig compiler. It cross-compiles on
Linux/macOS and builds Windows binaries on Windows, producing a static library,
DLL, import library, headers, and license. Compilation failures are reported
normally; no bundled ZIP is used. The Windows bundle follows the layout in
[NSIS Appendix G](https://nsis.sourceforge.io/Docs/AppendixG.html).
Building native `makensis` on POSIX still requires native zlib development
headers and libraries, as before; the Windows bundle does not replace them.

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
- [x] Handle Stamping Installers
- [x] EventLog Registry Entries
- [x] Uninstall previous installs prior to install
- [x] StartMenu and Desktop Shortcuts (`nsis_shortcut`).
- [x] Options pages (`nsis_options_page`) with persisted values.
- [x] Installer command line: `/COMPONENTS`, `/INSTTYPE`, `/OPTIONS=`, `/O:`, `/HELP`.
- [ ] Update Path. \[Help Wanted]
- [ ] Set Environment Variables. \[Help Wanted]
- [ ] Don't prompt for components if all hidden or all required.
- [ ] Enable adding files directly to installer (add to hidden section).

### Signing

Set `signing_certificate` on `nsis_installer` to a
[`rules_signing`](https://github.com/EliSauder/rules_signing) certificate target.
If the certificate uses `password_env`, pass that variable to the build with
`--action_env=VARIABLE_NAME` (or `--action_env=VARIABLE_NAME=value`).
The installer action preserves the signing environment, including on Windows.

## Options Pages

An options page asks the user for values and hands them to your hooks. It is
built from three rules, all loaded from `//nsis:defs.bzl`:

- `nsis_option`: one control. `key` (default: the rule name) must match
  `[a-z][a-z0-9_]*`. Other attrs: `control`, `label_text`, `description`,
  `default`, `required`, `enabled_by`, `persist`, plus the control-specific
  `choices`, `multi_select`, `min`, `max`, `max_length`, `lines`, `filter`,
  `save`, `must_exist` and `address_types`. Attrs a control does not use are
  rejected at analysis time.
- `nsis_option_group`: a group box around `options`, with `label_text` and an
  optional `enabled_by`. Groups do not nest.
- `nsis_options_page`: `options` (options and groups, top to bottom), `title`,
  `subtitle`, `text`, `position` and `order`. The rule name is the page id
  (`[a-z][a-z0-9_]*`; `shortcuts` and `setup` are reserved).

```bzl
load("//nsis:defs.bzl", "nsis_installer", "nsis_option", "nsis_option_group", "nsis_options_page")

nsis_option(name = "enable_extras", control = "checkbox", label_text = "Install extras")
nsis_option(name = "extras_name", control = "text", default = "extra", required = True)
nsis_option(name = "port", control = "number", min = "1", max = "65535", default = "8080")
nsis_option(name = "mode", control = "droplist", choices = ["fast", "slow"])
nsis_option(name = "token", control = "password")

nsis_option_group(
    name = "extras_group",
    options = [":extras_name", ":port"],
    enabled_by = ":enable_extras",
)

nsis_options_page(
    name = "install_settings",
    title = "Install Settings",
    position = "after_directory",
    options = [":enable_extras", ":extras_group", ":mode", ":token"],
)

nsis_installer(
    name = "my_installer",
    options_pages = [":install_settings"],
    # ...
)
```

Attach a page with `nsis_installer.options_pages` (always shown) or
`nsis_component.options_pages` (shown only when that component is selected, and
only with `position = "after_components"`).

### Controls

| `control` | Backing type | Value / `default` form | Control-specific attrs |
|---|---|---|---|
| `checkbox` | bool | `1` or `0` | |
| `number` | int | signed 32-bit integer | `min`, `max` |
| `text` | string | any text | `max_length` |
| `password` | secret string | any text; never persisted | `max_length` |
| `radio` | enum | one of `choices` | `choices` |
| `droplist` | enum | one of `choices` | `choices` |
| `richedit` | multiline | text; stored on one line with `\n` and `\\` escapes | `max_length`, `lines` |
| `file_request` | file | absolute file path, Browse button | `filter`, `save`, `must_exist` |
| `dir_request` | dir | absolute directory, Browse button | `must_exist` |
| `combobox` | string | text with suggested `choices` | `choices`, `max_length` |
| `listbox`, `sorted_listbox` | enum | one of `choices`, or `a\|b` with `multi_select` | `choices`, `multi_select`, `lines` |
| `date` | date | `YYYY-MM-DD` | `min`, `max` |
| `ip_address` | ipv4 | `a.b.c.d` | |
| `net_address` | net | IPv4, IPv6 or DNS name, optionally with port or prefix | `address_types` |

`address_types` is any of `ipv4`, `ipv6`, `dns` (at least one) plus
`with_port` and `with_prefix`; empty means `ipv4`, `ipv6` and `dns`. String
defaults may reference NSIS variables such as `$DOCUMENTS`. Without a
`default` a value is unchecked, the number closest to 0 within `min`/`max`, an
empty string, or the first choice. `required` demands a non-empty value (not
for `number`, `checkbox`, `radio`, `droplist` and `date`).

### Layout

`position` is one of `after_welcome`, `after_license`, `after_directory` and
`after_components` (the default); all of them are before the files are
installed. Pages at the same position are ordered by `order`, then by name. The
dialog layout is computed at build time; a page whose controls do not fit fails
the build, so split it into several pages.

`enabled_by` names a `checkbox` on the same page: the control (or the whole
group) is disabled while the checkbox is unchecked. Checkbox chains are
allowed, cycles are not.

### Persistence

`persist` is `auto` (default: persisted, except passwords), `yes` or `no`
(`password` with `yes` is an error). Persisted values are written as
`REG_SZ` values named `<page>.<key>` under `Software\...\<product>\Options` and
are loaded again by the uninstaller and by the next install (as the defaults
of an upgrade).

### Reading values in hooks

The value of an option is available in every hook (also the uninstall hooks, from
the persisted copy) as `${Option_Get} <page> <key> $var`. Page and key are
plain words, not strings.

```nsis
!macro PostInstall_my_component OUTPATH
    ${Option_Get} install_settings port $0
    ${If} install_settings ${Option_IsSet} enable_extras
        ; checkbox is checked
    ${EndIf}
    ${Option_ListContains} list_page toppings "nuts" $1  ; $1 = 1 or 0
    ${Option_GetMultiline} text_page note $2            ; \n -> CRLF
    ${Option_Set} install_settings port 9090
!macroend
```

`Option_Get`, `Option_Set`, `Option_IsSet` and `Option_ListContains` work
unchanged in uninstall hooks; use `${un.Option_GetMultiline}` there. Passwords
are not persisted, so uninstall hooks see their default.

## Command Line

Installers built by this ruleset understand the following switches, besides the
standard NSIS ones (`/S`, `/D=`, `/NCRC`). Switch names are case-insensitive.
Invalid input makes the installer print `ERROR: ...` to the console and exit
with code `2` (silent mode) or show a message box (interactive mode).

| Switch | Meaning |
|---|---|
| `/COMPONENTS=<list>` | Comma separated component names or group names. Absolute (`a,b`: exactly these, plus required ones) or relative (`+a,-b`: change the defaults). Dependencies are selected with their dependents; deselecting a required component or one that a selected component needs is an error. Mixing the two forms is an error. |
| `/INSTTYPE=<name>` | Start from an install type. Combine only with a relative `/COMPONENTS`. |
| `/OPTIONS=<ini>` | Read options from an INI file: one `[<page>]` section per page with `key=value` lines, and an optional `[setup]` section with `components=` and `insttype=` (the `/COMPONENTS` and `/INSTTYPE` equivalents). Unknown sections or keys are errors. |
| `/O:<page>.<key>=<value>` | Set one option. May be repeated; the last occurrence wins. |
| `/HELP[=<topic>]`, `/?` | Print the help and exit with `0`. Topic: `usage`, `options`, `components`, `insttypes` or `all` (default). |
| `/FORMAT=text\|ini` | Help format. `ini` is a valid `/OPTIONS` file with the usage as comments; passwords are shown as `<secret>` in text output and left empty in ini output. |
| `/HELP-OUT=<file>` | Write the help to `<file>` (UTF-16LE) instead of the console. |
| `/TESTID=<id>` | Only for `testable` installers: isolates registry keys, mutexes and the product code. |

Option values are validated and canonicalised (`yes`, `TRUE` and `on` are all
`1` for a checkbox; dates must be `YYYY-MM-DD`, ...). Precedence, lowest to
highest: defaults, persisted values of a previous install, `/OPTIONS=`, `/O:`.
Command line options are applied before any page is shown, so in an
interactive install they pre-fill the pages. The help reports the effective
state, so `/HELP /COMPONENTS=+docs` shows what that selection would install.

```
Setup.exe /S /COMPONENTS=+docs,-samples /O:install_settings.port=9090 /OPTIONS=answers.ini
Setup.exe /HELP=options /FORMAT=ini /HELP-OUT=answers.ini
```

`nsis_installer` also has an `options_doc` output group with JSON and Markdown
files (`<name>_options_doc.json` and `.md`) listing options, components and
install types, for documentation:
`bazel build //:my_installer --output_groups=options_doc`.

## Shortcuts

`nsis_shortcut` creates a `.lnk` to a file that an `nsis_component` installs.
List it in the component's `shortcuts`.

```bzl
load("//nsis:defs.bzl", "nsis_component", "nsis_installer", "nsis_shortcut")

nsis_shortcut(
    name = "app_shortcut",
    target = ":app.exe",
    display_name = "My App",
    description = "Starts My App",
    arguments = ["--gui"],
    icon = ":app.ico",
    locations = ["start_menu", "desktop"],
)

nsis_component(
    name = "app",
    srcs = [":app.exe", ":app.ico"],
    shortcuts = [":app_shortcut"],
)

nsis_installer(
    name = "my_installer",
    components = [":app"],
    shortcuts_desktop_default = True,
    # ...
)
```

| Attr | Meaning |
|---|---|
| `target` | Mandatory. One of the component's `srcs` (or its `service_executable`). |
| `target_subpath` | The file inside a directory (tree artifact) target; required exactly then. Relative, no `.` or `..`. |
| `display_name` | Name of the `.lnk`. Defaults to the rule name in Title Case. |
| `description`, `arguments` | Comment and command line arguments (quoted as needed). |
| `icon`, `icon_subpath`, `icon_index` | Icon source, installed by the same component (default: the target's icon); `icon_index` also applies to the target's icon. |
| `locations` | Any of `start_menu`, `desktop`, `path`. Default `["start_menu", "desktop"]`. |
| `start_menu_subfolder` | A folder below the user's Start Menu folder (`start_menu` only). |
| `location_path` | The folder for `path` (required exactly then): a drive or UNC path, or one starting with a shell constant such as `$INSTDIR`, `$SMSTARTUP`, `$APPDATA`. |

The "Start in" folder is the target's folder. Two shortcuts with the same name in
the same location fail the build. Shortcuts are created after the files and all
`post_install` hooks, only for installed components.

`nsis_installer` attrs: `shortcuts_enabled_default` (True),
`shortcuts_start_menu_default` (True), `shortcuts_desktop_default` (False) and
`start_menu_folder` (default `<vendor_path or vendor>\<product_path>`, relative
to the Programs folder).

When any component has shortcuts, a built-in **Shortcuts** options page is
shown after the files were installed (before the Finish page). Its options can
also be set on the command line, and are persisted:

| Key | Meaning |
|---|---|
| `shortcuts.enabled` | Master toggle, also governing `path` shortcuts. |
| `shortcuts.start_menu` | Create Start Menu shortcuts. |
| `shortcuts.start_menu_folder` | The Start Menu folder, e.g. `/O:shortcuts.start_menu_folder=Custom\Folder`. |
| `shortcuts.desktop` | Create Desktop shortcuts. |

The page is skipped when none of the installed components has shortcuts. In a silent install the shortcuts are created at the end
of the installation.

The uninstaller removes a shortcut only if it still points into the
installation directory, then removes the Start Menu folders it created if they
are empty. Shortcuts the user repointed are kept (with a warning in the log).

## NSIS API Unit Testing

Use `nsis_symbol` to declare an API and `nsis_test_harness` to build a standalone
test executable without writing JSON. Parameters use `direction:name[:type]`,
for example `["in:count:int", "in:enabled:bool", "out:result:string"]`.
Supported types are `string` (default), signed 32-bit `int`, and `bool`.
The Python `Harness` validates inputs, converts outputs to their declared types,
captures stdout/stderr, checks that all 20 NSIS registers are preserved and the
stack is balanced, and can assert the NSIS error flag (`expect_errors`).

See the [testing framework guide](nsis/testing/README.md) for Bazel definitions,
typed Python assertions, installer/uninstaller support, and runnable examples.
These unit harnesses are separate from the end-to-end installer tests.

## Generated Installer Details

- Unicode
- Uninstaller file name: `Uninstaller.exe`
- Writes to Windows Registry `Software\{{.Product}}` or
  `Software\{{.Vendor}}\{{.Product}}`
  depending on what values are provided. Writes to subkeys:
    - InstallDir
- Adds uninstaller details to `Software\Microsoft\Windows\CurrentVersion\Uninstall\{{.Id}}`
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
- By default will allow 32bit installers to be installed on the 64bit system of
  the same instruction set (`allow_32bit_on_64bit`): `x86_32` on `x86_64` and
  `arm32` on `arm64`. Cross-ISA hosts (`x86_32` on `arm32`/`arm64`, `arm32` on
  `x86_32`/`x86_64`) are always rejected. Disabling the flag requires an exact
  architecture match.
- Uses MUI for the UI.
- Logs to the details view, and to StdOut if run from a console. `log_level`
  selects `none` (disabled), `debug`, `info` (default), `warn` or `error`.
- The shell context (`SetShellVarContext` and the HKLM/HKCU choice) defaults to
  the execution level. It is applied before the `pre_init`/`pre_uninit` hooks
  and re-applied after them, so a hook may switch it with
  `UpdateShellContextToAdmin`/`UpdateShellContextToCurrent`.
- Ensures only one installer is running using a mutex.
- Uninstalls previous installs when run.
- Installs and updates windows services using `sc.exe`
    - Will always attempt to stop the service before component section runs.
    - All component files are updated before the service is updated or created.
- When `/TESTID={{.TestId}}` is passed, will append TestId to the registry
  keys it uses. This is to handle race conditions while testing installers.
- If version is not provided, will default to `0.0.0.0`.
- EventLog keys written to `SYSTEM\CurrentControlSet\Services\EventLog\Application\{{.Id}}`
  under `HKLM` (always, since the Event Log service only reads `HKLM`). Using an
  `eventlog` component in an installer whose `execution_level` is not `admin`
  fails the build. Message file paths are stored as
  `REG_EXPAND_SZ`, so environment variables such as `%SystemRoot%` expand.

### Stamping
- Stamp values will be substituted with their workspace avlues when built with
  stamping.
- If build or installer is not stamped, stamp templates will be substituted using
  `stamp_defaults` if provided, otherwise, will default to the empty string.
- Vendor and Product *can* be stamped, but it is not recommended since it can
  result in odd or broken behavior (however, its behavior is well defined below).
    - Output file name will not include stamped information unless
      `stamp_defaults` has a value for it. Because information gets removed,
      it can lead to unintentional file name clashes.
    - If you need these fields to be configurable, or want to follow DRY (Don't
      Repeat Yourself), it is recommended to use [variables](https://bazel.build/build/share-variables)
      or [configurable attributes](https://bazel.build/docs/configurable-attributes).

### Component Dependencies

Based on dependencies provided in each component, a dependency graph between
components is created and then embedded in the installer. In the component
selection screen the following behavior will be seen:

1. When a component is selected, all of its dependencies (including transitive
   dependencies) will also be selected.
2. When a component is unselected, the all of its dependencies (including
   transitive dependencies) will be unselected, unless:
   1. They were selected manually.
   2. They are depended on by another component (either directly or transitively).
3. When a component is unselected, all dependents (either direct or transitive)
   will be unselected (even if they were selected manually).
