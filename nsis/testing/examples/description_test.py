"""Check Bazel-generated symbol descriptions against the generator contract."""

import json
import sys
import unittest
from pathlib import Path

from python.runfiles import Runfiles

from nsis.testing.generate import generate, validate


class DescriptionTest(unittest.TestCase):
    def test_generated_descriptions(self):
        runfiles = Runfiles.Create()
        description = json.loads(
            Path(runfiles.Rlocation(sys.argv[1])).read_text(encoding="utf-8")
        )
        self.assertEqual(validate(description), {
            "symbol": "un.Example",
            "kind": "definition",
            "context": "uninstaller",
            "parameters": [
                {"name": "second", "direction": "in"},
                {"name": "first", "direction": "out"},
                {"name": "third", "direction": "inout"},
            ],
            "invocation": "call",
            "defines": {"TEST_MODE": "value with spaces"},
        })
        script = generate(description, "example.nsh")
        self.assertIn(
            '${un.Example} "$_harness_param_second" $_harness_param_first $_harness_param_third',
            script,
        )
        constant = json.loads(
            Path(runfiles.Rlocation(sys.argv[2])).read_text(encoding="utf-8")
        )
        self.assertEqual(constant["invocation"], "value")
        self.assertIn(
            'StrCpy $_harness_param_result "${Answer}"',
            generate(constant, "example.nsh"),
        )


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
