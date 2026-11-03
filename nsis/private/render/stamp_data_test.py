import json
import tempfile
import unittest
from pathlib import Path

from nsis.private.render.stamp_data import _expand_tree_files, main


class TreeFilesTest(unittest.TestCase):
    def test_expands_nested_components_and_merges_trees(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first = root / "first"
            second = root / "second"
            (first / "nested" / "empty").mkdir(parents=True)
            (second / "nested").mkdir(parents=True)
            (first / "README.md").write_text("readme")
            (first / "nested" / "one.txt").write_text("one")
            (second / "nested" / "two.txt").write_text("two")
            component = {"Files": [], "Directories": [str(first), str(second)]}
            data = {"ComponentGroups": [{"Components": [component]}]}

            _expand_tree_files(data)

            self.assertCountEqual(
                component["TreeFiles"],
                ["README.md", "nested\\one.txt", "nested\\two.txt"],
            )
            self.assertEqual(
                component["TreeDirectories"], ["nested\\empty", "nested"]
            )

    def test_quotes_literal_nsis_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tree = root / "tree"
            tree.mkdir()
            (tree / "${NAME}.txt").write_text("literal name")
            component = {"Files": [], "Directories": [str(tree)]}
            source = root / "input.json"
            output = root / "output.json"
            source.write_text(json.dumps(component))

            main([str(source), str(output), "", ""])
            expanded = json.loads(output.read_text())

            self.assertEqual(expanded["TreeFiles"], ["$${NAME}.txt"])
            self.assertEqual(expanded["TreeDirectories"], [])

    def test_missing_tree_is_an_error(self):
        with tempfile.TemporaryDirectory() as temporary:
            component = {
                "Files": [], "Directories": [str(Path(temporary) / "missing")]
            }
            with self.assertRaises(FileNotFoundError):
                _expand_tree_files(component)


if __name__ == "__main__":
    unittest.main()
