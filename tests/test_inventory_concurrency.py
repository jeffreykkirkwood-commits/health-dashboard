"""#239: the Inventory updated workflow must not leave cancelled runs on main's commits.

Comment (issue_comment) runs are filed by GitHub against main's newest commit, and Render's
"deploy after checks pass" waits on every check there. These tests read the workflow's
concurrency block and work out, for each event, which group a run joins and whether a newer
run would cancel it.
"""
import re
import unittest
from pathlib import Path

WORKFLOW = Path(__file__).resolve().parents[1] / '.github' / 'workflows' / 'inventory-updated.yml'


def concurrency():
    text = WORKFLOW.read_text()
    block = re.search(r'^concurrency:\n((?:  .*\n)+)', text, re.M)
    assert block, 'workflow has no top-level concurrency block'
    fields = dict(re.findall(r'^  ([\w-]+): (.*)$', block.group(1), re.M))
    return fields['group'], fields['cancel-in-progress']


def evaluate(expr, event_name, number, run_id):
    """Evaluate the small subset of GitHub expressions this block uses."""
    def one(inner):
        inner = inner.strip()
        inner = inner.replace('github.event.pull_request.number || github.event.issue.number', repr(str(number)))
        inner = inner.replace('github.event_name', repr(event_name))
        inner = inner.replace('github.run_id', repr(str(run_id)))
        inner = inner.replace('&&', ' and ').replace('||', ' or ')
        value = eval(inner, {'__builtins__': {}})  # synthetic, fixed text from our own workflow
        return value
    parts = re.split(r'(\$\{\{.*?\}\})', expr)
    if len(parts) == 3 and parts[0] == parts[2] == '':
        return one(parts[1][3:-2])
    return ''.join(str(one(p[3:-2])) if p.startswith('${{') else p for p in parts)


class Concurrency(unittest.TestCase):
    def setUp(self):
        self.group, self.cancel = concurrency()

    def test_comment_runs_are_never_cancelled(self):
        self.assertIs(evaluate(self.cancel, 'issue_comment', 7, 1001), False)

    def test_two_comment_runs_on_the_same_pr_never_share_a_group(self):
        # A shared group would also cancel a *pending* run, even with cancel-in-progress off.
        a = evaluate(self.group, 'issue_comment', 7, 1001)
        b = evaluate(self.group, 'issue_comment', 7, 1002)
        self.assertNotEqual(a, b)

    def test_comment_runs_on_different_prs_never_share_a_group(self):
        self.assertNotEqual(evaluate(self.group, 'issue_comment', 7, 1001),
                            evaluate(self.group, 'issue_comment', 8, 1001))

    def test_pr_runs_still_replace_older_runs_of_the_same_pr(self):
        self.assertIs(evaluate(self.cancel, 'pull_request', 7, 1001), True)
        self.assertEqual(evaluate(self.group, 'pull_request', 7, 1001),
                         evaluate(self.group, 'pull_request', 7, 1002))

    def test_pr_runs_never_cancel_comment_runs(self):
        self.assertNotEqual(evaluate(self.group, 'pull_request', 7, 1001),
                            evaluate(self.group, 'issue_comment', 7, 1001))

    def test_pr_runs_of_different_prs_do_not_cancel_each_other(self):
        self.assertNotEqual(evaluate(self.group, 'pull_request', 7, 1),
                            evaluate(self.group, 'pull_request', 8, 1))

    def test_triggers_unchanged(self):
        text = WORKFLOW.read_text()
        self.assertIn('pull_request:\n    types: [opened, edited, synchronize, reopened]', text)
        self.assertIn('issue_comment:\n    types: [created, edited, deleted]', text)


if __name__ == '__main__':
    unittest.main()
