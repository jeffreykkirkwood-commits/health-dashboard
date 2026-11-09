"""Inventory updated gate (#224). Synthetic PR bodies and comments only, no network."""
import importlib.util
import io
import json
import os
import re
import shutil
import stat
import subprocess
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / '.github' / 'scripts' / 'check_inventory_updated.py'
WORKFLOW = ROOT / '.github' / 'workflows' / 'inventory-updated.yml'
spec = importlib.util.spec_from_file_location('check_inventory_updated', SCRIPT)
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)

CHANGE = 'Does a thing.\n\n## Proof\n- tests\n\nInventory: adds env var EXAMPLE_FLAG on the demo service'
NO_CHANGE = 'Does a thing.\n\nInventory: no change (reads an existing setting)'


def comment(body, login='jeffreykkirkwood-commits', kind='User'):
    return {'body': body, 'user': {'login': login, 'type': kind}}


def run(body, comments):
    with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as f:
        json.dump(comments, f)
    out = io.StringIO()
    try:
        with mock.patch.dict(os.environ, {'PR_BODY': body, 'COMMENTS_FILE': f.name}), redirect_stdout(out):
            code = check.main()
    finally:
        os.unlink(f.name)
    return code, json.loads(out.getvalue())


class NoChange(unittest.TestCase):
    def test_no_change_passes_without_a_comment(self):
        for line in ('Inventory: no change', 'Inventory: No change (x)', 'inventory: NO CHANGE.',
                     '**Inventory:** no change', '- Inventory: no change'):
            self.assertEqual(check.decide('Text\n' + line, [])[0], True, line)

    def test_real_markdown_forms_from_open_prs(self):
        # Synthetic copies of the Inventory lines on open PRs #219, #220/#222 and #223.
        for line in ('- Inventory: no change',
                     '- **Inventory: no change.** No new service, env var or permission.',
                     '- **Inventory: no change.**',
                     '* _Inventory:_ *no change*', '**Inventory**: no change!', '  -   Inventory: __no change__!'):
            self.assertEqual(check.decide('Text\n\n## Proof\n- ok\n' + line, []), (True, 'Inventory: no change.'), line)

    def test_real_change_line_needs_the_comment(self):
        # Synthetic copy of #218's line: it lists a change, so it waits for Operations.
        body = ('## Proof\n- ok\n- Inventory: no new env var, key, service or permission. With live reads on, '
                'the existing OPS_DASHBOARD_GH_READ_TOKEN is also used for one more read.')
        passed, why = check.decide(body, [])
        self.assertFalse(passed)
        self.assertIn('waiting for Operations', why)
        self.assertTrue(check.decide(body, [comment('Inventory updated (Operations)')])[0])

    def test_no_change_must_start_the_line(self):
        self.assertFalse(check.decide('Inventory: adds X, otherwise no change', [])[0])

    def test_missing_inventory_line_fails_and_says_so(self):
        passed, why = check.decide('Just a description.\n## Proof\n- ok', [])
        self.assertFalse(passed)
        self.assertIn('No "Inventory:" line', why)
        self.assertFalse(check.decide('', [])[0])
        self.assertFalse(check.decide(None, None)[0])

    def test_inventory_mid_sentence_is_not_the_line(self):
        self.assertFalse(check.decide('See the Inventory: no change note elsewhere', [])[0])


