"""Analysis-time failure tests for nsis_installer."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _eventlog_requires_admin_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "requires execution_level = \"admin\"")
    return analysistest.end(env)

eventlog_requires_admin_test = analysistest.make(
    _eventlog_requires_admin_test_impl,
    expect_failure = True,
)
