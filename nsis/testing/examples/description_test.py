"""Check Bazel-generated symbol descriptions against the generator contract."""

import json
import sys
import unittest
from pathlib import Path

from python.runfiles import Runfiles

from nsis.testing.generate import validate


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
                {"name": "second", "direction": "in", "type": "int"},
                {"name": "first", "direction": "out", "type": "bool"},
                {"name": "third", "direction": "inout", "type": "string"},
            ],
            "invocation": "call",
            "defines": {"TEST_MODE": "value with spaces"},
        })
        constant = json.loads(
            Path(runfiles.Rlocation(sys.argv[2])).read_text(encoding="utf-8")
        )
        self.assertEqual(constant["invocation"], "value")


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