class Change(unittest.TestCase):
    def test_change_without_a_comment_waits(self):
        passed, why = check.decide(CHANGE, [])
        self.assertFalse(passed)
        self.assertIn('waiting for Operations', why)

    def test_operations_comment_passes(self):
        for text in ('Inventory updated (Operations, 2026-11-04 12:10 PM ET), head 568d72b: ...',
                     'inventory updated', '**Inventory updated** for this change'):
            self.assertTrue(check.decide(CHANGE, [comment('QA PASS'), comment(text)])[0], text)

    def test_other_comments_do_not_count(self):
        for text in ('QA PASS on abc1234', 'Waiting for Inventory updated from Operations',
                     'Inventory not updated yet', 'Inventory update pending', ''):
            self.assertFalse(check.decide(CHANGE, [comment(text)])[0], text)

    def test_bot_comments_do_not_count(self):
        for c in (comment('Inventory updated', 'github-actions[bot]', 'Bot'),
                  comment('Inventory updated', 'some-app[bot]', 'User'),
                  comment('Inventory updated', 'helper', 'Bot')):
            self.assertFalse(check.decide(CHANGE, [c])[0], c)

    def test_malformed_comments_are_ignored(self):
        self.assertFalse(check.decide(CHANGE, [None, 'Inventory updated', {'body': 5}, {}])[0])
        self.assertTrue(check.decide(CHANGE, [{'body': 'Inventory updated'}])[0])


class LookAlikes(unittest.TestCase):
    def test_question_or_no_is_not_a_confirmation(self):
        for text in ('Inventory updated? Not yet.', 'inventory updated: no, still pending',
                     'Inventory updated yet? Checking.'):
            with self.subTest(text=text):
                self.assertFalse(check.decide(CHANGE, [comment(text)])[0])

    def test_no_change_to_something_is_a_change(self):
        for line in ('Inventory: no change to env vars; adds a new Render service',
                     'Inventory: no change for the API, but adds a key name',
                     'Inventory: no change except a new env var'):
            with self.subTest(line=line):
                self.assertFalse(check.decide(line, [])[0])

    def test_real_confirmations_and_no_change_lines_still_pass(self):
        self.assertTrue(check.decide(CHANGE, [comment('Inventory updated (Operations, synthetic note).')])[0])
        self.assertTrue(check.decide(CHANGE, [comment('**Inventory updated**')])[0])
        self.assertTrue(check.decide('Inventory: no change (CI workflow and script only)', [])[0])
        self.assertTrue(check.decide('Inventory: no change.', [])[0])

