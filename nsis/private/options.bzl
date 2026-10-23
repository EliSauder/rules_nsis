"""Options pages: nsis_option, nsis_option_group and nsis_options_page.

Everything about a page is decided at analysis time: validation, canonical
defaults and the dialog layout. The resulting data (see `collect_options_pages`)
is handed to the installer template, which only emits NSIS code.

Adding a control (see `_CONTROLS`): add one entry describing its backing type,
the control-specific attrs it accepts, how its default is parsed and how it is
laid out, then add the matching create/read/check blocks to the template's
`opt_*` dispatchers. Internal pages (e.g. shortcuts) are plain page data
dicts appended to the collected pages (`Internal = True`, optionally position
`after_instfiles`).
"""

_CONTROL_NAMES = [
    "checkbox",
    "number",
    "text",
    "password",
    "richedit",
    "file_request",
    "dir_request",
    "radio",
    "droplist",
    "combobox",
    "listbox",
    "sorted_listbox",
    "date",
    "ip_address",
    "net_address",
]

_PERSIST_VALUES = ["auto", "yes", "no"]

_POSITIONS = [
    "after_welcome",
    "after_license",
    "after_directory",
    "after_components",
]

# Internal pages may additionally use "after_instfiles".
_POSITION_RANK = {
    "after_welcome": 0,
    "after_license": 1,
    "after_directory": 2,
    "after_components": 3,
    "after_instfiles": 4,
}

_RESERVED_PAGES = ["shortcuts", "setup"]

# Usable height of the nsDialogs page area, in dialog units.
_PAGE_HEIGHT = 140
_GAP = 4
_LABEL_HEIGHT = 10
_EDIT_HEIGHT = 12
_LINE_HEIGHT = 8
_LINE_CHARS = 70
_GROUP_HEADER = 10
_GROUP_PADDING = 4
_GROUP_INDENT = 6
_DROPDOWN_HEIGHT = 60
_DEFAULT_LINES = 4

_INT_MAX = 2147483647

NsisOptionInfo = provider(
    doc = "A single installer option, rendered as one control on an options page.",
    fields = {
        "label": "The Bazel label of the option, as a string.",
        "name": "The rule name.",
        "key": "The option key, unique within its page.",
        "control": "The control kind.",
        "type": "The backing data type of the option's value.",
        "text": "The label shown in the UI.",
        "description": "The help text shown under the control.",
        "default": "The default in canonical form.",
        "required": "Whether the value must be non-empty.",
        "enabled_by": "The Bazel label (string) of the checkbox option enabling this one, or empty.",
        "persist": "The effective persistence: True or False.",
        "choices": "The valid values for enum controls.",
        "multi_select": "Whether a list control selects several values.",
        "min": "Canonical lower bound, or empty.",
        "max": "Canonical upper bound, or empty.",
        "max_length": "Maximum text length, 0 for unlimited.",
        "lines": "Control height in text lines, 0 for the default.",
        "filter": "File dialog filter.",
        "save": "Whether the file dialog is a save dialog.",
        "must_exist": "Whether a path must exist.",
        "address_types": "Accepted network address types.",
        "net_flags": "The NET_STRING_* mask of the accepted network address types.",
    },
)

NsisOptionGroupInfo = provider(
    doc = "A group box around several options.",
    fields = {
        "label": "The Bazel label of the group, as a string.",
        "name": "The rule name.",
        "text": "The group box caption.",
        "enabled_by": "The Bazel label (string) of the checkbox option enabling the group, or empty.",
        "options": "The NsisOptionInfo of every option in the group, in order.",
    },
)

NsisOptionsPageInfo = provider(
    doc = "An options page with its validated, laid out content.",
    fields = {
        "label": "The Bazel label of the page, as a string.",
        "name": "The page id.",
        "position": "Where the page is placed in the installer.",
        "ds": "The page data source entry, without the owning components.",
    },
)

def _fail(label, msg):
    fail("{}: {}".format(label, msg))

def _title_case(name):
    words = [w.capitalize() for w in name.split("_") if w.strip()]
    return " ".join(words)

def _is_ident(value):
    """Whether value matches [a-z][a-z0-9_]*."""
    if not value:
        return False
    if not value[0].isalpha() or not value[0].islower():
        return False
    for c in value.elems():
        if not (c in "abcdefghijklmnopqrstuvwxyz0123456789_"):
            return False
    return True

def _parse_bool(value):
    v = value.lower()
    if v in ["1", "true", "t", "yes", "y", "on"]:
        return "1"
    if v in ["0", "false", "f", "no", "n", "off"]:
        return "0"
    return None

