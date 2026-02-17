#!/usr/bin/env python3
"""Evaluate file-policy.json against a list of changed files.

Reads the policy contract, matches changed files against glob patterns,
determines the highest applicable tier, and outputs structured JSON.

Usage:
    echo "src/app.ts" | python3 evaluate-policy.py
    python3 evaluate-policy.py --files "src/app.ts,Dockerfile"
    python3 evaluate-policy.py --policy path/to/policy.json --files "src/app.ts"
"""

import argparse
import fnmatch
import json
import os
import sys


def load_policy(policy_path: str) -> dict:
    with open(policy_path) as f:
        return json.load(f)


def match_file(file_path: str, patterns: list[str]) -> str | None:
    """Match a file path against a list of glob patterns. Returns the first matching pattern or None."""
    for pattern in patterns:
        # fnmatch doesn't handle ** natively for directory traversal,
        # so we handle it: ** matches any number of path segments
        if "**" in pattern:
            # Convert ** glob to work with fnmatch
            # e.g., ".github/**" should match ".github/workflows/ci.yml"
            prefix = pattern.split("**")[0]
            if file_path.startswith(prefix):
                suffix = pattern.split("**")[-1]
                if not suffix or suffix == "/":
                    return pattern
                remaining = file_path[len(prefix):]
                if fnmatch.fnmatch(remaining, "*" + suffix):
                    return pattern
        elif fnmatch.fnmatch(file_path, pattern):
            return pattern
    return None


def evaluate(policy: dict, changed_files: list[str]) -> dict:
    """Evaluate changed files against the policy and return results."""
    tiers = policy.get("tiers", {})
    matches = []
    matched_tiers = set()

    for file_path in changed_files:
        file_path = file_path.strip()
        if not file_path:
            continue

        file_match = {"file": file_path, "tier": "none", "matched_pattern": None}

        # Check high tier first (takes priority)
        high_patterns = tiers.get("high", {}).get("patterns", [])
        pattern = match_file(file_path, high_patterns)
        if pattern:
            file_match["tier"] = "high"
            file_match["matched_pattern"] = pattern
            matched_tiers.add("high")
            matches.append(file_match)
            continue

        # Check low tier
        low_patterns = tiers.get("low", {}).get("patterns", [])
        pattern = match_file(file_path, low_patterns)
        if pattern:
            file_match["tier"] = "low"
            file_match["matched_pattern"] = pattern
            matched_tiers.add("low")

        matches.append(file_match)

    # Determine the highest tier
    if "high" in matched_tiers:
        resolved_tier = "high"
    elif "low" in matched_tiers:
        resolved_tier = "low"
    else:
        resolved_tier = "none"

    # Get required checks for the resolved tier
    if resolved_tier != "none":
        required_checks = tiers.get(resolved_tier, {}).get("checks", [])
    else:
        required_checks = []

    return {
        "tier": resolved_tier,
        "required_checks": required_checks,
        "matches": matches,
    }


def main():
    parser = argparse.ArgumentParser(description="Evaluate file policy against changed files")
    parser.add_argument("--policy", default=None, help="Path to file-policy.json")
    parser.add_argument("--files", default=None, help="Comma-separated list of changed files")
    args = parser.parse_args()

    # Resolve policy path
    if args.policy:
        policy_path = args.policy
    else:
        # Default: look for .github/file-policy.json relative to repo root
        script_dir = os.path.dirname(os.path.abspath(__file__))
        policy_path = os.path.join(script_dir, "..", "file-policy.json")

    if not os.path.exists(policy_path):
        print(f"Error: Policy file not found: {policy_path}", file=sys.stderr)
        sys.exit(1)

    policy = load_policy(policy_path)

    # Get changed files
    if args.files:
        changed_files = [f.strip() for f in args.files.split(",") if f.strip()]
    else:
        changed_files = [line.strip() for line in sys.stdin if line.strip()]

    result = evaluate(policy, changed_files)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