class QaFindings(unittest.TestCase):
    """QA ISSUES on a065fd4 (#225): wrong wording that must not turn the check green."""
    # Synthetic copies of Operations' real comments on roamfit-prototype #52 and ops-dashboard #218.
    ROAMFIT_52 = ('Inventory updated (Operations, 2026-11-04 12:10 PM ET), head 568d72b: health reply now includes '
                  'the running commit from `RENDER_GIT_COMMIT`; no new env var, key or setting; commit ID publicly '
                  'visible on `/healthz`.\n\nLive check: merged as 5a2482d ... PASS.')
    OPS_218 = ('Inventory updated (Operations, 2026-11-04 12:48 PM ET), head 0ee2f75: the GitHub REST API row now '
               'lists the new reads, `/repos/<repo>/pulls?state=closed` (5 app repos, 60 s cache), using the existing `OPS_DASHBOARD_GH_READ_TOKEN`. No new key, env var, service '
               'or setting. The key\'s scope on those 5 repos is still UNVERIFIED and needs answering before live data goes on.')

    def test_operations_real_comments_pass(self):
        for text in (self.ROAMFIT_52, self.OPS_218):
            self.assertTrue(check.confirms(text), text[:40])
            self.assertTrue(check.decide(CHANGE, [comment(text)])[0])

    def test_allowed_confirmation_shapes(self):
        for text in ('Inventory updated', 'Inventory updated.', 'inventory updated!', 'Inventory updated - row added',
                     'Inventory updated: Render row added', 'Inventory updated \u2014 done', '**Inventory updated**',
                     'Inventory updated\nsecond line may say not yet', '\n\nInventory updated (Operations)'):
            self.assertTrue(check.confirms(text), text)

    def test_question_negation_or_pending_fails(self):
        for text in ('Inventory updated? Not yet.', 'inventory updated: no, still pending', 'Inventory updated?',
                     'Inventory updated - not yet', 'Inventory updated: pending', 'Inventory updated: waiting on Ops',
                     'Inventory updated: TODO', 'Inventory updated yet?', 'Inventory updated. Not yet',
                     'Inventory updatedness', 'Inventory updated, head abc? (Operations)'):
            self.assertFalse(check.confirms(text), text)
            self.assertFalse(check.decide(CHANGE, [comment(text)])[0], text)

    def test_no_change_followed_by_more_is_a_listed_change(self):
        for line in ('Inventory: no change to env vars; adds a new Render service', 'Inventory: no changes yet, adds a key',
                     'Inventory: no change; adds a key', 'Inventory: no change, except a new key',
                     '- **Inventory: no change** to env vars, adds a service'):
            passed, why = check.decide('Text\n' + line, [])
            self.assertFalse(passed, line)
            self.assertIn('waiting for Operations', why, line)

    def test_real_open_pr_lines_still_pass(self):
        # Synthetic copies of the real lines on #219, #220, #221, #222 and #223.
        for line in ('- Inventory: no change',
                     '- **Inventory: no change.** No new service, key, setting or env var.',
                     'Inventory: no change (reads RENDER_GIT_COMMIT, which Render already provides; no new env var or setting)',
                     '- **Inventory: no change.** The switch already exists, and no new key, setting or service is added.',
                     '- **Inventory: no change.**', 'Inventory: no change!', '*Inventory: no change*'):
            self.assertTrue(check.decide('Text\n' + line, [])[0], line)

    def test_fenced_lines_are_ignored_in_the_body(self):
        for fence in ('```', '~~~'):
            body = f'Text\n{fence}\nInventory: no change\n{fence}\nInventory: adds a new Render service'
            self.assertFalse(check.decide(body, [])[0], fence)
            self.assertIsNone(check.inventory_line(f'{fence}text\nInventory: no change\n{fence}'))
        self.assertTrue(check.decide('```\nInventory: adds X\n```\nInventory: no change', [])[0])
        # a ~~~ line inside a ``` block does not close it
        self.assertIsNone(check.inventory_line('```\n~~~\nInventory: no change\n```x'))

    def test_fenced_lines_are_ignored_in_comments(self):
        for text in ('```\nInventory updated\n```', '~~~\nInventory updated (Operations)\n~~~\nQA PASS'):
            self.assertFalse(check.confirms(text), text)
        self.assertTrue(check.confirms('```\nlog\n```\nInventory updated (Operations)'))


class LookAlikesD(unittest.TestCase):
    """#227 (d), from QA on #225: look-alikes that used to pass. Synthetic text only."""

    def test_qa_look_alikes_do_not_count(self):
        for text in ('Inventory updated (not yet)', 'Inventory updated soon',
                     'Inventory updated (pending)', 'Inventory updated (waiting for Operations)',
                     'Inventory updated (Operations?)', 'Inventory updated (no)', 'Inventory updated (TODO)',
                     'Inventory updated: soon', 'Inventory updated later', '**Inventory updated** soon',
                     'Inventory updated (not yet) - Operations', 'Inventory updated: not yet. Done soon.',
                     'Inventory updated. Not yet.', 'Inventory updated (Operations): pending. Row next.'):
            with self.subTest(text=text):
                self.assertFalse(check.confirms(text), text)
                self.assertFalse(check.decide(CHANGE, [comment(text)])[0], text)

    def test_real_operations_shapes_still_count(self):
        # Shapes of Operations' real confirmations on Nov 4, 2026 (synthetic times and shas).
        for text in ('Inventory updated (Operations, Nov 4, 2026, 7:42 PM ET, head `abc1234`): adds one workflow row.',
                     'Inventory updated (Operations, Nov 4, 2026, 2:03 PM ET): ops-dashboard row updated.',
                     'Inventory updated (Operations, 2026-11-04 12:48 PM ET), head abc1234: No new key.',
                     "Inventory updated: I've added a new GitHub Actions workflow to the row.",
                     '**Inventory updated** (Operations)', 'Inventory updated  (Operations)',
                     # QA on #256: a sentence after the bracket's colon ends the clause at "."
                     'Inventory updated (Operations, Nov 4, 2026, 7:42 PM ET, head `abc1234`): added key. No new key.',
                     'Inventory updated: added a row! No new key.'):
            with self.subTest(text=text):
                self.assertTrue(check.confirms(text), text)
                self.assertTrue(check.decide(CHANGE, [comment(text)])[0], text)

    def test_a_dot_inside_a_word_does_not_end_the_clause(self):
        # #260 (b), from QA on #256: only "." or "!" followed by a space or the line end closes it.
        for text in ('Inventory updated: app.py row not done', 'Inventory updated: v1.2 row pending',
                     'Inventory updated: done.Later'):
            with self.subTest(text=text):
                self.assertFalse(check.confirms(text), text)
                self.assertFalse(check.decide(CHANGE, [comment(text)])[0], text)
        for text in ('Inventory updated: v1.2 row added', 'Inventory updated: app.py row added. No new key.'):
            with self.subTest(text=text):
                self.assertTrue(check.confirms(text), text)
                self.assertTrue(check.decide(CHANGE, [comment(text)])[0], text)


