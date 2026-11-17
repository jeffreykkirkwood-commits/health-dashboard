#!/usr/bin/env python3
"""Fail a PR whose body does not link a tracking issue (#227).

Every PR should trace up to an initiative through an issue. GitHub's
"linked issues" field only fills for PRs into the default branch, and Junk Jaws
merges into staging first, so this check reads the PR body text only.

A link counts when the visible body (HTML comments stripped) contains any of:
  - Closes / Fixes / Resolves / Refs followed by #N, [#N](url), owner/repo#N,
    or a full github.com/.../issues/N URL
  - a bare owner/repo#N
  - a bare full github.com/.../issues/N URL

Dependabot PRs are skipped (their bodies are robot-written). Standard library
only. Env: PR_BODY, PR_USER (optional; dependabot[bot] skips).
"""
from __future__ import annotations

import os
import re
import sys

HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)

# Keyword forms (start of a word, optional colon, then the target).
KEYWORD_LINK = re.compile(
    r"(?i)\b(?:closes|fixes|resolves|refs):?[^\S\n]+"
    r"(?:#\d+\b|\[#\d+\]\(\S+\)|"
    r"https://github\.com/[\w.-]+/[\w.-]+/issues/\d+\b|"
    r"[\w.-]+/[\w.-]+#\d+\b)"
)

# Bare cross-repo shorthand and full issue URL (no keyword required).
CROSS_REPO = re.compile(r"(?<![\w/-])[\w.-]+/[\w.-]+#\d+\b")
ISSUE_URL = re.compile(r"https://github\.com/[\w.-]+/[\w.-]+/issues/\d+\b", re.IGNORECASE)

SKIP_USER = "dependabot[bot]"

FAIL_HINT = (
    "Add a line such as 'Refs #123' or 'Closes #123' to the PR body "
    "(a cross-repo owner/repo#123 or a full github.com/.../issues/123 URL "
    "also counts). Text inside HTML comments does not count."
)


def strip_noise(text: str) -> str:
    """Remove HTML comments and surrounding whitespace."""
    return HTML_COMMENT.sub("", text or "").strip()


def has_issue_link(body: str) -> bool:
    """True when the visible body links an issue in an accepted form."""
    text = strip_noise(body)
    if not text:
        return False
    return bool(
        KEYWORD_LINK.search(text)
        or CROSS_REPO.search(text)
        or ISSUE_URL.search(text)
    )


def main() -> int:
    user = (os.environ.get("PR_USER") or "").strip()
    if user == SKIP_USER:
        print(f"PR issue-link check skipped: opened by {SKIP_USER}.")
        return 0

    body = os.environ.get("PR_BODY")
    if body is None:
        body = ""

    if has_issue_link(body):
        print("PR issue-link check passed: the body links a tracking issue.")
        return 0

    print("PR issue-link check failed.")
    print("This pull request body does not link an issue.")
    print(FAIL_HINT)
    return 1


if __name__ == "__main__":
    sys.exit(main())
