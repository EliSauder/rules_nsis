"""Command line data for the installer template (/COMPONENTS, /INSTTYPE, /HELP).

`cli_data` turns the already collected component and option data into the
tables the template emits as NSIS code: the flattened component list with its
dependency closure, the group expansions, the install types and the static
text pieces of the /HELP output. `options_doc_content` renders the same data
for the `options_doc` output group.
"""

_COMPONENTS = "Components"
_GROUPS = "ComponentGroups"

_USAGE = [
    ("/S", "Install silently."),
    ("/D=<dir>", "Install into <dir>. Must be the last argument and unquoted."),
    ("/NCRC", "Skip the integrity check."),
    ("/O:<page>.<key>=<value>", "Set an option. May be repeated; the last one wins."),
    ("/OPTIONS=<ini>", "Read options from an INI file ([<page>] sections, plus [setup])."),
    ("/COMPONENTS=<list>", "Comma separated component names or groups. Absolute (a,b) or relative (+a,-b)."),
    ("/INSTTYPE=<name>", "Start from an install type. Combine with relative /COMPONENTS only."),
    ("/HELP[=<topic>]", "Show this help. Topic: usage, options, components, insttypes or all."),
    ("/?", "Same as /HELP."),
    ("/FORMAT=<fmt>", "Help format: text (default) or ini (a valid /OPTIONS file)."),
    ("/HELP-OUT=<file>", "Write the help to <file> instead of the console."),
]

_TESTID_USAGE = (
    "/TESTID=<id>",
    "Isolate registry keys, mutexes and the product code per test run.",
)

_EXTRA_FIELDS = [
    ("MultiSelect", "multi_select"),
    ("Filter", "filter"),
    ("Lines", "lines"),
    ("MustExist", "must_exist"),
    ("Save", "save"),
    ("AddressTypes", "address_types"),
]

def _pad(value, width):
    return value + " " * (width - len(value))

def _one_line(value):
    return value.replace("\r", " ").replace("\n", " ")

def _walk(components, groups):
    """Returns [(component data, group path)] in installer order."""
    flat = []
    stack = [(components, groups, "")]
    for _ in range(100000):
        if not stack:
            break
        cmps, grps, path = stack.pop()
        for c in cmps:
            flat.append((c, path))
        for g in reversed(grps):
            stack.append((g[_COMPONENTS], g[_GROUPS], path + g["Name"] + "/"))
    return flat

def _group_expansions(groups):
    """Returns [{Name, Members}] where Members includes all descendants."""
    result = []
    stack = [(g, []) for g in reversed(groups)]
    for _ in range(100000):
        if not stack:
            break
        g, anc = stack.pop()
        names = [c["Name"] for c in g[_COMPONENTS]]
        result.append({"Name": g["Name"], "Members": names, "Ancestors": anc})
        for sub in reversed(g[_GROUPS]):
            stack.append((sub, anc + [g["Name"]]))
    by_name = {r["Name"]: r for r in result}
    for r in result:
        for a in r["Ancestors"]:
            for m in r["Members"]:
                if m not in by_name[a]["Members"]:
                    by_name[a]["Members"].append(m)
    return result

def _is_persisted(opt):
    return bool(opt.get("Persist", False))

def _option_details(opt, owners):
    secret = opt.get("Secret", False)
    parts = []
    if secret:
        parts.append("default=<secret>")
    else:
        parts.append("default={}".format(opt.get("Default", "") or "(none)"))
    parts.append("persisted" if _is_persisted(opt) else "not persisted")
    if opt.get("Choices"):
        parts.append("choices={}".format("|".join(opt["Choices"])))
    if opt.get("Min") or opt.get("Max"):
        parts.append("range={}..{}".format(opt.get("Min", "") or "", opt.get("Max", "") or ""))
    if opt.get("MaxLength"):
        parts.append("max_length={}".format(opt["MaxLength"]))
    for field, label in _EXTRA_FIELDS:
        v = opt.get(field)
        if v:
            parts.append("{}={}".format(label, v if type(v) != "list" else ",".join(v)))
    if opt.get("Required"):
        parts.append("required")
    if owners:
        parts.append("components={}".format(",".join(owners)))
    return _one_line(", ".join(parts))

def _option_kind(opt):
    return "{}/{}".format(opt.get("Control", "?"), opt.get("Type", "?"))