OTHER_CHANGE = 'Does a thing.\n\n## Proof\n- tests\n\nInventory: adds env var OTHER_FLAG and a new key'


def at(body, when, login='jeffreykkirkwood-commits', kind='User'):
    return {**comment(body, login, kind), 'created_at': when}


def rev(body, when):
    # Shaped like a later edit in GitHub's userContentEdits: editedAt == createdAt.
    return {'createdAt': when, 'editedAt': when, 'updatedAt': when, 'deletedAt': None, 'diff': body}


class StaleConfirmation(unittest.TestCase):
    """#227 (a): a confirmation counts only if posted after the Inventory line took its value."""
    OK = 'Inventory updated (Operations, synthetic)'

    def test_never_edited_body_any_confirmation_counts(self):
        self.assertTrue(check.decide(CHANGE, [at(self.OK, '2026-11-04T10:00:00Z')], [])[0])
        self.assertIsNone(check.line_since(CHANGE, []))

    def test_old_confirmation_does_not_cover_a_new_inventory_line(self):
        edits = [rev(OTHER_CHANGE, '2026-11-04T12:00:00Z'), rev(CHANGE, '2026-11-04T09:00:00Z')]
        passed, why = check.decide(OTHER_CHANGE, [at(self.OK, '2026-11-04T10:00:00Z')], edits)
        self.assertFalse(passed)
        self.assertIn('changed after the last "Inventory updated"', why)
        self.assertLessEqual(len(why), 140)

    def test_new_confirmation_after_the_change_passes(self):
        edits = [rev(OTHER_CHANGE, '2026-11-04T12:00:00Z'), rev(CHANGE, '2026-11-04T09:00:00Z')]
        comments = [at(self.OK, '2026-11-04T10:00:00Z'), at(self.OK, '2026-11-04T12:30:00Z')]
        self.assertTrue(check.decide(OTHER_CHANGE, comments, edits)[0])

    def test_edits_that_keep_the_inventory_line_do_not_ask_again(self):
        # Proof text edited twice after Operations confirmed; the Inventory line never changed.
        edits = [rev(CHANGE + '\n', '2026-11-04T13:00:00Z'),
                 rev(CHANGE.replace('- tests', '- tests, 600 OK'), '2026-11-04T11:00:00Z'),
                 rev(CHANGE, '2026-11-04T09:00:00Z')]
        self.assertEqual(check.line_since(CHANGE, edits), '2026-11-04T09:00:00Z')
        self.assertTrue(check.decide(CHANGE, [at(self.OK, '2026-11-04T10:00:00Z')], edits)[0])

    def test_case_spacing_or_bold_only_is_not_a_change(self):
        edits = [rev(CHANGE.replace('Inventory: adds', '**Inventory:**  Adds'), '2026-11-04T12:00:00Z'),
                 rev(CHANGE, '2026-11-04T09:00:00Z')]
        self.assertTrue(check.decide(CHANGE, [at(self.OK, '2026-11-04T10:00:00Z')], edits)[0])

    def test_line_changed_and_changed_back_needs_a_new_confirmation(self):
        edits = [rev(CHANGE, '2026-11-04T14:00:00Z'), rev(OTHER_CHANGE, '2026-11-04T12:00:00Z'),
                 rev(CHANGE, '2026-11-04T09:00:00Z')]
        self.assertFalse(check.decide(CHANGE, [at(self.OK, '2026-11-04T10:00:00Z')], edits)[0])
        self.assertTrue(check.decide(CHANGE, [at(self.OK, '2026-11-04T14:05:00Z')], edits)[0])

    def test_switching_to_no_change_passes_without_a_comment(self):
        edits = [rev(NO_CHANGE, '2026-11-04T12:00:00Z'), rev(CHANGE, '2026-11-04T09:00:00Z')]
        self.assertEqual(check.decide(NO_CHANGE, [], edits), (True, 'Inventory: no change.'))

    def test_comment_without_a_time_does_not_count_once_the_line_changed(self):
        edits = [rev(OTHER_CHANGE, '2026-11-04T12:00:00Z'), rev(CHANGE, '2026-11-04T09:00:00Z')]
        self.assertFalse(check.decide(OTHER_CHANGE, [comment(self.OK)], edits)[0])

    def test_deleted_revisions_and_junk_are_skipped(self):
        edits = [{'editedAt': '2026-11-04T13:00:00Z', 'diff': None}, 'junk', {'diff': CHANGE},
                 rev(OTHER_CHANGE, '2026-11-04T12:00:00Z'), rev(CHANGE, '2026-11-04T09:00:00Z')]
        self.assertEqual(check.line_since(OTHER_CHANGE, edits), '2026-11-04T12:00:00Z')

    def test_real_shaped_original_node_counts_from_its_editedat(self):
        # Copied from the real userContentEdits for #238 (fetched with gh api graphql), with
        # synthetic text. GitHub gives the node holding the ORIGINAL body the first edit's time
        # as createdAt (21:31:23Z); its editedAt (21:22:41Z) is when that text became current.
        edits = [
            {'createdAt': '2026-11-04T21:36:53Z', 'editedAt': '2026-11-04T21:36:53Z',
             'updatedAt': '2026-11-04T21:36:53Z', 'deletedAt': None,
             'diff': CHANGE.replace('- tests', '- tests, 664 OK, CI green')},
            {'createdAt': '2026-11-04T21:31:23Z', 'editedAt': '2026-11-04T21:31:23Z',
             'updatedAt': '2026-11-04T21:31:23Z', 'deletedAt': None,
             'diff': CHANGE.replace('- tests', '- tests, 664 OK')},
            {'createdAt': '2026-11-04T21:31:23Z', 'editedAt': '2026-11-04T21:22:41Z',
             'updatedAt': '2026-11-04T21:31:23Z', 'deletedAt': None, 'diff': CHANGE},
        ]
        body = edits[0]['diff']
        # Operations confirmed between creation and the first edit; the line never changed.
        self.assertEqual(check.line_since(body, edits), '2026-11-04T21:22:41Z')
        self.assertTrue(check.decide(body, [at(self.OK, '2026-11-04T21:25:00Z')], edits)[0])
        # A confirmation from before the PR existed still doesn't count.
        self.assertFalse(check.decide(body, [at(self.OK, '2026-11-04T21:20:00Z')], edits)[0])

    def test_real_shaped_line_change_after_confirmation_still_asks_again(self):
        # #240's shape: one edit, original node createdAt == the edit time.
        edits = [
            {'createdAt': '2026-11-04T22:47:49Z', 'editedAt': '2026-11-04T22:47:49Z',
             'updatedAt': '2026-11-04T22:47:49Z', 'deletedAt': None, 'diff': OTHER_CHANGE},
            {'createdAt': '2026-11-04T22:47:49Z', 'editedAt': '2026-11-04T22:43:06Z',
             'updatedAt': '2026-11-04T22:47:49Z', 'deletedAt': None, 'diff': CHANGE},
        ]
        self.assertEqual(check.line_since(OTHER_CHANGE, edits), '2026-11-04T22:47:49Z')
        self.assertFalse(check.decide(OTHER_CHANGE, [at(self.OK, '2026-11-04T22:45:00Z')], edits)[0])
        self.assertTrue(check.decide(OTHER_CHANGE, [at(self.OK, '2026-11-04T22:50:00Z')], edits)[0])

    def test_workflow_asks_for_editedat(self):
        text = WORKFLOW.read_text()
        self.assertIn('nodes { editedAt diff }', text)

    def test_main_reads_the_edits_file(self):
        edits = [rev(OTHER_CHANGE, '2026-11-04T12:00:00Z'), rev(CHANGE, '2026-11-04T09:00:00Z')]
        with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as e:
            json.dump(edits, e)
        with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as c:
            json.dump([at(self.OK, '2026-11-04T10:00:00Z')], c)
        out = io.StringIO()
        try:
            env = {'PR_BODY': OTHER_CHANGE, 'COMMENTS_FILE': c.name, 'EDITS_FILE': e.name}
            with mock.patch.dict(os.environ, env), redirect_stdout(out):
                check.main()
        finally:
            os.unlink(e.name)
            os.unlink(c.name)
        self.assertEqual(json.loads(out.getvalue())['state'], 'failure')


