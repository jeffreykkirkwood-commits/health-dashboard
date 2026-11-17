"""Checks the PR category label script (#226): title tag -> category: label."""
import importlib.util
import io
import json
import os
import subprocess
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / '.github' / 'scripts' / 'category_label.py'
spec = importlib.util.spec_from_file_location('category_label', SCRIPT)
cl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cl)

REPO = 'example/demo'


class FakeGh:
    """Records gh api calls; any call whose args contain fail_on returns exit 1."""

    def __init__(self, fail_on=None):
        self.calls = []
        self.fail_on = fail_on

    def __call__(self, args):
        self.calls.append(args)
        code = 1 if self.fail_on and any(self.fail_on in a for a in args) else 0
        return subprocess.CompletedProcess(args, code, '', '')


def run(title, labels=(), fail_on=None):
    fake = FakeGh(fail_on)
    env = {'PR_TITLE': title, 'PR_NUMBER': '7', 'REPO': REPO, 'LABELS': json.dumps(list(labels))}
    buf = io.StringIO()
    with patch.dict(os.environ, env), redirect_stdout(buf):
        code = cl.main(fake)
    return code, fake.calls, buf.getvalue()


class CategoryFromTitleTest(unittest.TestCase):
    def test_each_category_tag_is_read(self):
        for name in cl.COLOURS:
            self.assertEqual(cl.category_from_title(f'[{name}] Do a thing'), name)

    def test_titles_without_a_leading_tag(self):
        for title in ('Bump playwright from 1.55.0 to 1.64.1', '[Bug fix]No space',
                      'Fix [Bug fix] later', '[bug fix] wrong case', '[Feature] Unknown', ''):
            self.assertIsNone(cl.category_from_title(title), title)

    def test_colours_match_the_212_table(self):
        self.assertEqual(cl.COLOURS['Product enhancement'], '1A6FCF')
        self.assertEqual(cl.COLOURS['Resiliency'], '0C7F14')
        self.assertEqual(len(cl.COLOURS), 6)


class MainTest(unittest.TestCase):
    def test_new_pr_gets_label_created_and_added(self):
        code, calls, _ = run('[Security] Redact tokens')
        self.assertEqual(code, 0)
        self.assertEqual(calls[0], ['-X', 'POST', f'repos/{REPO}/labels',
                                    '-f', 'name=category: Security', '-f', 'color=5319E7'])
        self.assertEqual(calls[1], ['-X', 'POST', f'repos/{REPO}/issues/7/labels',
                                    '-f', 'labels[]=category: Security'])
        self.assertEqual(len(calls), 2)

    def test_changing_the_tag_swaps_the_label(self):
        code, calls, out = run('[Bug fix] Now a fix', ['P0', 'category: Security'])
        self.assertEqual(code, 0)
        self.assertIn(['-X', 'POST', f'repos/{REPO}/issues/7/labels',
                       '-f', 'labels[]=category: Bug fix'], calls)
        self.assertEqual(calls[-1], ['-X', 'DELETE',
                                     f'repos/{REPO}/issues/7/labels/category%3A%20Security'])
        self.assertIn("Removed 'category: Security'", out)
        self.assertFalse(any('P0' in a for c in calls for a in c))

    def test_correct_label_already_there_makes_no_calls(self):
        code, calls, out = run('[Build & tooling] CI', ['category: Build & tooling'])
        self.assertEqual((code, calls), (0, []))
        self.assertIn('nothing to do', out)

    def test_stray_second_category_label_is_removed(self):
        code, calls, _ = run('[Resiliency] Retry', ['category: Resiliency', 'Category: Bug fix'])
        self.assertEqual(code, 0)
        self.assertEqual(calls, [['-X', 'DELETE',
                                  f'repos/{REPO}/issues/7/labels/Category%3A%20Bug%20fix']])

    def test_no_tag_changes_nothing(self):
        code, calls, out = run('Bump actions/checkout from 4 to 7', ['category: Security'])
        self.assertEqual((code, calls), (0, []))
        self.assertIn('no category tag', out)

    def test_ampersand_label_is_url_encoded_on_remove(self):
        _, calls, _ = run('[Bug fix] X', ['category: Build & tooling'])
        self.assertEqual(calls[-1][-1], f'repos/{REPO}/issues/7/labels/category%3A%20Build%20%26%20tooling')

    def test_label_already_existing_is_not_an_error(self):
        # The create call fails (HTTP 422 when it exists); adding still goes ahead.
        code, calls, _ = run('[Security] X', fail_on='color=')
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 2)

    def test_failed_add_or_remove_fails_the_job(self):
        self.assertEqual(run('[Security] X', fail_on='labels[]=')[0], 1)
        code, _, out = run('[Security] X', ['category: Security', 'category: Bug fix'],
                           fail_on='DELETE')
        self.assertEqual(code, 1)
        self.assertIn('::error::Could not remove', out)


if __name__ == '__main__':
    unittest.main()
