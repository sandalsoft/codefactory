#!/usr/bin/env python3
"""Format policy evaluation results as a Markdown PR comment.

Reads evaluation JSON (from evaluate-policy.py) and outputs a Markdown
comment suitable for posting on a GitHub pull request.

Usage:
    python3 evaluate-policy.py --files "src/app.ts,Dockerfile" | python3 format-comment.py
    python3 format-comment.py --input results.json --dry-run
"""

import argparse
import json
import sys

# Marker used to identify and update existing comments (avoids spam)
COMMENT_MARKER = "<!-- file-policy-guard -->"

TIER_LABELS = {
    "high": "HIGH",
    "low": "LOW",
    "none": "—",
}


def format_comment(evaluation: dict, dry_run: bool = False) -> str:
    tier = evaluation.get("tier", "none")
    required_checks = evaluation.get("required_checks", [])
    matches = evaluation.get("matches", [])

    lines = [COMMENT_MARKER, ""]

    # Header
    if dry_run:
        lines.append("## File Policy Guard (Dry Run)")
        lines.append("")
        lines.append("> This is a **dry-run** report. No checks are enforced.")
    else:
        if tier == "none":
            lines.append("## File Policy Guard — No Policy Match")
        elif tier == "high":
            lines.append("## File Policy Guard — HIGH Risk Tier")
        else:
            lines.append("## File Policy Guard — LOW Risk Tier")

    lines.append("")

    # Summary
    if tier == "none":
        lines.append("No changed files matched any policy patterns. No additional checks required.")
        return "\n".join(lines)

    lines.append(f"**Resolved tier:** `{tier.upper()}`")
    lines.append("")

    # Required checks
    if required_checks:
        lines.append("**Required checks:**")
        for check in required_checks:
            lines.append(f"- `{check}`")
        lines.append("")

    # File matches table
    if matches:
        lines.append("### Changed Files")
        lines.append("")
        lines.append("| File | Tier | Matched Pattern |")
        lines.append("|------|------|-----------------|")
        for match in matches:
            file_path = match.get("file", "")
            file_tier = TIER_LABELS.get(match.get("tier", "none"), "—")
            pattern = match.get("matched_pattern") or "—"
            lines.append(f"| `{file_path}` | {file_tier} | `{pattern}` |")
        lines.append("")

    if not dry_run and tier != "none":
        lines.append("---")
        lines.append(f"All required checks must pass before this PR can be merged.")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Format policy evaluation as PR comment")
    parser.add_argument("--input", default=None, help="Path to evaluation JSON file")
    parser.add_argument("--dry-run", action="store_true", help="Format as dry-run report")
    args = parser.parse_args()

    if args.input:
        with open(args.input) as f:
            evaluation = json.load(f)
    else:
        evaluation = json.load(sys.stdin)

    comment = format_comment(evaluation, dry_run=args.dry_run)
    print(comment)


if __name__ == "__main__":
    main()