class Main(unittest.TestCase):
    def test_main_prints_state_and_short_description_only(self):
        code, out = run(CHANGE, [comment('Inventory updated (Operations)')])
        self.assertEqual((code, out['state']), (0, 'success'))
        code, out = run(CHANGE + ' secret-looking-text', [])
        self.assertEqual(out['state'], 'failure')
        self.assertNotIn('secret-looking-text', json.dumps(out))
        for body in (CHANGE, NO_CHANGE, ''):
            self.assertLessEqual(len(check.decide(body, [])[1]), 140)

    def test_no_change_main(self):
        self.assertEqual(run(NO_CHANGE, [])[1]['state'], 'success')


class Workflow(unittest.TestCase):
    def test_untrusted_text_is_never_interpolated_into_run(self):
        text = WORKFLOW.read_text()
        for bad in ('pull_request.body', 'comment.body', 'issue.body', 'pull_request.title', 'issue.title',
                    'head_ref', 'pull_request_target'):
            self.assertNotIn(bad, text, bad)

    def test_reruns_on_comment_delete_and_reads_edit_history(self):
        # #227 (b) and (a): deleting a confirmation re-runs the check; the body's edit history is read.
        text = WORKFLOW.read_text()
        self.assertIn('types: [created, edited, deleted]', text)
        self.assertIn('userContentEdits', text)
        self.assertIn('EDITS_FILE="$RUNNER_TEMP/edits.json"', text)

    def test_minimal_permissions_and_only_checkout(self):
        text = WORKFLOW.read_text()
        self.assertIn('statuses: write', text)
        self.assertNotIn('contents: write', text)
        self.assertNotIn('pull-requests: write', text)
        uses = [l.split('uses:')[1].strip() for l in text.splitlines() if l.strip().startswith(('uses:', '- uses:'))]
        self.assertTrue(uses and all(u.startswith('actions/checkout@') for u in uses), uses)


