# Interview Answers

## Project Overview

**Project Name:** codefactory

**Concept:** A language-agnostic template that provides automated CI/CD policy enforcement via a JSON contract. Teams define file-path-to-risk-tier mappings using glob patterns, and a GitHub Actions workflow enforces the required CI checks per tier on every PR.

## Key Decisions

### Policy Contract Schema

- **Tiers:** Two tiers only — `high` and `low`.
- **Format:** JSON file at `.github/file-policy.json`.
- **Glob patterns** map file paths to tiers.
- **Required checks** per tier reference GitHub Actions check run **names** (e.g., `"checks": ["tests", "lint"]`).
- **No authorized reviewer management** — that's handled natively by GitHub CODEOWNERS and branch protection rules. Keep it out of the policy contract to avoid sync problems.

### Enforcement Mechanism

- **GitHub Actions workflow** reads the policy JSON, determines which files changed in the PR, resolves the highest applicable tier, and enforces the required checks.
- **No human approval gate** — enforcement is purely automated. High-risk file changes require extra CI checks to pass, but no human sign-off.

### Dry-Run Mode

- Implemented as a **flag/input on the main workflow** (e.g., `dry_run: true`), not a separate workflow.
- In dry-run mode, the workflow **posts a PR comment** summarizing:
  - Files changed
  - Tiers matched
  - Checks that *would* be required
- Does **not** block or fail the PR in dry-run mode.

### Template Deliverables

1. **`.github/file-policy.json`** — The policy contract with example configuration.
2. **`.github/workflows/file-policy-guard.yml`** — The enforcement GitHub Actions workflow.
3. **Example policies** for **TypeScript** and **Python** as starter configs.
4. **README** explaining how to configure and use the template.

### Technical Constraints

- **Language-agnostic** — the template itself makes no assumptions about the consuming project's language or framework.
- **Two tiers only** (`high` / `low`) — no need for arbitrary tier support at MVP.
- **CI checks are GitHub Actions check run names** — the policy references them by string name.

## Out of Scope (MVP)

- Authorized reviewer management (use CODEOWNERS)
- More than two risk tiers
- Human-in-the-loop approval gates
- CLI/script for policy JSON schema validation
