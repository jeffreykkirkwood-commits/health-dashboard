"""Checks the card-format script: the body sections and the PR title category (junkjaws-app #148)."""
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
        '## Files touched\n- a.py\n## Proof\nTests pass.\n')
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
        code, out = run(CARD.replace('## Proof\nTests pass.\n', ''))
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
        for title in ('[bug fix] Lowercase', '[Bugfix] Typo', '[Bug fix]No space', 'Bug fix: no brackets',
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


if __name__ == '__main__':
    unittest.main()
