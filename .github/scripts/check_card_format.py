#!/usr/bin/env python3
"""Fail when a pull request body is missing required card-format sections."""

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
        print("Fill every required section in the pull request body:")
        for problem in problems:
            print(f"  - {problem}")
        print()
        print("Required headings: " + ", ".join(f"## {h}" for h in REQUIRED_HEADINGS))
        return 1

    print("Card format check passed: all required sections are present and non-blank.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
