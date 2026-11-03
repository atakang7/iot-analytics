import tempfile
import unittest
from pathlib import Path
import runpy

_checks = runpy.run_path(str(Path(__file__).with_name('verify-docs.py')))
check_links = _checks['check_links']
check_style = _checks['check_style']
check_readme = _checks['check_readme']


class DocumentationChecks(unittest.TestCase):
    def test_relative_link_exists(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "start.md").write_text("hello")
            self.assertEqual(check_links(root, root / "start.md", "[start](start.md)"), [])

    def test_missing_link_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            problems = check_links(root, root / "start.md", "[bad](not-a-page.md)")
            self.assertEqual(len(problems), 1)

    def test_links_cannot_escape_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            problems = check_links(root, root / "start.md", "[bad](../../etc/passwd)")
            self.assertEqual(len(problems), 1)

    def test_external_link_is_out_of_scope(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(check_links(root, root / "start.md", "[a](https://example.org)"), [])

    def test_component_readme_requires_root_link(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            child = root / "services" / "ingestion" / "README.md"
            child.parent.mkdir(parents=True)
            good = "Part of [iot-analytics](../../README.md).\n"
            self.assertEqual(check_readme(root, child, good), [])
            self.assertTrue(check_readme(root, child, "# ingestion\n"))
            self.assertTrue(check_readme(root, child, good + "line\n" * 61))

    def test_root_readme_limit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertTrue(check_readme(root, root / "README.md", "line\n" * 81))

    def test_ai_stock_phrases_are_rejected(self):
        self.assertTrue(check_style(Path("x.md"), "A pivotal development"))
        self.assertTrue(check_style(Path("x.md"), "Place \u2014 explanation."))
        self.assertFalse(check_style(Path("x.md"), "Consumers commit after durable writes."))


if __name__ == "__main__":
    unittest.main()
