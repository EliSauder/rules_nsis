"""Analysis-time failure tests for nsis_installer."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(
    "//nsis:defs.bzl",
    "nsis_component",
    "nsis_installer",
    "nsis_option",
    "nsis_option_group",
    "nsis_options_page",
)

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