STUB_GH = r"""#!/usr/bin/env bash
# Synthetic stand-in for gh, used only inside this test's own PATH.
args="$*"
case "$args" in
  *graphql*)
    if [ "$STUB_GRAPHQL" = fail ]; then echo "gh: Resource not accessible by integration" >&2; exit 1; fi
    cat "$STUB_DIR/edits.json" ;;
  *"-X POST"*) printf '%s\n' "$@" > "$STUB_DIR/status_call" ;;
  *comments*) cat "$STUB_DIR/comments.json" ;;
  *pulls/*) cat "$STUB_DIR/pr.json" ;;
  *) echo "unexpected gh call" >&2; exit 2 ;;
esac
"""


def workflow_run_script():
    text = WORKFLOW.read_text()
    m = re.search(r'^        run: \|\n((?:          .*\n|\s*\n)+)', text, re.M)
    return '\n'.join(l[10:] for l in m.group(1).splitlines())


@unittest.skipUnless(shutil.which('bash') and shutil.which('jq'), 'needs bash and jq')
class WorkflowRunsWhenEditHistoryIsUnreadable(unittest.TestCase):
    """The Actions token gets "Resource not accessible by integration" for userContentEdits once a
    body was edited (run 41945462570). The step must fall back to the old rule, warn, and exit 0."""

    def run_step(self, graphql, body, comments, edits=()):
        d, runner_temp = tempfile.mkdtemp(), tempfile.mkdtemp()  # separate: the step writes into RUNNER_TEMP
        self.addCleanup(shutil.rmtree, d)
        self.addCleanup(shutil.rmtree, runner_temp)
        Path(d, 'pr.json').write_text(json.dumps({'head': {'sha': 'abc1234def'}, 'body': body}))
        Path(d, 'comments.json').write_text(json.dumps(list(comments)))
        Path(d, 'edits.json').write_text(json.dumps(list(edits)))
        gh = Path(d, 'bin', 'gh')
        gh.parent.mkdir()
        gh.write_text(STUB_GH)
        gh.chmod(gh.stat().st_mode | stat.S_IEXEC)
        env = {'PATH': f"{gh.parent}:{os.environ.get('PATH', '/usr/bin:/bin')}", 'HOME': d,
               'GH_TOKEN': 'synthetic', 'REPO': 'example/repo', 'PR_NUMBER': '7',
               'RUN_URL': 'https://example.invalid/run', 'RUNNER_TEMP': runner_temp,
               'STUB_DIR': d, 'STUB_GRAPHQL': graphql}
        p = subprocess.run(['bash', '-e', '-c', workflow_run_script()], cwd=ROOT, env=env,
                           capture_output=True, text=True, timeout=60)
        call = Path(d, 'status_call')
        return p, (call.read_text().splitlines() if call.exists() else None)

    def test_unreadable_history_warns_and_a_confirmation_still_counts(self):
        p, call = self.run_step('fail', OTHER_CHANGE, [at(StaleConfirmation.OK, '2026-11-04T10:00:00Z')])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('::warning', p.stdout + p.stderr)
        self.assertIn('edit history', p.stdout + p.stderr)
        self.assertIsNotNone(call)
        self.assertIn('repos/example/repo/statuses/abc1234def', call)
        self.assertIn('state=success', call)

    def test_unreadable_history_without_a_confirmation_still_waits(self):
        p, call = self.run_step('fail', CHANGE, [])
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('state=failure', call)

    def test_readable_history_still_catches_a_changed_line(self):
        edits = [rev(OTHER_CHANGE, '2026-11-04T12:00:00Z'), rev(CHANGE, '2026-11-04T09:00:00Z')]
        p, call = self.run_step('ok', OTHER_CHANGE, [at(StaleConfirmation.OK, '2026-11-04T10:00:00Z')], edits)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotIn('::warning', p.stdout + p.stderr)
        self.assertIn('state=failure', call)


class UnreadableEditsFile(unittest.TestCase):
    def test_broken_or_empty_edits_file_falls_back_to_the_old_rule(self):
        for content in ('', 'not json', '{"errors": []}'):
            with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as e:
                e.write(content)
            with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as c:
                json.dump([at(StaleConfirmation.OK, '2026-11-04T10:00:00Z')], c)
            out, err = io.StringIO(), io.StringIO()
            try:
                env = {'PR_BODY': OTHER_CHANGE, 'COMMENTS_FILE': c.name, 'EDITS_FILE': e.name}
                with mock.patch.dict(os.environ, env), redirect_stdout(out), mock.patch('sys.stderr', err):
                    code = check.main()
            finally:
                os.unlink(e.name)
                os.unlink(c.name)
            self.assertEqual(code, 0)
            self.assertEqual(json.loads(out.getvalue())['state'], 'success', content)
            self.assertIn('::warning', err.getvalue(), content)


if __name__ == '__main__':
    unittest.main()
