"""Testing.nsh cases."""

load(":defs.bzl", "include_api_case")

_TEST_ID = ['${SetTestId} "framework-test-id"']

def testing_cases():
    cases = include_api_case(
        name = "test_id",
        api = "testing",
        include = "Testing.nsh",
        symbol = "GetTestId",
        un_symbol = "GetTestId",
        parameters = ["out:value"],
        on_init = _TEST_ID,
    )

    # SetTestId's effect is observed by test_id, which sets the id in .onInit.
    cases += include_api_case(
        name = "test_id_set",
        api = "testing",
        include = "Testing.nsh",
        symbol = "SetTestId",
        un_symbol = "SetTestId",
        parameters = ["in:id"],
    )
    cases += include_api_case(
        name = "test_id_init",
        api = "testing",
        include = "Testing.nsh",
        src = "testing_adapters.nsh",
        symbol = "HarnessTestIdInit",
        un_symbol = "HarnessTestIdInit",
        parameters = ["in:testid", "out:value"],
    )

    # The production build (no TESTABLE_INSTALLER) is never in a test.
    for name, symbol, on_init, testable in [
        ("if_test", "IfTest", _TEST_ID, True),
        ("if_test_unset", "IfTest", [], True),
        ("if_test_production", "IfTest", [], False),
        ("if_not_test", "IfNotTest", [], True),
        ("if_not_test_set", "IfNotTest", _TEST_ID, True),
        ("if_not_test_production", "IfNotTest", [], False),
    ]:
        cases += include_api_case(
            name = name,
            api = "testing",
            include = "Testing.nsh",
            symbol = symbol,
            un_symbol = symbol,
            kind = "condition",
            invocation = "statement",
            parameters = ["out:matched:bool"],
            on_init = on_init,
            testable = testable,
        )
    return cases
