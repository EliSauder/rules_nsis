from tests.includes import common

# Condition cases and whether they report an admin context.
_CONDITIONS = {
    "if_admin_after_admin": True,
    "if_admin_after_current": False,
    "if_admin_after_reset": False,
    "if_admin_after_reset_admin_level": True,
    "if_admin_default": False,
    "if_admin_default_admin_level": True,
    "if_not_admin_after_admin": False,
    "if_not_admin_after_current": True,
}


def run_case(case, harness, args):
    base = common.base(case)
    if base in ("shell_context_admin", "shell_context_current", "shell_context_set", "shell_context_reset"):
        assert harness.run().returncode == 0
    elif base in _CONDITIONS:
        harness.run().assert_outputs(admin=_CONDITIONS[base])
    else:
        raise common.unhandled(case)


if __name__ == "__main__":
    common.main(run_case)
