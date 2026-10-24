"""Analysis-time failure tests for nsis_installer."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(
    "//nsis:defs.bzl",
    "nsis_component",
    "nsis_installer",
    "nsis_option",
    "nsis_option_group",
    "nsis_options_page",
    "nsis_plugin",
    "nsis_shortcut",
)
load("//nsis/private:dirrule.bzl", "dirrule")
def _eventlog_requires_admin_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "requires execution_level = \"admin\"")
    return analysistest.end(env)

eventlog_requires_admin_test = analysistest.make(
    _eventlog_requires_admin_test_impl,
    expect_failure = True,
)

def _expect_failure_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.expected)
    return analysistest.end(env)

_expect_failure_test = analysistest.make(
    _expect_failure_test_impl,
    expect_failure = True,
    attrs = {"expected": attr.string(mandatory = True)},
)

def options_failure_test(
        name,
        expected,
        options = [],
        groups = [],
        page = {},
        items = None,
        component_page = False):
    """Declares an installer with a bad options page and a test that expects `expected`.

    Args:
        name: The test name; also the page name (the page is `<name>_page`).
        expected: Text the analysis failure must contain.
        options: Dicts of nsis_option attrs plus `name`; `enabled_by` is a short name.
        groups: Dicts of nsis_option_group attrs plus `name` and `options` (short names).
        page: Extra nsis_options_page attrs.
        items: Short names (options or groups) the page lists; defaults to all of them.
        component_page: Attach the page to a component instead of the installer.
    """
    load_prefix = ":" + name + "_"

    def full(short):
        return load_prefix + short

    for o in options:
        o = dict(o)
        n = o.pop("name")
        if "enabled_by" in o:
            o["enabled_by"] = full(o["enabled_by"])
        nsis_option(name = name + "_" + n, tags = ["manual"], **o)
    for g in groups:
        g = dict(g)
        n = g.pop("name")
        g["options"] = [full(x) for x in g["options"]]
        if "enabled_by" in g:
            g["enabled_by"] = full(g["enabled_by"])
        nsis_option_group(name = name + "_" + n, tags = ["manual"], **g)
    if items == None:
        items = [o["name"] for o in options if not any([o["name"] in g["options"] for g in groups])] + [g["name"] for g in groups]
    page_name = page.get("page_name", name + "_page")
    page = {k: v for k, v in page.items() if k != "page_name"}
    nsis_options_page(
        name = page_name,
        options = [full(i) for i in items],
        tags = ["manual"],
        **page
    )
    nsis_component(
        name = name + "_component",
        srcs = ["//tests/testdata:README.md"],
        tags = ["manual"],
        options_pages = [":" + page_name] if component_page else [],
    )
    if component_page:
        nsis_installer(
            name = name + "_installer",
            id = "6b0c1d7a-0000-4000-8000-000000000001",
            components = [":" + name + "_component"],
            product = "Options Negative",
            product_path = "Options Negative",
            tags = ["manual"],
        )
    else:
        nsis_installer(
            name = name + "_installer",
            id = "6b0c1d7a-0000-4000-8000-000000000001",
            components = [":" + name + "_component"],
            options_pages = [":" + page_name],
            product = "Options Negative",
            product_path = "Options Negative",
            tags = ["manual"],
        )
    _expect_failure_test(
        name = name,
        target_under_test = ":" + name + "_installer",
        expected = expected,
    )

def shortcut_failure_test(
        name,
        expected,
        shortcut = {},
        shortcut2 = None,
        tree = False,
        installed = True):
    """Declares an installer with a bad nsis_shortcut and a test that expects `expected`.

    Args:
        name: The test name.
        expected: Text the analysis failure must contain.
        shortcut: nsis_shortcut attrs; `target` defaults to the component's README.md.
        shortcut2: attrs of an optional second shortcut on the same component.
        tree: Install the README.md as a directory artifact instead of a file.
        installed: Whether the component installs the shortcut's default target.
    """
    srcs = ["//tests/testdata:README.md"]
    if tree:
        dirrule(name = name + "_tree", srcs = srcs, tags = ["manual"])
        srcs = [":" + name + "_tree"]
    shortcuts = []
    for i, attrs in enumerate([shortcut, shortcut2]):
        if attrs == None:
            continue
        attrs = dict(attrs)
        attrs.setdefault("target", "//tests/testdata:README.md" if installed else "//tests/testdata:test_icon.ico")
        nsis_shortcut(name = "{}_shortcut{}".format(name, i), tags = ["manual"], **attrs)
        shortcuts.append(":{}_shortcut{}".format(name, i))
    nsis_component(
        name = name + "_component",
        srcs = srcs,
        shortcuts = shortcuts,
        tags = ["manual"],
    )
    nsis_installer(
        name = name + "_installer",
        id = "6b0c1d7a-0000-4000-8000-000000000002",
        components = [":" + name + "_component"],
        product = "Shortcuts Negative",
        product_path = "Shortcuts Negative",
        tags = ["manual"],
    )
    _expect_failure_test(
        name = name,
        target_under_test = ":" + name + "_installer",
        expected = expected,
    )

def _plugin_lines_test_impl(ctx):
    env = analysistest.begin(ctx)
    contents = [
        a.content
        for a in analysistest.target_actions(env)
        if a.mnemonic == "FileWrite" and a.outputs.to_list()[0].basename.endswith(".plugins.nsh")
    ]
    asserts.equals(env, 1, len(contents))
    lines = contents[0].splitlines() if contents else []
    for expected in ctx.attr.lines:
        matches = [l for l in lines if l.startswith(expected.split(" ...")[0]) and l.endswith(expected.split("... ")[-1])]
        asserts.equals(env, 1, len(matches), "{} not exactly once in {}".format(expected, lines))
    if ctx.attr.license:
        licenses = [f.short_path for f in analysistest.target_under_test(env)[OutputGroupInfo].plugin_licenses.to_list()]
        asserts.true(env, any([l.endswith(ctx.attr.license) for l in licenses]), "{} not in {}".format(ctx.attr.license, licenses))
    return analysistest.end(env)

# Each entry of `lines` is "<start> ... <end>" and must match exactly one line.
_plugin_lines_test = analysistest.make(
    _plugin_lines_test_impl,
    attrs = {
        "lines": attr.string_list(),
        "license": attr.string(),
    },
)

def plugin_tests(name):
    """Declares plugin analysis tests.

    The tests share dummy DLLs; analysis never reads their content.
    """
    for dll in ["p/p.dll", "x64/p.dll", "wrong/other.dll"]:
        native.genrule(
            name = "{}_dll_{}".format(name, dll.replace("/", "_").replace(".", "_")),
            outs = ["{}_dlls/{}".format(name, dll)],
            cmd = "touch $@",
            tags = ["manual"],
        )

    def dll(path):
        return ":{}_dll_{}".format(name, path.replace("/", "_").replace(".", "_"))

    nsis_plugin(name = name + "_wrong_name", plugin_name = "p", x86_unicode = dll("wrong/other.dll"), license = "//tests/testdata:README.md", tags = ["manual"])
    nsis_plugin(name = name + "_p", plugin_name = "p", x86_unicode = dll("p/p.dll"), amd64_unicode = dll("x64/p.dll"), license = "//tests/testdata:README.md", tags = ["manual"])

    nsis_component(name = name + "_component", srcs = ["//tests/testdata:README.md"], tags = ["manual"])

    def installer(suffix, plugins):
        nsis_installer(
            name = name + "_" + suffix + "_installer",
            id = "6b0c1d7a-0000-4000-8000-000000000003",
            components = [":" + name + "_component"],
            product = "Plugins " + suffix,
            product_path = "Plugins " + suffix,
            plugins = plugins,
            tags = ["manual"],
        )
        return ":{}_{}_installer".format(name, suffix)

    _expect_failure_test(
        name = name + "_wrong_name_test",
        target_under_test = installer("wrong_name", [":" + name + "_wrong_name"]),
        expected = "must be named p.dll",
    )
    _plugin_lines_test(
        name = name + "_same_label_test",
        target_under_test = installer("same_label", ["@nsis_plugin_nsarray//:plugin"]),
        lines = ['!addplugindir /x86-unicode ... nsis_plugin_nsarray/Plugins/x86-unicode"'],
    )
    _plugin_lines_test(
        name = name + "_lines_test",
        target_under_test = installer("lines", [":" + name + "_p"]),
        lines = [
            '!addplugindir /x86-unicode ... {}_dlls/p"'.format(name),
            '!addplugindir /amd64-unicode ... {}_dlls/x64"'.format(name),
            '!addplugindir /x86-unicode ... nsis_plugin_nsarray/Plugins/x86-unicode"',
            '!addincludedir ... nsis_plugin_nsarray/Include"',
        ],
        license = "Docs/nsArray/Readme.txt",
    )
