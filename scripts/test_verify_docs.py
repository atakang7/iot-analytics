import tempfile
import unittest
from pathlib import Path

from verify_docs import check_links, check_style


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

    def test_ai_stock_phrases_are_rejected(self):
        self.assertTrue(check_style(Path("x.md"), "A pivotal development"))
        self.assertTrue(check_style(Path("x.md"), "Place \u2014 explanation."))
        self.assertFalse(check_style(Path("x.md"), "Consumers commit after durable writes."))


if __name__ == "__main__":
    unittest.main()