def cli_data(components, groups, deps, component_map, install_types, testable, pages, version_text):
    """Builds the `Cli` data source key.

    Args:
        components: The data source `Components` (nested lists).
        groups: The data source `ComponentGroups`.
        deps: The data source `ComponentDependencies` list.
        component_map: Component name to component data.
        install_types: The ordered install type names.
        testable: Whether the installer is testable (lists /TESTID).
        pages: The data source `OptionsPages`.
        version_text: The "<product> <version>" heading.

    Returns:
        A dict for `(ds "in").Cli`.
    """
    flat = _walk(components, groups)
    closure = {d["Component"]: sorted([x for x in d["Dependencies"]]) for d in deps}

    name_width = max([len(c["Name"]) for c, _ in flat] + [1])
    mode_width = max([len(c["SelectionMode"]) for c, _ in flat] + [1])

    cmps = []
    for c, path in flat:
        name = c["Name"]
        types = [install_types[int(i) - 1] for i in c["InstallCategories"].split(" ") if i]
        idxs = [int(i) for i in c["InstallCategories"].split(" ") if i]
        all_deps = closure.get(name, [])
        default_selected = c["Required"] or not c["DisabledByDefault"]
        notes = []
        if types:
            notes.append("types: " + ",".join(types))
        if c["Dependencies"]:
            notes.append("deps: " + ",".join(c["Dependencies"]))
        if path:
            notes.append("group: " + path.rstrip("/"))
        cmps.append({
            "Name": name,
            "DisplayName": c["DisplayName"],
            "Mode": c["SelectionMode"],
            "Required": c["Required"],
            "DefaultSelected": default_selected,
            "InstTypeIdx": idxs,
            "AllDeps": all_deps,
            "TextPrefix": "  {}  {}  selected=".format(_pad(name, name_width), _pad(c["SelectionMode"], mode_width)),
            "TextSuffix": "  default={}{}  ({})".format(
                "yes" if default_selected else "no",
                "".join(["  " + n for n in notes]),
                _one_line(c["DisplayName"]),
            ),
            "IniPiece": "{} ({}{})".format(
                name,
                "required" if c["SelectionMode"] in ("required", "hidden") else ("default" if default_selected else "optional"),
                ", deps: " + ",".join(c["Dependencies"]) if c["Dependencies"] else "",
            ),
        })

    required = {c["Name"]: c["Required"] for c in cmps}
    itypes = []
    for i, t in enumerate(install_types):
        members = [c["Name"] for c in cmps if (i + 1) in c["InstTypeIdx"]]
        itypes.append({"Name": t, "Index": i + 1, "Members": members, "Text": "  {}: {}".format(t, ", ".join(members) or "(none)")})

    usage_rows = list(_USAGE)
    if testable:
        usage_rows.append(_TESTID_USAGE)
    usage_width = max([len(s) for s, _ in usage_rows])
    usage = [{
        "Switch": s,
        "Text": "  {}  {}".format(_pad(s, usage_width), d),
        "Ini": ";   {}  {}".format(_pad(s, usage_width), d),
    } for s, d in usage_rows]

    id_width = 1
    kind_width = 1
    for p in pages:
        for o in p["Options"]:
            id_width = max(id_width, len(o["Id"]))
            kind_width = max(kind_width, len(_option_kind(o)))

    help_pages = []
    for p in pages:
        owners = p.get("OwningComponents", [])
        opts = []
        for o in p["Options"]:
            details = _option_details(o, owners)
            desc = _one_line(o.get("Description", "") or "")
            opts.append({
                "Key": o["Key"],
                "Id": o["Id"],
                "Var": o["Var"],
                "Secret": bool(o.get("Secret", False)),
                "TextPrefix": "  {}  {}  value=".format(_pad(o["Id"], id_width), _pad(_option_kind(o), kind_width)),
                "TextDetail": "      {}".format(details),
                "TextDescription": "      {}".format(desc) if desc else "",
                "IniComment": "; {}: {}, {}{}".format(o["Key"], _option_kind(o), details, " - " + desc if desc else ""),
            })
        help_pages.append({"Name": p["Name"], "Options": opts})

    return {
        "Heading": version_text,
        "Components": cmps,
        "Groups": [{
            "Name": g["Name"],
            "Members": [{"Name": m, "Required": required[m]} for m in g["Members"]],
        } for g in _group_expansions(groups)],
        "InstTypes": itypes,
        "Usage": usage,
        "Pages": help_pages,
        "HasOptions": len(help_pages) > 0,
        "ComponentCount": len(cmps),
    }

def options_doc_content(product, version, data):
    """Returns (json_text, markdown_text) documenting options, components and install types."""
    cli = data["Cli"]
    doc = {
        "product": product,
        "version": version,
        "options": [{
            "id": o["Id"],
            "page": o["Page"],
            "key": o["Key"],
            "control": o.get("Control", ""),
            "type": o.get("Type", ""),
            "label": o.get("Label", ""),
            "description": o.get("Description", ""),
            "default": "" if o.get("Secret", False) else o.get("Default", ""),
            "choices": o.get("Choices", []),
            "min": o.get("Min", ""),
            "max": o.get("Max", ""),
            "required": bool(o.get("Required", False)),
            "secret": bool(o.get("Secret", False)),
            "persisted": _is_persisted(o),
        } for o in data["Options"]],
        "components": [{
            "name": c["Name"],
            "display_name": c["DisplayName"],
            "mode": c["Mode"],
            "default_selected": c["DefaultSelected"],
            "dependencies": c["AllDeps"],
            "install_types": [t["Name"] for t in cli["InstTypes"] if c["Name"] in t["Members"]],
        } for c in cli["Components"]],
        "install_types": [{"name": t["Name"], "components": t["Members"]} for t in cli["InstTypes"]],
    }

    md = ["# {} {}".format(product, version), "", "## Options", ""]
    if doc["options"]:
        md.append("| Option | Control | Type | Default | Persisted | Description |")
        md.append("|---|---|---|---|---|---|")
        for o in doc["options"]:
            md.append("| `{}` | {} | {} | {} | {} | {} |".format(
                o["id"],
                o["control"],
                o["type"],
                "`{}`".format(o["default"]) if o["default"] else "",
                "yes" if o["persisted"] else "no",
                _one_line(o["description"]).replace("|", "\\|"),
            ))
    else:
        md.append("None.")
    md += ["", "## Components", ""]
    md.append("| Component | Mode | Default | Dependencies | Install types |")
    md.append("|---|---|---|---|---|")
    for c in doc["components"]:
        md.append("| `{}` | {} | {} | {} | {} |".format(
            c["name"],
            c["mode"],
            "yes" if c["default_selected"] else "no",
            ", ".join(c["dependencies"]),
            ", ".join(c["install_types"]),
        ))
    md += ["", "## Install types", ""]
    for t in doc["install_types"]:
        md.append("- **{}**: {}".format(t["name"], ", ".join(t["components"]) or "(none)"))
    md.append("")

    return json.encode_indent(doc), "\n".join(md)
