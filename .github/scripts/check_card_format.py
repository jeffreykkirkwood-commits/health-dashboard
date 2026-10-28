#!/usr/bin/env python3
"""Fail when a pull request title has no category or its body is missing card-format sections."""

from __future__ import annotations

import os
import re
import sys

REQUIRED_HEADINGS = (
    "Type",
    "What changes",
    "Who notices and how",
    "Files touched",
    "Proof",
)

# PR title rule (junkjaws-app #148): the title starts with exactly one of these
# categories in square brackets, then a space, then the rest of the title.
CATEGORIES = (
    "Product enhancement",
    "Bug fix",
    "Security",
    "Vulnerability patch",
    "Resiliency",
    "Build & tooling",
)
CATEGORY_TAGS = tuple(f"[{c}]" for c in CATEGORIES)


def title_problem(title: str) -> str | None:
    """Why the PR title does not start with exactly one category tag, or None if it does."""
    for tag in CATEGORY_TAGS:
        if title.startswith(tag + " "):
            rest = title[len(tag) + 1:].strip()
            if not rest:
                return f"Title has {tag} but nothing after it"
            if rest.startswith(CATEGORY_TAGS):
                return "Title starts with more than one category; use exactly one"
            return None
    return "Title does not start with a category in square brackets followed by a space"


HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
HEADING_LINE = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)


def strip_noise(text: str) -> str:
    """Remove HTML comments and surrounding whitespace."""
    return HTML_COMMENT.sub("", text).strip()


def section_bodies(body: str) -> dict[str, str]:
    """Map lowercased heading text to the raw body under that heading."""
    matches = list(HEADING_LINE.finditer(body))
    sections: dict[str, str] = {}
    for i, match in enumerate(matches):
        heading = match.group(1).strip()
        start = match.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
        sections[heading.lower()] = body[start:end]
    return sections


def main() -> int:
    body = os.environ.get("PR_BODY")
    if body is None:
        body = ""

    sections = section_bodies(body)
    problems: list[str] = []

    bad_title = title_problem(os.environ.get("PR_TITLE") or "")
    if bad_title:
        problems.append(bad_title)

    for required in REQUIRED_HEADINGS:
        key = required.lower()
        if key not in sections:
            problems.append(f"Missing section: ## {required}")
            continue
        content = strip_noise(sections[key])
        if not content:
            problems.append(f"Blank section: ## {required}")

    if problems:
        print("Card format check failed.")
        print("Fix the pull request title and fill every required section in the body:")
        for problem in problems:
            print(f"  - {problem}")
        print()
        print("Required headings: " + ", ".join(f"## {h}" for h in REQUIRED_HEADINGS))
        if bad_title:
            print("Start the title with one of these, then a space: "
                  + ", ".join(CATEGORY_TAGS))
        return 1

    print("Card format check passed: the title starts with a category and all required "
          "sections are present and non-blank.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
