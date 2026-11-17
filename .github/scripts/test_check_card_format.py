"""Checks the card-format script: the body sections, the PR title category
(junkjaws-app #148), and the Inventory line in Proof (#222)."""
import importlib.util
import io
import os
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / '.github' / 'scripts' / 'check_card_format.py'
spec = importlib.util.spec_from_file_location('check_card_format', SCRIPT)
ccf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ccf)

CARD = ('\n## Type\nFix\n## What changes\nA thing.\n## Who notices and how\nNobody.\n'
        '## Files touched\n- a.py\n## Proof\nTests pass.\nInventory: no change\n')
TITLE = '[Bug fix] Fix a synthetic thing'
CATEGORIES = ('[Product enhancement]', '[Bug fix]', '[Security]', '[Vulnerability patch]',
              '[Resiliency]', '[Build & tooling]')


def run(body, title=TITLE):
    buf = io.StringIO()
    with patch.dict(os.environ, {'PR_TITLE': title, 'PR_BODY': body}), redirect_stdout(buf):
        return ccf.main(), buf.getvalue()


class CardFormatTest(unittest.TestCase):
    def test_full_card_passes_and_missing_section_fails(self):
        self.assertEqual(run(CARD)[0], 0)
        code, out = run(CARD.replace('## Proof\nTests pass.\nInventory: no change\n', ''))
        self.assertEqual(code, 1)
        self.assertIn('Missing section: ## Proof', out)
        self.assertNotIn('Title', out)


class TitleCategoryTest(unittest.TestCase):
    def test_each_category_passes(self):
        for tag in CATEGORIES:
            self.assertEqual(run(CARD, title=tag + ' Do a thing')[0], 0, tag)

    def test_title_without_a_category_fails_and_lists_all_six(self):
        code, out = run(CARD, title='Fix a synthetic thing')
        self.assertEqual(code, 1)
        self.assertIn('Title does not start with a category', out)
        for tag in CATEGORIES:
            self.assertIn(tag, out)

    def test_near_misses_fail(self):
        for title in ('[bug fix] Lowercase', '[Bug Fix] Typo', '[Bug fix]No space', 'Bug fix: no brackets',
                      ' [Bug fix] Leading space', '[Feature] Not a category', 'Fix [Bug fix] not first',
                      '[Bug fix]', '[Bug fix]   ', ''):
            self.assertEqual(run(CARD, title=title)[0], 1, repr(title))

    def test_two_categories_fail(self):
        code, out = run(CARD, title='[Bug fix] [Security] Both')
        self.assertEqual(code, 1)
        self.assertIn('more than one category', out)

    def test_missing_title_env_fails(self):
        with patch.dict(os.environ, {'PR_BODY': CARD}), redirect_stdout(io.StringIO()):
            os.environ.pop('PR_TITLE', None)
            self.assertEqual(ccf.main(), 1)


class InventoryLineTest(unittest.TestCase):
    def with_inventory(self, line):
        return CARD.replace('Inventory: no change\n', line)

    def test_missing_inventory_line_fails(self):
        code, out = run(self.with_inventory(''))
        self.assertEqual(code, 1)
        self.assertIn("Missing 'Inventory:' line in ## Proof", out)
        self.assertIn('Inventory: no change', out)

    def test_empty_inventory_line_fails(self):
        for line in ('Inventory:\n', 'Inventory:   \n', '**Inventory:** \n', 'Inventory: -\n'):
            code, out = run(self.with_inventory(line))
            self.assertEqual(code, 1, repr(line))
            self.assertIn("'Inventory:' line in ## Proof is empty", out)

    def test_no_change_passes(self):
        self.assertEqual(run(self.with_inventory('Inventory: no change\n'))[0], 0)

    def test_named_change_passes(self):
        for line in ('Inventory: adds env var name FOO_URL\n', '**Inventory:** adds env var name FOO_URL\n',
                     '- inventory: no change. CI check only.\n'):
            self.assertEqual(run(self.with_inventory(line))[0], 0, repr(line))

    def test_inventory_list_on_following_lines_passes(self):
        for block in ('Inventory:\n- adds env var name FOO_URL\n- no service change\n',
                      '**Inventory:**\n\n* adds env var name FOO_URL\n',
                      'Inventory:\n1. adds env var name FOO_URL\n'):
            self.assertEqual(run(self.with_inventory(block))[0], 0, repr(block))

    def test_inventory_followed_by_plain_text_or_empty_bullet_still_empty(self):
        for block in ('Inventory:\nSee above.\n', 'Inventory:\n- \n'):
            code, out = run(self.with_inventory(block))
            self.assertEqual(code, 1, repr(block))
            self.assertIn("'Inventory:' line in ## Proof is empty", out)

    def test_inventory_inside_comment_or_other_section_does_not_count(self):
        self.assertEqual(run(self.with_inventory('<!-- Inventory: no change -->\n'))[0], 1)
        body = self.with_inventory('').replace('## Type\nFix', '## Type\nFix\nInventory: no change')
        self.assertEqual(run(body)[0], 1)


if __name__ == '__main__':
    unittest.main()