def _parse_int(value):
    """Returns the canonical decimal form, or None when value is no 32-bit int."""
    digits = value
    negative = False
    if value.startswith("+") or value.startswith("-"):
        negative = value.startswith("-")
        digits = value[1:]
    if not digits or not digits.isdigit():
        return None
    n = int(digits.lstrip("0") or "0")
    if n > _INT_MAX + (1 if negative else 0):
        return None
    return str(-n if negative else n)

def _days_in_month(year, month):
    if month in [1, 3, 5, 7, 8, 10, 12]:
        return 31
    if month != 2:
        return 30
    leap = (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
    return 29 if leap else 28

def _parse_date(value):
    """Returns the canonical YYYY-MM-DD form, or None when value is no date."""
    if len(value) != 10 or value[4] != "-" or value[7] != "-":
        return None
    y = value[0:4]
    m = value[5:7]
    d = value[8:10]
    if not (y.isdigit() and m.isdigit() and d.isdigit()):
        return None
    year = int(y.lstrip("0") or "0")
    month = int(m.lstrip("0") or "0")
    day = int(d.lstrip("0") or "0")
    if year < 1601 or month < 1 or month > 12 or day < 1 or day > _days_in_month(year, month):
        return None
    return value

def _parse_ipv4(value):
    """Returns the dotted quad without leading zeros, or None."""
    parts = value.split(".")
    if len(parts) != 4:
        return None
    out = []
    for p in parts:
        if not p or not p.isdigit() or len(p) > 3:
            return None
        n = int(p.lstrip("0") or "0")
        if n > 255:
            return None
        out.append(str(n))
    return ".".join(out)

def _valid_escapes(value):
    """Whether a multi-line value only uses the escapes \\n and \\\\."""
    i = 0
    n = len(value)
    for _ in range(n):
        if i >= n:
            break
        if value[i] == "\\":
            if i + 1 >= n or value[i + 1] not in ["n", "\\"]:
                return False
            i += 2
        elif value[i] in ["\n", "\r"]:
            return False
        else:
            i += 1
    return True

def _lines(text, chars = _LINE_CHARS):
    if not text:
        return 0
    return (len(text) + chars - 1) // chars

# ----------------------------------------------------------------------------
# Per-control behaviour. Each entry:
#   type:       backing data type.
#   uses:       control-specific attrs the control accepts.
#   required:   whether `required` may be set.
#   default:    fn(label, a) -> canonical default; fails on a bad default.
#   layout:     fn(a) -> struct(has_label, control_offset, control_height,
#               height, choice_height) in dialog units, relative to the block.
# `a` is the struct of option attrs built in `_option_attrs`.
# ----------------------------------------------------------------------------

def _default_checkbox(label, a):
    if not a.default:
        return "0"
    v = _parse_bool(a.default)
    if v == None:
        _fail(label, "default '{}' is not a boolean (1/0, true/false, yes/no, on/off)".format(a.default))
    return v

def _default_number(label, a):
    lo = a.min
    hi = a.max
    if not a.default:
        # Closest value to 0 that is within the bounds.
        v = 0
        if lo and v < int(lo):
            v = int(lo)
        if hi and v > int(hi):
            v = int(hi)
        return str(v)
    v = _parse_int(a.default)
    if v == None:
        _fail(label, "default '{}' is not a 32-bit integer".format(a.default))
    if (lo and int(v) < int(lo)) or (hi and int(v) > int(hi)):
        _fail(label, "default {} is outside of min/max [{}, {}]".format(v, lo, hi))
    return v

def _default_string(label, a):
    if a.max_length and len(a.default) > a.max_length:
        _fail(label, "default is longer than max_length ({})".format(a.max_length))
    return a.default

def _default_enum(label, a):
    if not a.default:
        return a.choices[0]
    if a.default not in a.choices:
        _fail(label, "default '{}' is not one of choices {}".format(a.default, a.choices))
    return a.default

def _default_richedit(label, a):
    if not _valid_escapes(a.default):
        _fail(label, "default must be on a single line; use \\n for line breaks and \\\\ for a backslash")
    return _default_string(label, a)

def _default_path(label, a):
    d = a.default
    if d and not (d.startswith("$") or d.startswith("\\\\") or (len(d) > 2 and d[1] == ":" and d[2] in ["\\", "/"])):
        _fail(label, "default '{}' is not an absolute path".format(d))
    return _default_string(label, a)

def _default_combobox(label, a):
    return _default_string(label, a)

def _default_list(label, a):
    if not a.multi_select:
        return _default_enum(label, a)
    if not a.default:
        return ""
    chosen = {}
    for item in a.default.split("|"):
        match = [c for c in a.choices if c.lower() == item.lower()]
        if not match:
            _fail(label, "default item '{}' is not one of choices {}".format(item, a.choices))
        if match[0] in chosen:
            _fail(label, "default item '{}' is listed twice".format(item))
        chosen[match[0]] = True
    return "|".join([c for c in a.choices if c in chosen])

def _default_date(label, a):
    if not a.default:
        # Empty means "today" (clamped to min/max), which is only known at run time.
        return ""
    v = _parse_date(a.default)
    if v == None:
        _fail(label, "default '{}' is not a date (YYYY-MM-DD, years 1601-9999)".format(a.default))
    if (a.min and v < a.min) or (a.max and v > a.max):
        _fail(label, "default {} is outside of min/max [{}, {}]".format(v, a.min, a.max))
    return v

def _default_ip(label, a):
    if not a.default:
        return ""
    v = _parse_ipv4(a.default)
    if v == None:
        _fail(label, "default '{}' is not an IPv4 address (a.b.c.d)".format(a.default))
    return v

def _default_net(label, a):
    d = a.default
    if not d:
        return ""
    for c in d.elems():
        if c in " \t\r\n|":
            _fail(label, "default '{}' is not a valid network address".format(d))
    types = a.address_types
    if types and "ipv6" not in types and "dns" not in types:
        host = d
        if "with_prefix" in types and "/" in host:
            host, prefix = host.rsplit("/", 1)
            if not prefix.isdigit() or int(prefix) > 32:
                _fail(label, "default '{}' has an invalid prefix length".format(d))
        if "with_port" in types and ":" in host:
            host, port = host.rsplit(":", 1)
            if not port.isdigit() or int(port) > 65535:
                _fail(label, "default '{}' has an invalid port".format(d))
        if _parse_ipv4(host) == None:
            _fail(label, "default '{}' is not an IPv4 address".format(d))
    return d

def _layout_checkbox(_a):
    return struct(has_label = False, control_offset = 0, control_height = _EDIT_HEIGHT, height = _EDIT_HEIGHT, choice_height = 0)

def _layout_edit(_a):
    return struct(
        has_label = True,
        control_offset = _LABEL_HEIGHT + 1,
        control_height = _EDIT_HEIGHT,
        height = _LABEL_HEIGHT + 1 + _EDIT_HEIGHT,
        choice_height = 0,
    )

def _layout_droplist(_a):
    return struct(
        has_label = True,
        control_offset = _LABEL_HEIGHT + 1,
        control_height = _DROPDOWN_HEIGHT,
        height = _LABEL_HEIGHT + 1 + _EDIT_HEIGHT,
        choice_height = 0,
    )

def _layout_multiline(a):
    h = (a.lines or _DEFAULT_LINES) * _LINE_HEIGHT + 4
    return struct(
        has_label = True,
        control_offset = _LABEL_HEIGHT + 1,
        control_height = h,
        height = _LABEL_HEIGHT + 1 + h,
        choice_height = 0,
    )

def _layout_radio(a):
    return struct(
        has_label = True,
        control_offset = _LABEL_HEIGHT + 1,
        control_height = _EDIT_HEIGHT,
        height = _LABEL_HEIGHT + 1 + _EDIT_HEIGHT * len(a.choices),
        choice_height = _EDIT_HEIGHT,
    )

_CONTROLS = {
    "checkbox": {
        "type": "bool",
        "uses": [],
        "required": False,
        "default": _default_checkbox,
        "layout": _layout_checkbox,
    },
    "number": {
        "type": "int",
        "uses": ["min", "max"],
        "required": False,
        "default": _default_number,
        "layout": _layout_edit,
    },
    "text": {
        "type": "string",
        "uses": ["max_length"],
        "required": True,
        "default": _default_string,
        "layout": _layout_edit,
    },
    "password": {
        "type": "secret",
        "uses": ["max_length"],
        "required": True,
        "default": _default_string,
        "layout": _layout_edit,
    },
    "radio": {
        "type": "enum",
        "uses": ["choices"],
        "required": False,
        "default": _default_enum,
        "layout": _layout_radio,
    },
    "droplist": {
        "type": "enum",
        "uses": ["choices"],
        "required": False,
        "default": _default_enum,
        "layout": _layout_droplist,
    },
    "richedit": {
        "type": "multiline",
        "uses": ["max_length", "lines"],
        "required": True,
        "default": _default_richedit,
        "layout": _layout_multiline,
    },
    "file_request": {
        "type": "file",
        "uses": ["filter", "save", "must_exist"],
        "required": True,
        "default": _default_path,
        "layout": _layout_edit,
    },
    "dir_request": {
        "type": "dir",
        "uses": ["must_exist"],
        "required": True,
        "default": _default_path,
        "layout": _layout_edit,
    },
    "combobox": {
        "type": "string",
        "uses": ["choices", "max_length"],
        "optional_choices": True,
        "required": True,
        "default": _default_combobox,
        "layout": _layout_droplist,
    },
    "listbox": {
        "type": "enum",
        "uses": ["choices", "multi_select", "lines"],
        "required": True,
        "default": _default_list,
        "layout": _layout_multiline,
    },
    "sorted_listbox": {
        "type": "enum",
        "uses": ["choices", "multi_select", "lines"],
        "required": True,
        "default": _default_list,
        "layout": _layout_multiline,
    },
    "date": {
        "type": "date",
        "uses": ["min", "max"],
        "required": False,
        "default": _default_date,
        "layout": _layout_edit,
    },
    "ip_address": {
        "type": "ipv4",
        "uses": [],
        "required": True,
        "default": _default_ip,
        "layout": _layout_edit,
    },
    "net_address": {
        "type": "net",
        "uses": ["address_types"],
        "required": True,
        "default": _default_net,
        "layout": _layout_edit,
    },
}

_ADDRESS_BASE_TYPES = ["ipv4", "ipv6", "dns"]
_ADDRESS_TYPES = _ADDRESS_BASE_TYPES + ["with_port", "with_prefix"]

def _net_flags(label, types):
    """Maps address_types to the NET_STRING_* mask of ParseNetworkString."""
    for t in types:
        if t not in _ADDRESS_TYPES:
            _fail(label, "address_types entry '{}' must be one of {}".format(t, _ADDRESS_TYPES))
    if len(types) != len(set(types)):
        _fail(label, "address_types contains duplicates")
    if not types:
        types = _ADDRESS_BASE_TYPES
    bases = [t for t in types if t in _ADDRESS_BASE_TYPES]
    if not bases:
        _fail(label, "address_types needs at least one of ipv4, ipv6 or dns")
    port = "with_port" in types
    prefix = "with_prefix" in types
    if prefix and bases == ["dns"]:
        _fail(label, "address_types: with_prefix needs ipv4 or ipv6")
    flags = 0
    if "ipv4" in types:
        flags |= 0x1 | (0x2 if port else 0) | (0x4 if prefix else 0)
    if "ipv6" in types:
        flags |= 0x8 | (0x20 if port else 0) | (0x80 if prefix else 0)
    if "dns" in types:
        flags |= 0x100 | (0x200 if port else 0)
    return flags

# Attr name -> value that means "not set".
_CONTROL_ATTRS = {
    "choices": [],
    "multi_select": False,
    "min": "",
    "max": "",
    "max_length": 0,
    "lines": 0,
    "filter": "",
    "save": False,
    "must_exist": False,
    "address_types": [],
}

def _option_attrs(ctx):
    return struct(
        control = ctx.attr.control,
        default = ctx.attr.default,
        required = ctx.attr.required,
        choices = list(ctx.attr.choices),
        multi_select = ctx.attr.multi_select,
        min = ctx.attr.min,
        max = ctx.attr.max,
        max_length = ctx.attr.max_length,
        lines = ctx.attr.lines,
        filter = ctx.attr.filter,
        save = ctx.attr.save,
        must_exist = ctx.attr.must_exist,
        address_types = list(ctx.attr.address_types),
    )

def _validate_choices(label, choices):
    seen = set()
    for c in choices:
        if not c:
            _fail(label, "choices must not contain an empty value")
        if "|" in c:
            _fail(label, "choice '{}' contains '|', which separates list values".format(c))
        if "\n" in c or "\r" in c:
            _fail(label, "choice '{}' contains a line break".format(c))
        if c.lower() in seen:
            _fail(label, "choice '{}' is duplicated (choices are compared case-insensitively)".format(c))
        seen.add(c.lower())

def _nsis_option_impl(ctx):
    label = str(ctx.label)
    key = ctx.attr.key or ctx.label.name
    if not _is_ident(key):
        _fail(label, "key '{}' must match [a-z][a-z0-9_]*".format(key))

    a = _option_attrs(ctx)
    control = a.control
    spec = _CONTROLS.get(control)
    if spec == None:
        _fail(label, "control '{}' is not yet supported".format(control))

    for attr_name, unset in _CONTROL_ATTRS.items():
        if getattr(a, attr_name) != unset and attr_name not in spec["uses"]:
            _fail(label, "attribute '{}' is not used by control '{}'".format(attr_name, control))
    if a.required and not spec["required"]:
        _fail(label, "attribute 'required' is not used by control '{}'".format(control))

    persist = ctx.attr.persist
    if persist == "yes" and spec["type"] == "secret":
        _fail(label, "password options are never persisted; persist = \"yes\" is not allowed")
    effective_persist = (persist == "yes") or (persist == "auto" and spec["type"] != "secret")

    lo = ""
    hi = ""
    if "choices" in spec["uses"]:
        if not a.choices and not spec.get("optional_choices"):
            _fail(label, "control '{}' requires choices".format(control))
        _validate_choices(label, a.choices)
    if "max_length" in spec["uses"] and a.max_length < 0:
        _fail(label, "max_length must not be negative")
    if "lines" in spec["uses"] and a.lines < 0:
        _fail(label, "lines must not be negative")
    if a.required and "multi_select" in spec["uses"] and not a.multi_select:
        _fail(label, "attribute 'required' is only used by control '{}' with multi_select".format(control))
    if control == "number":
        if a.min:
            lo = _parse_int(a.min)
            if lo == None:
                _fail(label, "min '{}' is not a 32-bit integer".format(a.min))
        if a.max:
            hi = _parse_int(a.max)
            if hi == None:
                _fail(label, "max '{}' is not a 32-bit integer".format(a.max))
        if lo and hi and int(lo) > int(hi):
            _fail(label, "min ({}) is greater than max ({})".format(lo, hi))
    elif control == "date":
        if a.min:
            lo = _parse_date(a.min)
            if lo == None:
                _fail(label, "min '{}' is not a date (YYYY-MM-DD)".format(a.min))
        if a.max:
            hi = _parse_date(a.max)
            if hi == None:
                _fail(label, "max '{}' is not a date (YYYY-MM-DD)".format(a.max))
        if lo and hi and lo > hi:
            _fail(label, "min ({}) is greater than max ({})".format(lo, hi))
    if control == "file_request" and a.filter:
        parts = a.filter.split("|")
        if len(parts) % 2 != 0 or "" in parts:
            _fail(label, "filter '{}' must be pairs of 'name|pattern' separated by '|'".format(a.filter))
    net_flags = 0
    if control == "net_address":
        net_flags = _net_flags(label, a.address_types)
    if control in ["number", "date"]:
        a = struct(**dict({k: getattr(a, k) for k in _CONTROL_ATTRS.keys()}, min = lo, max = hi, control = a.control, default = a.default, required = a.required))

    default = spec["default"](label, a)

    return [NsisOptionInfo(
        label = label,
        name = ctx.label.name,
        key = key,
        control = control,
        type = "list" if a.multi_select else spec["type"],
        text = ctx.attr.label_text or _title_case(ctx.label.name),
        description = ctx.attr.description,
        default = default,
        required = a.required,
        enabled_by = str(ctx.attr.enabled_by.label) if ctx.attr.enabled_by else "",
        persist = effective_persist,
        choices = a.choices,
        multi_select = a.multi_select,
        min = a.min,
        max = a.max,
        max_length = a.max_length,
        lines = a.lines,
        filter = a.filter,
        save = a.save,
        must_exist = a.must_exist,
        address_types = a.address_types,
        net_flags = net_flags,
    )]

nsis_option = rule(
    implementation = _nsis_option_impl,
    doc = """
A single installer option, shown as one control on an `nsis_options_page`.

The value is available to install and uninstall hooks through
`${Option_Get} <page> <key> $var`, can be set from the command line with
`/O:<page>.<key>=<value>`, and is persisted for the uninstaller and upgrades
unless `persist = "no"`.
""",
    attrs = {
        "key": attr.string(
            default = "",
            doc = "The option key, [a-z][a-z0-9_]*. Defaults to the rule name.",
        ),
        "control": attr.string(
            default = "text",
            values = _CONTROL_NAMES,
            doc = """
The control kind, which determines the backing data type: `checkbox` (bool),
`number` (int), `text` (string), `password` (secret string, never persisted),
`radio` and `droplist` (one of `choices`), `richedit` (multi-line text, stored
on one line with `\\n` and `\\\\` escapes), `file_request` and `dir_request`
(absolute paths with a Browse button), `combobox` (text with suggested
`choices`), `listbox` and `sorted_listbox` (one of `choices`, or a `|` separated
list with `multi_select`), `date` (YYYY-MM-DD), `ip_address` (IPv4) and
`net_address` (see `address_types`).
""",
        ),
        "label_text": attr.string(
            default = "",
            doc = "The UI text. Defaults to the rule name in Title Case.",
        ),
        "description": attr.string(
            default = "",
            doc = "Help text shown under the control.",
        ),
        "default": attr.string(
            default = "",
            doc = """
The default value in the canonical form of the backing type. String types may
reference NSIS variables such as `$DOCUMENTS`. When empty: unchecked, the
number closest to 0 within min/max, an empty string, or the first choice.
""",
        ),
        "required": attr.bool(
            default = False,
            doc = "Whether the value must be non-empty (not for number, checkbox, radio, droplist and date).",
        ),
        "enabled_by": attr.label(
            providers = [NsisOptionInfo],
            doc = "A checkbox option on the same page; this control is disabled while it is unchecked.",
        ),
        "persist": attr.string(
            default = "auto",
            values = _PERSIST_VALUES,
            doc = "auto: persisted, except passwords. yes: always. no: never. password + yes is an error.",
        ),
        "choices": attr.string_list(
            default = [],
            doc = "The valid values of radio, droplist, listbox and sorted_listbox controls; the suggestions of combobox.",
        ),
        "multi_select": attr.bool(default = False, doc = "List controls: select several values."),
        "min": attr.string(default = "", doc = "Lower bound of number (integer) and date (YYYY-MM-DD) controls."),
        "max": attr.string(default = "", doc = "Upper bound of number (integer) and date (YYYY-MM-DD) controls."),
        "max_length": attr.int(default = 0, doc = "Maximum text length, 0 for unlimited."),
        "lines": attr.int(default = 0, doc = "Height of richedit, listbox and sorted_listbox in text lines, 0 for the default (4)."),
        "filter": attr.string(default = "", doc = "file_request: dialog filter, e.g. `Executables|*.exe|All files|*.*`."),
        "save": attr.bool(default = False, doc = "file_request: use a save dialog (the file need not exist)."),
        "must_exist": attr.bool(default = False, doc = "file_request, dir_request: the path must exist."),
        "address_types": attr.string_list(default = [], doc = "net_address: any of `ipv4`, `ipv6`, `dns` (at least one) plus `with_port` and `with_prefix`. Empty means ipv4, ipv6 and dns."),
    },
)

def _nsis_option_group_impl(ctx):
    infos = [o[NsisOptionInfo] for o in ctx.attr.options]
    return [NsisOptionGroupInfo(
        label = str(ctx.label),
        name = ctx.label.name,
        text = ctx.attr.label_text or _title_case(ctx.label.name),
        enabled_by = str(ctx.attr.enabled_by.label) if ctx.attr.enabled_by else "",
        options = infos,
    )]

nsis_option_group = rule(
    implementation = _nsis_option_group_impl,
    doc = "A group box around several `nsis_option`s on a page. Groups do not nest and carry no value.",
    attrs = {
        "label_text": attr.string(
            default = "",
            doc = "The group box caption. Defaults to the rule name in Title Case.",
        ),
        "options": attr.label_list(
            providers = [NsisOptionInfo],
            allow_empty = False,
            mandatory = True,
            doc = "The options inside the group, top to bottom.",
        ),
        "enabled_by": attr.label(
            providers = [NsisOptionInfo],
            doc = "A checkbox option on the same page; the whole group is disabled while it is unchecked.",
        ),
    },
)

def _option_ds(page, opt, x, width, y, in_group):
    """Returns the data source entry of an option laid out at y."""
    spec = _CONTROLS[opt.control]
    a = struct(choices = opt.choices, lines = opt.lines)
    lay = spec["layout"](a)
    height = lay.height
    desc_lines = _lines(opt.description)
    desc_y = y + height + 2
    if desc_lines:
        height += 2 + desc_lines * _LINE_HEIGHT
    choice_ys = [y + lay.control_offset + i * lay.choice_height for i in range(len(opt.choices))] if lay.choice_height else []
    return {
        "Key": opt.key,
        "Id": "{}.{}".format(page, opt.key),
        "Var": "__opt_{}_{}".format(page, opt.key),
        "Page": page,
        "Control": opt.control,
        "Type": opt.type,
        "Label": opt.text,
        "HasLabel": lay.has_label,
        "Description": opt.description,
        "Default": opt.default,
        "Choices": opt.choices,
        "ChoiceYs": choice_ys,
        "MultiSelect": opt.multi_select,
        "Min": opt.min,
        "Max": opt.max,
        "AllowNegative": opt.control != "number" or (not opt.min) or int(opt.min) < 0,
        "MaxLength": opt.max_length,
        "Lines": opt.lines,
        "Filter": opt.filter,
        "Save": opt.save,
        "MustExist": opt.must_exist,
        "AddressTypes": opt.address_types,
        "NetStringFlags": opt.net_flags,
        "Required": opt.required,
        "EnabledBy": "",
        "EnabledChain": [],
        "Persist": opt.persist,
        "Secret": opt.type == "secret",
        "InGroup": in_group,
        "X": x,
        "Width": width,
        "Y": y,
        "Height": height,
        "LabelY": y,
        "ControlY": y + lay.control_offset,
        "ControlHeight": lay.control_height,
        "TextWidth": ("70%" if in_group else "78%") if opt.control in ["file_request", "dir_request"] else width,
        "BrowseX": "76%" if in_group else "80%",
        "BrowseWidth": "18%" if in_group else "20%",
        "DescriptionY": desc_y,
        "DescriptionHeight": desc_lines * _LINE_HEIGHT,
        "HasDependents": False,
    }

def _enabled_chain(label, start, parent_of):
    """Returns the checkbox keys that must all be checked, nearest first."""
    chain = []
    seen = set()
    cur = start
    for _ in range(len(parent_of) + 1):
        if not cur:
            return chain
        if cur in seen:
            _fail(label, "enabled_by forms a cycle through '{}'".format(cur))
        seen.add(cur)
        if cur not in chain:
            chain.append(cur)
        cur = parent_of.get(cur, "")
    _fail(label, "enabled_by forms a cycle")

def _nsis_options_page_impl(ctx):
    label = str(ctx.label)
    name = ctx.label.name
    if not _is_ident(name):
        _fail(label, "page name '{}' must match [a-z][a-z0-9_]*".format(name))
    if name in _RESERVED_PAGES:
        _fail(label, "page name '{}' is reserved".format(name))

    # Flat view: option label -> info, in page order; group membership.
    options = {}
    keys = {}
    group_of = {}
    entries = []
    groups = {}
    for dep in ctx.attr.options:
        if NsisOptionGroupInfo in dep:
            g = dep[NsisOptionGroupInfo]
            if g.label in groups:
                _fail(label, "group '{}' is listed twice".format(g.name))
            groups[g.label] = g
            entries.append(g)
            for o in g.options:
                if o.label in options:
                    _fail(label, "option '{}' is listed twice".format(o.name))
                options[o.label] = o
                group_of[o.label] = g
        else:
            o = dep[NsisOptionInfo]
            if o.label in options:
                _fail(label, "option '{}' is listed twice".format(o.name))
            options[o.label] = o
            entries.append(o)

    for o in options.values():
        if o.key in keys:
            _fail(label, "duplicate option key '{}' on page '{}' (options '{}' and '{}')".format(o.key, name, keys[o.key], o.name))
        keys[o.key] = o.name

    def _check_enabler(owner, enabled_by):
        if not enabled_by:
            return
        enabler = options.get(enabled_by)
        if enabler == None:
            _fail(label, "{} is enabled_by '{}', which is not on page '{}'".format(owner, enabled_by, name))
        if enabler.control != "checkbox":
            _fail(label, "{} is enabled_by option '{}', which is a '{}'; it must be a checkbox".format(owner, enabler.name, enabler.control))

    # Parent links (key -> key) for cycle detection and chains.
    parent_of = {}
    for o in options.values():
        _check_enabler("option '{}'".format(o.name), o.enabled_by)
        g = group_of.get(o.label)
        parent = o.enabled_by
        if parent:
            parent_of[o.key] = options[parent].key
    for g in groups.values():
        _check_enabler("group '{}'".format(g.name), g.enabled_by)
        if g.enabled_by:
            for child in g.options:
                if child.label == g.enabled_by:
                    _fail(label, "group '{}' is enabled_by '{}', which is inside the group".format(g.name, child.name))

    def chain_for(o, g):
        start_keys = []
        if o.enabled_by:
            start_keys.append(options[o.enabled_by].key)
        if g != None and g.enabled_by:
            start_keys.append(options[g.enabled_by].key)
        result = []
        for k in start_keys:
            for c in _enabled_chain(label, k, parent_of):
                if c not in result:
                    result.append(c)
        return result

    items = []
    flat = []
    flat_groups = []
    y = 0
    text_y = 0
    text_height = 0
    if ctx.attr.text:
        text_height = _lines(ctx.attr.text) * _LINE_HEIGHT
        y = text_height + _GAP

    dependents = {}
    for e in entries:
        if type(e) == "struct" and hasattr(e, "options"):
            g = e
            gy = y
            gx = 0
            inner_y = gy + _GROUP_HEADER
            children = []
            for o in g.options:
                ds = _option_ds(name, o, "{}u".format(_GROUP_INDENT), "92%", inner_y, True)
                ds["EnabledBy"] = options[o.enabled_by].key if o.enabled_by else ""
                ds["EnabledChain"] = chain_for(o, g)
                for k in ds["EnabledChain"]:
                    dependents[k] = True
                children.append(ds)
                flat.append(ds)
                inner_y += ds["Height"] + _GAP
            gheight = (inner_y - _GAP + _GROUP_PADDING) - gy
            gds = {
                "Index": len(flat_groups),
                "Label": g.text,
                "EnabledBy": options[g.enabled_by].key if g.enabled_by else "",
                "EnabledChain": chain_for_group(g, options, parent_of, label),
                "X": "0u",
                "Width": "100%",
                "Y": gy,
                "Height": gheight,
                "Options": children,
            }
            for k in gds["EnabledChain"]:
                dependents[k] = True
            flat_groups.append(gds)
            items.append({"IsGroup": True, "Group": gds})
            y = gy + gheight + _GAP
        else:
            ds = _option_ds(name, e, "0u", "100%", y, False)
            ds["EnabledBy"] = options[e.enabled_by].key if e.enabled_by else ""
            ds["EnabledChain"] = chain_for(e, None)
            for k in ds["EnabledChain"]:
                dependents[k] = True
            items.append(dict(ds, IsGroup = False))
            flat.append(ds)
            y += ds["Height"] + _GAP

    used = y - _GAP if (items or ctx.attr.text) else 0
    if used > _PAGE_HEIGHT:
        _fail(label, "the page content needs {}u of height but only {}u are available; split the options across several pages".format(used, _PAGE_HEIGHT))

    for ds in flat:
        ds["HasDependents"] = ds["Key"] in dependents
    for it in items:
        if not it["IsGroup"]:
            it["HasDependents"] = it["Key"] in dependents

    page_ds = {
        "Name": name,
        "Label": label,
        "Title": ctx.attr.title or _title_case(name),
        "Subtitle": ctx.attr.subtitle,
        "Text": ctx.attr.text,
        "TextY": text_y,
        "TextHeight": text_height,
        "Position": ctx.attr.position,
        "PositionRank": _POSITION_RANK[ctx.attr.position],
        "Order": ctx.attr.order,
        "OwningComponents": [],
        "Always": True,
        "Internal": False,
        "PreCreate": "",
        "PostLeave": "",
        "Items": items,
        "Options": flat,
        "Groups": flat_groups,
    }
    return [NsisOptionsPageInfo(
        label = label,
        name = name,
        position = ctx.attr.position,
        ds = page_ds,
    )]

def chain_for_group(g, options, parent_of, label):
    if not g.enabled_by:
        return []
    return _enabled_chain(label, options[g.enabled_by].key, parent_of)

nsis_options_page = rule(
    implementation = _nsis_options_page_impl,
    doc = """
An installer page showing options. Attach it with `nsis_installer.options_pages`
(always shown) or `nsis_component.options_pages` (shown when the component is
selected, only at `position = "after_components"`).
""",
    attrs = {
        "title": attr.string(default = "", doc = "The page title. Defaults to the rule name in Title Case."),
        "subtitle": attr.string(default = "", doc = "The page subtitle."),
        "text": attr.string(default = "", doc = "An optional paragraph at the top of the page."),
        "options": attr.label_list(
            providers = [
                [NsisOptionInfo],
                [NsisOptionGroupInfo],
            ],
            doc = "The options and option groups, top to bottom.",
        ),
        "position": attr.string(
            default = "after_components",
            values = _POSITIONS,
            doc = "Where the page is placed. All positions are before the files are installed.",
        ),
        "order": attr.int(default = 0, doc = "Tie-break within a position, then by rule name."),
    },
)

def _page_sort_key(page):
    return (page["PositionRank"], page["Order"], page["Name"])

def collect_options_pages(label, installer_pages, components):
    """Merges the installer's and the components' pages into data source entries.

    Args:
        label: The installer label, for error messages.
        installer_pages: Targets of the installer's `options_pages`.
        components: The unique NsisComponentInfo set of the installer.

    Returns:
        A struct of `pages` (sorted by position, order, name) and `options`
        (every option of every page, flat).
    """
    pages = {}
    by_name = {}
    owners = {}
    always = set()

    for target in installer_pages:
        info = target[NsisOptionsPageInfo]
        pages[info.label] = info
        always.add(info.label)

    for cmp in components:
        for target in cmp.options_pages:
            info = target[NsisOptionsPageInfo]
            if info.position != "after_components":
                fail("{}: page '{}' is attached to component '{}' and must use position = \"after_components\" (got \"{}\"); component selection is only known after the components page".format(
                    info.label,
                    info.name,
                    cmp.name,
                    info.position,
                ))
            pages[info.label] = info
            owners.setdefault(info.label, [])
            if cmp.name not in owners[info.label]:
                owners[info.label].append(cmp.name)

    var_names = {}
    result = []
    for plabel, info in pages.items():
        if info.name in by_name:
            fail("{}: duplicate options page name '{}' ({} and {})".format(label, info.name, by_name[info.name], plabel))
        by_name[info.name] = plabel
        ds = dict(info.ds)
        ds["Always"] = plabel in always
        ds["OwningComponents"] = owners.get(plabel, [])
        result.append(ds)
        for opt in ds["Options"]:
            if opt["Var"] in var_names:
                fail("{}: options '{}' and '{}' map to the same variable {}; rename one of the pages or keys".format(label, var_names[opt["Var"]], opt["Id"], opt["Var"]))
            var_names[opt["Var"]] = opt["Id"]

    result = sorted(result, key = _page_sort_key)
    options = []
    for p in result:
        options.extend(p["Options"])
    return struct(pages = result, options = options)
