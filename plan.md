# Implementation Plan: codefactory

## Summary

Codefactory is a language-agnostic GitHub template that enforces CI/CD policies through a JSON contract. Teams define file-path-to-risk-tier mappings (high/low) using glob patterns in `.github/file-policy.json`, and a GitHub Actions workflow automatically checks which files changed in a PR, resolves the applicable tier, and enforces the required CI checks. It includes a dry-run mode that posts an informational PR comment without blocking, and ships with example policies for TypeScript and Python projects.

## Technical Stack

- **Runtime:** Bash + GitHub Actions composite/workflow YAML
- **Policy evaluation:** Bash with `jq`-free approach (pure bash glob matching), or a small inline Python script for JSON parsing and glob matching (since the template targets GitHub Actions runners which have Python pre-installed)
- **No external dependencies** — everything runs with tools available on `ubuntu-latest` GitHub Actions runners
- **Template files:** JSON, YAML, Markdown

## Phases

### Phase 1: Project Structure & Policy Schema

- [x] Step 1.1: Create the directory structure for the template (`examples/`, `.github/`)
- [x] Step 1.2: Create `.github/file-policy.json` with the default example policy demonstrating both high and low tiers with glob patterns and required check names
- [x] Step 1.3: Create a JSON schema file `.github/file-policy.schema.json` that documents the expected structure of the policy contract (for editor autocompletion, not runtime validation)

### Phase 2: Policy Evaluation Script

- [x] Step 2.1: Create `.github/scripts/evaluate-policy.py` — a self-contained Python script that reads the policy JSON, accepts a list of changed files, matches them against glob patterns, determines the highest tier, and outputs the required checks. Must handle: no matches (pass), low-tier matches, high-tier matches, mixed matches (highest tier wins)
- [x] Step 2.2: Create `.github/scripts/format-comment.py` — a script that takes the evaluation output and formats a Markdown PR comment summarizing: files changed, tiers matched per file, and checks required. Used for both dry-run comments and enforcement failure comments

### Phase 3: GitHub Actions Workflow

- [x] Step 3.1: Create `.github/workflows/file-policy-guard.yml` — the main enforcement workflow. Triggers on `pull_request` events. Accepts a `dry_run` input (boolean, default `false`). Jobs: checkout, get changed files, run evaluation script, post PR comment (dry-run or failure), set status check pass/fail
- [x] Step 3.2: Add the changed-files detection step using `git diff` against the PR base branch (no external actions dependency to keep the template self-contained)
- [x] Step 3.3: Add the enforcement logic — compare required checks from policy evaluation against actual check run statuses using the GitHub API (`$GITHUB_TOKEN`). If required checks haven't passed, fail the workflow. In dry-run mode, post the comment and exit successfully
- [x] Step 3.4: Add the PR comment posting step using the GitHub API to create or update a comment (update existing to avoid comment spam on re-runs)

### Phase 4: Example Policies

- [x] Step 4.1: Create `examples/typescript/file-policy.json` — example policy for a TypeScript project mapping `src/**/*.ts` to appropriate tiers, with infrastructure files (`tsconfig.json`, `package.json`, `.github/**`) as high tier and source files as low tier, with realistic check names like `build`, `test`, `lint`, `type-check`
- [x] Step 4.2: Create `examples/python/file-policy.json` — example policy for a Python project mapping `src/**/*.py`, `tests/**/*.py` with infrastructure files (`pyproject.toml`, `requirements*.txt`, `.github/**`, `Dockerfile`) as high tier and source/test files as low tier, with realistic check names like `pytest`, `mypy`, `ruff`, `build`
- [x] Step 4.3: Create `examples/README.md` explaining each example policy with a brief description of the tier rationale

### Phase 5: Documentation

- [x] Step 5.1: Create the project `README.md` covering: what codefactory does, quick start (copy the files, edit the policy JSON, enable the workflow), policy JSON format reference, dry-run mode usage, how enforcement works, example policies, and limitations/FAQ

### Phase 6: Validation & Cleanup

- [x] Step 6.1: Create a local test script `scripts/test-evaluate.sh` that runs `evaluate-policy.py` against the example policies with sample changed-file lists to verify correct tier resolution and output format
- [x] Step 6.2: Run the test script and fix any issues
- [x] Step 6.3: Final review — verify all files are in place, no placeholders remain, policy JSON is valid, workflow YAML is valid, and README is complete
