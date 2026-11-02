"""nsis_shortcut and the data behind the internal shortcuts page.

A shortcut only names a file (and optionally an icon) that the owning
component installs. The component resolves it to the path the installer will
put the file at (`resolve_component_shortcuts`), the installer checks the whole
set and adds the internal `shortcuts` options page
(`shortcuts_page`). Creation and removal at run time live in the installer
template.
"""

load(":options.bzl", "internal_options_page")

_LOCATIONS = ["start_menu", "desktop", "path"]

_INVALID_NAME_CHARS = "\\/:*?\"<>|"

# NSIS constants (and `$INSTDIR`) a `location_path` may start with.
_SHELL_CONSTANTS = [
    "$INSTDIR",
    "$SMPROGRAMS",
    "$SMSTARTUP",
    "$STARTMENU",
    "$DESKTOP",
    "$APPDATA",
    "$LOCALAPPDATA",
    "$DOCUMENTS",
    "$QUICKLAUNCH",
    "$PROGRAMFILES",
    "$PROGRAMFILES32",
    "$PROGRAMFILES64",
    "$COMMONFILES",
    "$COMMONFILES32",
    "$COMMONFILES64",
    "$PROFILE",
    "$FAVORITES",
    "$SENDTO",
    "$WINDIR",
    "$SYSDIR",
]

NsisShortcutInfo = provider(
    doc = "A shortcut to a file installed by a component.",
    fields = {
        "label": "The Bazel label of the shortcut, as a string.",
        "name": "The rule name.",
        "link_name": "The shortcut file name without the .lnk extension.",
        "target": "The File the shortcut points at (a file, or a directory artifact).",
        "target_subpath": "The file inside a directory target, with `\\` separators.",
        "icon": "The File providing the icon, or None for the target's own icon.",
        "icon_subpath": "The file inside a directory icon, with `\\` separators.",
        "icon_index": "The icon index.",
        "arguments": "The command line arguments, already quoted.",
        "description": "The shortcut's comment.",
        "start_menu": "Whether a Start Menu shortcut is created.",
        "desktop": "Whether a Desktop shortcut is created.",
        "path": "Whether a shortcut is created in location_path.",
        "start_menu_subfolder": "The Start Menu subfolder, with `\\` separators.",
        "location_path": "The folder for the `path` location.",
        "validation": "A depset of files of the actions validating the shortcut at build time.",
    },
)

_SHORTCUT_FIELDS = [
    "label",
    "name",
    "link_name",
    "target",
    "target_subpath",
    "icon",
    "icon_subpath",
    "icon_index",
    "arguments",
    "description",
    "start_menu",
    "desktop",
    "path",
    "start_menu_subfolder",
    "location_path",
    "validation",
]

def _fail(label, msg):
    fail("{}: {}".format(label, msg))

def _title_case(name):
    return " ".join([w.capitalize() for w in name.split("_") if w.strip()])

def relative_path(label, what, value):
    """Returns value normalized to `\\` separators, failing unless it is a plain relative path."""
    if not value:
        return ""
    v = value.replace("/", "\\")
    if v.startswith("\\") or ":" in v:
        _fail(label, "{} '{}' must be relative, without a drive or a leading separator".format(what, value))
    for seg in v.split("\\"):
        if seg == "":
            _fail(label, "{} '{}' must not have empty segments".format(what, value))
        if seg in [".", ".."]:
            _fail(label, "{} '{}' must not contain '{}' segments".format(what, value, seg))
        for c in "*?\"<>|".elems():
            if c in seg:
                _fail(label, "{} '{}' contains the character '{}', which is not valid in a path".format(what, value, c))
    return v

def _quote_argument(arg):
    if arg and not (" " in arg or "\t" in arg or "\"" in arg):
        return arg
    return "\"{}\"".format(arg.replace("\"", "\\\""))

def _check_location_path(label, value):
    v = value.replace("/", "\\")
    if len(v) >= 3 and v[0].isalpha() and v[1] == ":" and v[2] == "\\":
        rest = v[3:]
    elif v.startswith("\\\\") and len(v) > 2:
        rest = v[2:]
    else:
        rest = None
        for c in _SHELL_CONSTANTS:
            if v == c or v.startswith(c + "\\"):
                rest = v[len(c):]
                break
        if rest == None:
            _fail(label, "location_path '{}' must be a drive path (C:\\...), a UNC path (\\\\...) or start with one of the shell constants {}".format(value, _SHELL_CONSTANTS))
    for seg in rest.split("\\"):
        if seg == "..":
            _fail(label, "location_path '{}' must not contain '..' segments".format(value))
    return v.rstrip("\\") if len(v) > 3 else v

def _check_tree(ctx, tree, subpath, what):
    """Adds the action that checks that `subpath` is a file inside the tree artifact."""
    out = ctx.actions.declare_file("{}.{}_check".format(ctx.label.name, what))
    ctx.actions.run_shell(
        mnemonic = "NsisShortcutCheck",
        progress_message = "Checking {} of {}".format(what, ctx.label),
        inputs = [tree],
        outputs = [out],
        arguments = [tree.path, subpath.replace("\\", "/"), str(ctx.label), what, out.path],
        command = """
if [ ! -f "$1/$2" ]; then
  echo "ERROR: $3: $4_subpath '$2' is not a file inside the directory $1" >&2
  exit 1
fi
: > "$5"
""",
    )
    return out

