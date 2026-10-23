"""iCacls.nsh cases."""

load(":defs.bzl", "include_api_case")

def icacls_cases():
    cases = []
    for name, symbol, parameters in [
        ("icacls_grant", "iCacls_Grant", ["in:path", "in:sid", "in:permission", "in:recursive:int", "out:result"]),
        ("icacls_deny", "iCacls_Deny", ["in:path", "in:sid", "in:permission", "in:recursive:int", "out:result"]),
        ("icacls_remove_grant", "iCacls_RemoveGrant", ["in:path", "in:sid", "in:recursive:int", "out:result"]),
        ("icacls_remove_deny", "iCacls_RemoveDeny", ["in:path", "in:sid", "in:recursive:int", "out:result"]),
        ("icacls_integrity", "iCacls_IntegrityLevel", ["in:path", "in:level", "in:inheritance", "in:recursive:int", "out:result"]),
        ("icacls_substitute", "iCacls_Substitute", ["in:path", "in:old_sid", "in:new_sid", "in:recursive:int", "out:result"]),
    ]:
        cases += include_api_case(
            name = name,
            api = "icacls",
            include = "iCacls.nsh",
            symbol = symbol,
            # The macros only run icacls through nsExec, so they are context-free.
            un_symbol = symbol,
            parameters = parameters,
        )
    return cases
