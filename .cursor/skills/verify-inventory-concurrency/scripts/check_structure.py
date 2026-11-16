#!/usr/bin/env python3
"""Structural sync: inventory-updated.yml still encodes the #239 concurrency shape."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print('usage: check_structure.py <repo-root>', file=sys.stderr)
        return 2
    root = Path(sys.argv[1])
    wf = root / '.github' / 'workflows' / 'inventory-updated.yml'
    if not wf.is_file():
        print(f'FAIL: missing {wf}', file=sys.stderr)
        return 1
    text = wf.read_text()
    block = re.search(r'^concurrency:\n((?:  .*\n)+)', text, re.M)
    if not block:
        print('FAIL: no top-level concurrency block', file=sys.stderr)
        return 1
    fields = dict(re.findall(r'^  ([\w-]+): (.*)$', block.group(1), re.M))
    group = fields.get('group', '')
    cancel = fields.get('cancel-in-progress', '')
    problems = []
    # Comment runs must include run_id so they never share the PR group.
    if 'github.run_id' not in group:
        problems.append('group expression missing github.run_id (comment isolation)')
    if "github.event_name == 'pull_request' && 'pr'" not in group and \
       'github.event_name == "pull_request" && "pr"' not in group:
        # Allow either quote style; current file uses single quotes inside ${{ }}.
        if "'pr'" not in group and '"pr"' not in group:
            problems.append("group expression missing the 'pr' branch for pull_request events")
    # cancel-in-progress must be true only for pull_request.
    if 'pull_request' not in cancel:
        problems.append('cancel-in-progress must depend on pull_request event_name')
    if cancel.strip() in ('true', 'True', '"true"', "'true'"):
        problems.append('cancel-in-progress is unconditionally true (would cancel comment runs)')
    if problems:
        for p in problems:
            print(f'FAIL: {p}', file=sys.stderr)
        print('group=', group, file=sys.stderr)
        print('cancel=', cancel, file=sys.stderr)
        return 1
    print('OK: concurrency block matches #239 shape')
    print(f'  group: {group}')
    print(f'  cancel-in-progress: {cancel}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