def _resolve_file(ctx, attr_name, file, subpath, checks):
    if file.is_directory:
        if not subpath:
            _fail(ctx.label, "{} {} is a directory; {}_subpath is required to select the file inside it".format(attr_name, file.short_path, attr_name))
        checks.append(_check_tree(ctx, file, subpath, attr_name))
    elif subpath:
        _fail(ctx.label, "{}_subpath is only valid when {} is a directory; {} is a file".format(attr_name, attr_name, file.short_path))

def _nsis_shortcut_impl(ctx):
    label = str(ctx.label)
    locations = ctx.attr.locations
    if not locations:
        _fail(label, "locations must not be empty")
    for loc in locations:
        if loc not in _LOCATIONS:
            _fail(label, "unknown location '{}'; valid locations are {}".format(loc, _LOCATIONS))
    if len(set(locations)) != len(locations):
        _fail(label, "locations {} contains duplicates".format(locations))

    has_path = "path" in locations
    if has_path and not ctx.attr.location_path:
        _fail(label, "location_path is required when locations contains \"path\"")
    if not has_path and ctx.attr.location_path:
        _fail(label, "location_path is only valid when locations contains \"path\"")
    if ctx.attr.start_menu_subfolder and "start_menu" not in locations:
        _fail(label, "start_menu_subfolder is only valid when locations contains \"start_menu\"")

    display_name = ctx.attr.display_name.strip() or _title_case(ctx.label.name)
    for c in _INVALID_NAME_CHARS.elems():
        if c in display_name:
            _fail(label, "display_name '{}' contains the character '{}', which is not valid in a file name".format(display_name, c))

    if ctx.attr.icon_index < 0:
        _fail(label, "icon_index must not be negative")
    if ctx.attr.icon_subpath and ctx.file.icon == None:
        _fail(label, "icon_subpath requires icon")

    target_subpath = relative_path(label, "target_subpath", ctx.attr.target_subpath)
    icon_subpath = relative_path(label, "icon_subpath", ctx.attr.icon_subpath)
    checks = []
    _resolve_file(ctx, "target", ctx.file.target, target_subpath, checks)
    if ctx.file.icon != None:
        _resolve_file(ctx, "icon", ctx.file.icon, icon_subpath, checks)

    validation = depset(checks)
    return [
        NsisShortcutInfo(
            label = label,
            name = ctx.label.name,
            link_name = display_name,
            target = ctx.file.target,
            target_subpath = target_subpath,
            icon = ctx.file.icon,
            icon_subpath = icon_subpath,
            icon_index = ctx.attr.icon_index,
            arguments = " ".join([_quote_argument(a) for a in ctx.attr.arguments]),
            description = ctx.attr.description,
            start_menu = "start_menu" in locations,
            desktop = "desktop" in locations,
            path = has_path,
            start_menu_subfolder = relative_path(label, "start_menu_subfolder", ctx.attr.start_menu_subfolder),
            location_path = _check_location_path(label, ctx.attr.location_path) if has_path else "",
            validation = validation,
        ),
        OutputGroupInfo(_validation = validation),
    ]

nsis_shortcut = rule(
    implementation = _nsis_shortcut_impl,
    doc = """
A shortcut (.lnk) to a file that an `nsis_component` installs.

List it in the component's `shortcuts`. The shortcuts are created after the
installation finished, on the installer's internal Shortcuts page (or silently,
driven by `/O:shortcuts.<key>=<value>`), only for components that were
installed, and removed again by the uninstaller if they still point into the
installation directory. The shortcut's "Start in" folder is the target's folder.
""",
    attrs = {
        "target": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = """
The file the shortcut points at. It must be one of the `srcs` (or the
`service_executable`) of the component that lists the shortcut. When it is a
directory (tree artifact), set `target_subpath`.
""",
        ),
        "target_subpath": attr.string(
            default = "",
            doc = """
Required when `target` is a directory and forbidden otherwise: the relative
path of the file inside that directory. `/` and `\\` are both accepted; no
absolute paths and no `.` or `..` segments.
""",
        ),
        "display_name": attr.string(
            default = "",
            doc = "The shortcut's name, shown as `<display_name>.lnk`. Defaults to the rule name in Title Case.",
        ),
        "description": attr.string(default = "", doc = "The shortcut's comment (tooltip)."),
        "arguments": attr.string_list(
            default = [],
            doc = "Command line arguments. Arguments with spaces or quotes are quoted.",
        ),
        "icon": attr.label(
            allow_single_file = True,
            doc = """
Optional file the icon is taken from (an .ico, or an executable and an
`icon_index`). It follows the rules of `target`: it must be installed by the
same component, and a directory needs `icon_subpath`. Defaults to the icon of
the target.
""",
        ),
        "icon_subpath": attr.string(
            default = "",
            doc = "Like `target_subpath`, for `icon`.",
        ),
        "icon_index": attr.int(
            default = 0,
            doc = "The index of the icon in the icon file (or in the target when no `icon` is set).",
        ),
        "locations": attr.string_list(
            default = ["start_menu", "desktop"],
            doc = """
Where to create the shortcut: any of `start_menu`, `desktop` and `path`. The
first two follow the user's choices on the Shortcuts page; `path` is only
governed by the page's master toggle.
""",
        ),
        "start_menu_subfolder": attr.string(
            default = "",
            doc = "A folder below the Start Menu folder the user chose, for the `start_menu` location.",
        ),
        "location_path": attr.string(
            default = "",
            doc = """
The absolute folder for the `path` location (required exactly when `locations`
contains it). A drive path, a UNC path, or a path starting with one of the
NSIS shell constants `$INSTDIR`, `$SMSTARTUP`, `$APPDATA`, ... which resolve
for the installer's shell context.
""",
        ),
    },
)

