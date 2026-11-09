#!/usr/bin/env python3
"""Hold a PR that changes the inventory until Operations comments "Inventory updated" (#224).

Gap: roamfit-prototype #52 merged before Operations commented "Inventory updated".
Rule:
- The PR body's "Inventory:" line starts with "no change" (any case), followed by the end of the
  line, ".", "!", ")" or " (": pass. A list marker and bold/italic markers are allowed.
  "no change to env vars; adds a service" is a listed change.
- No "Inventory:" line: fail, asking for one.
- Any other Inventory line: pass only once a PR comment confirms it. The comment's first line
  starts with "Inventory updated", then the end of the line, ".", "!", or a dash, colon or space
  and more text. A leading bracket and the opening clause after it (up to the first "(", ",", ";", " - " or sentence-ending "." or "!") have no "?" and no
  negation or pending word (no, not, pending, yet, waiting, todo, soon, later; #227 d). A "?" later on the line, such as in an API path, is fine. So "Inventory updated? Not yet." and
  "Inventory updated: no, still pending" don't count, but Operations' "Inventory updated
  (Operations, <time>), head <sha>: ... No new key ..." does.
- Lines inside fenced code blocks (``` or ~~~) are ignored in the body and in comments.
- Stale confirmations (#227 a): a confirmation counts only if it was posted after the Inventory
  line took its current value. The PR body's edit history (EDITS_FILE: GitHub's
  userContentEdits, each {"editedAt", "diff"} where diff is the full body of that revision)
  shows when that was. Pushes don't matter, because the line lives in the body. A change in
  case, spacing or bold markers only is not a change.
Every agent, Operations included, comments as the same GitHub account, so authors can't be
told apart. A comment counts by its text only. Comments from bots such as github-actions are
ignored. Python standard library only. It reads PR_BODY (env), COMMENTS_FILE (a JSON list of
GitHub issue comments) and EDITS_FILE (optional, the body's edit history), and never prints the
body or a comment back.
"""
import json, os, re, sys

LIST_MARKER = re.compile(r'^\s*[-*+]\s+')
EMPHASIS = re.compile(r'[*_]+')  # bold/italic markers around the label and/or the value
INVENTORY = re.compile(r'^Inventory:\s*(.*)$', re.IGNORECASE)
NO_CHANGE = re.compile(r'^no change(?:$|[.!)]| \()', re.IGNORECASE)  # value is already free of * and _
UPDATED = re.compile(r'^(?:\*\*)?Inventory updated(?:\*\*)?(?:$|[.!]|\s*[-\u2013\u2014:]|\s)(.*)$', re.IGNORECASE)
NOT_DONE = re.compile(r'\b(?:no|not|pending|yet|waiting|todo|soon|later)\b', re.IGNORECASE)
CLAUSE_END = re.compile(r'[(,;]| - |[.!](?:\s|$)')  # a sentence end closes it too (#256 QA)
FENCE = re.compile(r'^\s*(```|~~~)')


def unfenced(text):
    """The lines of text that are outside fenced code blocks (``` or ~~~)."""
    out, fence = [], None
    for line in (text or '').splitlines():
        m = FENCE.match(line)
        if m:
            if fence is None:
                fence = m.group(1)
            elif m.group(1) == fence:
                fence = None
            continue
        if fence is None:
            out.append(line)
    return out


def confirms(text):
    """True when the comment's first line (outside code fences) is a real "Inventory updated"."""
    lines = [l for l in unfenced(text) if l.strip()]
    if not lines:
        return False
    first = lines[0].strip()
    m = UPDATED.match(first)
    if not m:
        return False
    rest = m.group(1).lstrip()
    if rest.startswith('('):  # #227 (d): a leading bracket is checked too, e.g. "(not yet)"
        bracket, _, rest = rest[1:].partition(')')
        if '?' in bracket or NOT_DONE.search(bracket):
            return False
    clause = CLAUSE_END.split(rest, 1)[0]
    return '?' not in clause and not NOT_DONE.search(clause)


def inventory_line(body):
    """The text after the first "Inventory:" line start, or None if there is none."""
    for raw in unfenced(body):
        m = INVENTORY.match(EMPHASIS.sub('', LIST_MARKER.sub('', raw, count=1)).strip())
        if m:
            return m.group(1).strip()
    return None


def same_line(a, b):
    """Two Inventory values are the same if they differ only in case or spacing."""
    return a is not None and b is not None and ' '.join(a.split()).casefold() == ' '.join(b.split()).casefold()


def line_since(body, edits):
    """When the body's Inventory line took its current value (ISO time), or None if unknown.

    edits is GitHub's userContentEdits list for the PR body. Each revision's editedAt is when
    that body became current, and diff is that body in full. Not createdAt: on the node holding
    the original body GitHub sets createdAt to the first edit's time (seen on #238 and #240).
    Revisions whose text was deleted (diff null) are skipped. None means the body was never
    edited, so every comment counts.
    """
    revisions = sorted((e for e in edits or [] if isinstance(e, dict) and isinstance(e.get('diff'), str)
                        and isinstance(e.get('editedAt'), str)), key=lambda e: e['editedAt'], reverse=True)
    if not revisions:
        return None
    current, since = inventory_line(body), revisions[0]['editedAt']
    for rev in revisions:
        if not same_line(inventory_line(rev['diff']), current):
            break
        since = rev['editedAt']
    return since


def operations_confirmed(comments, since=None):
    """True when a non-bot comment starts with "Inventory updated" (posted after since, if set)."""
    for c in comments or []:
        if not isinstance(c, dict):
            continue
        user = c.get('user') or {}
        if user.get('type') == 'Bot' or str(user.get('login', '')).endswith('[bot]'):
            continue
        if since is not None and not (isinstance(c.get('created_at'), str) and c['created_at'] > since):
            continue
        if isinstance(c.get('body'), str) and confirms(c['body']):
            return True
    return False


def decide(body, comments, edits=None):
    """(passed, short description of 140 chars or fewer for the commit status)."""
    line = inventory_line(body)
    if line is None:
        return False, 'No "Inventory:" line in the PR body. Add "Inventory: no change" or what changes.'
    if NO_CHANGE.match(line):
        return True, 'Inventory: no change.'
    if operations_confirmed(comments, line_since(body, edits)):
        return True, 'Inventory changes; Operations commented "Inventory updated".'
    if operations_confirmed(comments):
        return False, 'Inventory line changed after the last "Inventory updated" comment; waiting for a new one.'
    return False, 'Inventory changes: waiting for Operations to comment "Inventory updated".'


def main():
    path = os.environ.get('COMMENTS_FILE')
    comments = []
    if path:
        with open(path, encoding='utf-8') as f:
            comments = json.load(f)
    edits = None
    edits_path = os.environ.get('EDITS_FILE')
    if edits_path:
        try:
            with open(edits_path, encoding='utf-8') as f:
                edits = json.load(f)
        except (OSError, ValueError):
            edits = None
        if not isinstance(edits, list):
            # Unreadable history: use the rule from before #227 (any confirmation counts).
            edits = None
            print("::warning title=Inventory gate::PR body edit history unreadable; any Operations "
                  "confirmation counts.", file=sys.stderr)
    passed, why = decide(os.environ.get('PR_BODY') or '', comments, edits)
    print(json.dumps({'state': 'success' if passed else 'failure', 'description': why}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
