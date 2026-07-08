#!/usr/bin/env python3
"""Extract the CHANGELOG section for a given version.

For a single section only. GitHub releases use `aggregate_release_notes.py`
instead, which includes notes since the last stable version.

Usage:
    python3 scripts/extract_release_notes.py <version-or-tag>
"""

from __future__ import annotations

import pathlib
import re
import sys

CHANGELOG_PATH = pathlib.Path(__file__).resolve().parent.parent / "CHANGELOG.md"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: extract_release_notes.py <version-or-tag>", file=sys.stderr)
        return 2

    version = sys.argv[1].lstrip("v").strip()
    if not CHANGELOG_PATH.exists():
        print(f"error: {CHANGELOG_PATH} does not exist", file=sys.stderr)
        return 1

    text = CHANGELOG_PATH.read_text(encoding="utf-8")

    # Match: "## <version>" followed by end-of-line or a date/title suffix.
    pattern = re.compile(
        rf"^## {re.escape(version)}(?:\s+[\u2014-].*)?\s*$", re.MULTILINE
    )
    m = pattern.search(text)
    if not m:
        print(
            f"error: no section for version '{version}' in {CHANGELOG_PATH.name}",
            file=sys.stderr,
        )
        return 1

    start = m.end()
    next_section = re.compile(r"^## ", re.MULTILINE).search(text, pos=start)
    end = next_section.start() if next_section else len(text)
    body = text[start:end].strip("\n")
    print(body)
    return 0


if __name__ == "__main__":
    sys.exit(main())

