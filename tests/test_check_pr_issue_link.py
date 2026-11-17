"""Checks the #227 PR issue-link script: body text forms, HTML comments,
Dependabot skip, and a staging-target PR with only body text."""
import importlib.util
import io
import os
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / '.github' / 'scripts' / 'check_pr_issue_link.py'
spec = importlib.util.spec_from_file_location('check_pr_issue_link', SCRIPT)
cil = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cil)

ISSUE_URL = 'https://github.com/jeffreykkirkwood-commits/junkjaws-app/issues/227'
CARD = ('\n## Type\nAdd\n## What changes\nA thing.\n## Who notices and how\nNobody.\n'
        '## Files touched\n- a.py\n## Proof\nTests pass.\nInventory: no change\n')


def run(body, user='alice'):
    buf = io.StringIO()
    env = {'PR_BODY': body, 'PR_USER': user}
    with patch.dict(os.environ, env, clear=False), redirect_stdout(buf):
        return cil.main(), buf.getvalue()


class HasIssueLink(unittest.TestCase):
    def test_keyword_hash_forms(self):
        for line in ('Refs #227', 'closes #12', 'Fixes #3.', 'Resolves #99',
                     '**Refs #227**', 'Refs: #227', 'Closes [#12](%s)' % ISSUE_URL,
                     'Closes %s' % ISSUE_URL,
                     'Refs jeffreykkirkwood-commits/junkjaws-app#227'):
            self.assertTrue(cil.has_issue_link(line + CARD), line)

    def test_bare_cross_repo_and_url(self):
        self.assertTrue(cil.has_issue_link('See jeffreykkirkwood-commits/ops-dashboard#7' + CARD))
        self.assertTrue(cil.has_issue_link('Tracking: %s' % ISSUE_URL + CARD))

    def test_html_comment_does_not_count(self):
        self.assertFalse(cil.has_issue_link('<!-- Refs #227 -->' + CARD))
        self.assertFalse(cil.has_issue_link('<!-- Closes %s -->' % ISSUE_URL))

    def test_issue_label_without_keyword_fails(self):
        self.assertFalse(cil.has_issue_link('Issue: #227' + CARD))
        self.assertFalse(cil.has_issue_link('Mentions #227 only' + CARD))
        self.assertFalse(cil.has_issue_link(CARD))
        self.assertFalse(cil.has_issue_link(''))


class Main(unittest.TestCase):
    def test_no_link_fails_with_plain_message(self):
        code, out = run(CARD)
        self.assertEqual(code, 1)
        self.assertIn('PR issue-link check failed', out)
        self.assertIn("does not link an issue", out)
        self.assertIn("Refs #123", out)

    def test_refs_makes_it_pass(self):
        code, out = run('Refs #227\n' + CARD)
        self.assertEqual(code, 0)
        self.assertIn('passed', out)

    def test_staging_pr_with_body_text_only(self):
        # Acceptance + Jefe3.0 rule: a PR into staging counts from body text,
        # not GitHub's linked-issues field (which stays empty off default branch).
        body = 'Refs #227\nBase is staging; linked-issues field is empty.\n' + CARD
        code, out = run(body)
        self.assertEqual(code, 0)
        self.assertIn('passed', out)

    def test_dependabot_is_skipped(self):
        code, out = run('Dependabot bump with no Refs line.', user='dependabot[bot]')
        self.assertEqual(code, 0)
        self.assertIn('skipped', out)
        self.assertIn('dependabot[bot]', out)

    def test_missing_body_env_fails(self):
        buf = io.StringIO()
        with patch.dict(os.environ, {'PR_USER': 'alice'}, clear=False), redirect_stdout(buf):
            os.environ.pop('PR_BODY', None)
            self.assertEqual(cil.main(), 1)


if __name__ == '__main__':
    unittest.main()
