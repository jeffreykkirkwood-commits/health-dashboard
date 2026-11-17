#!/usr/bin/env python3
"""PR category label (#226): read the [Category] tag at the start of the PR title
and give the PR the matching "category: <name>" label, removing any other
category: label. A title with no tag changes nothing (the Card format check
from #213 is what fails it). The label is created with its agreed colour
(#212) the first time it's needed. Standard library only; GitHub calls go
through the gh CLI using the job's GITHUB_TOKEN.

Env: PR_TITLE, PR_NUMBER, REPO, LABELS (JSON list of the PR's label names).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from typing import Callable
from urllib.parse import quote

PREFIX = "category: "
# The six categories (#148) and their label colours (final table on #212).
COLOURS = {
    "Product enhancement": "1A6FCF",
    "Bug fix": "D73A4A",
    "Security": "5319E7",
    "Vulnerability patch": "B60205",
    "Resiliency": "0C7F14",
    "Build & tooling": "6E7781",
}

Runner = Callable[[list[str]], "subprocess.CompletedProcess[str]"]


def category_from_title(title: str) -> str | None:
    """The category named by the title's leading [tag] plus a space, or None."""
    for name in COLOURS:
        if title.startswith(f"[{name}] "):
            return name
    return None


def plan(title: str, labels: list[str]) -> tuple[str | None, list[str]]:
    """(label to add or None, category: labels to remove) for this title."""
    category = category_from_title(title)
    if category is None:
        return None, []
    wanted = PREFIX + category
    remove = [name for name in labels
              if name.lower().startswith(PREFIX.strip()) and name != wanted]
    return (None if wanted in labels else wanted), remove


def gh(args: list[str]) -> "subprocess.CompletedProcess[str]":
    return subprocess.run(["gh", "api", *args], capture_output=True, text=True, check=False)


def main(run: Runner = gh) -> int:
    title = os.environ.get("PR_TITLE") or ""
    number = os.environ.get("PR_NUMBER") or ""
    repo = os.environ.get("REPO") or ""
    labels = json.loads(os.environ.get("LABELS") or "[]")

    add, remove = plan(title, labels)
    if add is None and not remove:
        if category_from_title(title) is None:
            print("Title has no category tag; no label changed.")
        else:
            print("Category label already correct; nothing to do.")
        return 0

    failed = False
    if add is not None:
        colour = COLOURS[add[len(PREFIX):]]
        # Creating a label that already exists returns HTTP 422; that's fine.
        run(["-X", "POST", f"repos/{repo}/labels", "-f", f"name={add}", "-f", f"color={colour}"])
        result = run(["-X", "POST", f"repos/{repo}/issues/{number}/labels", "-f", f"labels[]={add}"])
        if result.returncode != 0:
            print(f"::error::Could not add '{add}' (gh exit {result.returncode}).")
            failed = True
        else:
            print(f"Added '{add}'.")
    for name in remove:
        result = run(["-X", "DELETE", f"repos/{repo}/issues/{number}/labels/{quote(name, safe='')}"])
        if result.returncode != 0:
            print(f"::error::Could not remove '{name}' (gh exit {result.returncode}).")
            failed = True
        else:
            print(f"Removed '{name}'.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