def resolve_component_shortcuts(label, component_name, directory, installable, targets):
    """Resolves a component's shortcut targets to the paths they are installed at.

    Args:
        label: The component label, for error messages.
        component_name: The component name.
        directory: The component's install directory, with `\\` separators.
        installable: The Files the component installs (srcs and service executable).
        targets: The component's `shortcuts` targets.

    Returns:
        A list of structs: the NsisShortcutInfo fields plus `target_rel` and
        `icon_rel`, the paths below the install directory.
    """
    by_path = {f.path: f for f in installable}

    def install_path(sc, attr_name, file, subpath):
        if file.path not in by_path:
            names = sorted([f.short_path for f in installable])
            _fail(label, "shortcut {} has {} {}, which component '{}' does not install; its installable files are {}".format(
                sc.label,
                attr_name,
                file.short_path,
                component_name,
                names,
            ))
        rel = subpath if file.is_directory else file.basename
        return "{}\\{}".format(directory, rel) if directory else rel

    resolved = []
    for t in targets:
        sc = t[NsisShortcutInfo]
        target_rel = install_path(sc, "target", sc.target, sc.target_subpath)
        icon_rel = ""
        if sc.icon != None:
            icon_rel = install_path(sc, "icon", sc.icon, sc.icon_subpath)
        elif sc.icon_index:
            icon_rel = target_rel
        fields = {k: getattr(sc, k) for k in _SHORTCUT_FIELDS}
        fields["target_rel"] = target_rel
        fields["icon_rel"] = icon_rel
        fields["component"] = component_name
        resolved.append(struct(**fields))
    return resolved

def shortcut_ds(sc):
    """Returns the data source entry of a resolved shortcut."""
    return {
        "Name": sc.name,
        "LinkName": sc.link_name,
        "Target": "$INSTDIR\\" + sc.target_rel,
        "TargetRelative": sc.target_rel,
        "Arguments": sc.arguments,
        "Description": sc.description,
        "Icon": ("$INSTDIR\\" + sc.icon_rel) if sc.icon_rel else "",
        "IconRelative": sc.icon_rel,
        "IconIndex": sc.icon_index,
        "StartMenu": sc.start_menu,
        "Desktop": sc.desktop,
        "Path": sc.path,
        "StartMenuSubfolder": sc.start_menu_subfolder,
        "LocationPath": sc.location_path,
    }

def default_start_menu_folder(vendor, vendor_path, product_path):
    parts = [p for p in [vendor_path or vendor, product_path] if p]
    return "\\".join([p.replace("/", "\\").strip("\\") for p in parts])

def shortcuts_page(label, start_menu_folder, enabled_default, start_menu_default, desktop_default):
    """Returns the data source entry of the internal Shortcuts page."""
    folder = relative_path(label, "start_menu_folder", start_menu_folder)
    if not folder:
        _fail(label, "start_menu_folder must not be empty")
    return internal_options_page(
        name = "shortcuts",
        title = "Create Shortcuts",
        subtitle = "Choose which shortcuts to create for the installed application.",
        position = "after_instfiles",
        specs = [
            {"key": "enabled", "control": "checkbox", "text": "Create shortcuts", "default": "1" if enabled_default else "0"},
            {"key": "start_menu", "control": "checkbox", "text": "Create Start Menu shortcuts", "default": "1" if start_menu_default else "0", "enabled_by": "enabled"},
            {"key": "start_menu_folder", "control": "text", "text": "Start Menu folder:", "default": folder, "required": True, "enabled_by": "start_menu"},
            {"key": "desktop", "control": "checkbox", "text": "Create Desktop shortcuts", "default": "1" if desktop_default else "0", "enabled_by": "enabled"},
        ],
        pre_create = """    Call __Shortcuts_Scan
    ${If} $__shortcuts_any != 1
        Pop $1
        Pop $0
        Abort
    ${EndIf}""",
        post_create = "    Call __Shortcuts_PostCreate",
        post_leave = """    Call __Shortcuts_Validate
    ${If} $__opt_chk_err != ""
        StrCpy $__opt_chk_what "Start Menu folder"
        Goto __fail
    ${EndIf}
    Call __Shortcuts_CreateAll""",
    )
