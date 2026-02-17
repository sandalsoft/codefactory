# codefactory

A language-agnostic GitHub template that enforces CI/CD policies based on which files change in a pull request.

Define file-path-to-risk-tier mappings in a JSON contract. A GitHub Actions workflow automatically evaluates changed files, resolves the applicable tier, and enforces the required CI checks — no human approval gate needed.

## Quick Start

**1. Copy the files into your repo:**

```
.github/
  file-policy.json          # Your policy contract
  file-policy.schema.json   # JSON Schema (editor support)
  scripts/
    evaluate-policy.py      # Policy evaluation engine
    format-comment.py       # PR comment formatter
  workflows/
    file-policy-guard.yml   # Enforcement workflow
```

**2. Edit `.github/file-policy.json`** to match your project:

```json
{
  "tiers": {
    "high": {
      "patterns": [".github/**", "Dockerfile", "package.json"],
      "checks": ["build", "test", "lint"]
    },
    "low": {
      "patterns": ["src/**"],
      "checks": ["build", "test"]
    }
  }
}
```

**3. Ensure your check names match** your existing GitHub Actions job names. The `checks` arrays reference the `name` field of jobs in your CI workflows.

That's it. The workflow runs automatically on every pull request.

## Policy JSON Format

The policy file (`.github/file-policy.json`) defines two risk tiers:

| Field | Type | Description |
|-------|------|-------------|
| `tiers.high.patterns` | `string[]` | Glob patterns for high-risk files |
| `tiers.high.checks` | `string[]` | Check run names required when high-risk files change |
| `tiers.low.patterns` | `string[]` | Glob patterns for low-risk files |
| `tiers.low.checks` | `string[]` | Check run names required when low-risk files change |

### Glob Matching

Patterns use fnmatch-style matching:

| Pattern | Matches |
|---------|---------|
| `src/**/*.ts` | Any `.ts` file under `src/` at any depth |
| `Dockerfile` | Exactly `Dockerfile` in the repo root |
| `docker-compose*.yml` | `docker-compose.yml`, `docker-compose.prod.yml`, etc. |
| `.github/**` | Anything under `.github/` |
| `*.lock` | Any lock file in the repo root |

### Tier Resolution

When a PR changes files matching **both** tiers, the **highest tier wins**. The required checks for the resolved tier are enforced.

- Files matching `high` patterns → HIGH tier checks required
- Files matching only `low` patterns → LOW tier checks required
- Files matching no patterns → no additional checks required

## Dry-Run Mode

Enable dry-run mode to see what the policy *would* enforce without blocking any PRs.

### Via environment variable

In `.github/workflows/file-policy-guard.yml`, set:

```yaml
env:
  FILE_POLICY_DRY_RUN: "true"
```

### Via manual trigger

Run the workflow manually from the Actions tab and select `dry_run: true`.

### What dry-run does

- Posts a PR comment showing matched files, tiers, and required checks
- Does **not** fail the workflow or block the PR
- Useful for onboarding teams or testing policy changes

## How Enforcement Works

```
PR opened/updated
       │
       ▼
  Get changed files (git diff)
       │
       ▼
  Match files against policy patterns
       │
       ▼
  Resolve highest tier (high > low > none)
       │
       ├── tier = none → pass (no comment)
       │
       ├── dry_run = true → post informational PR comment → pass
       │
       └── dry_run = false
              │
              ▼
        Query GitHub Checks API
              │
              ├── All required checks passed → pass
              │
              └── Missing checks → fail with error details
```

The workflow posts (or updates) a single PR comment with the evaluation results. It uses a hidden marker to find and update its own comment on subsequent runs, avoiding comment spam.

## Example Policies

Starter configurations for common project types:

- **[TypeScript](examples/typescript/file-policy.json)** — infra files as high tier, source/test files as low
- **[Python](examples/python/file-policy.json)** — packaging/config as high tier, source/docs as low

See [`examples/README.md`](examples/README.md) for details and customization guidance.

## Limitations

- **Two tiers only** (high and low). If a file matches both, high wins.
- **Check names must match exactly.** The `checks` values must match the `name` field of your GitHub Actions jobs.
- **No authorized reviewer management.** Use GitHub's native CODEOWNERS and branch protection rules for reviewer requirements.
- **Glob matching uses Python's `fnmatch`.** The `**` pattern matches any depth of subdirectories, but edge cases may differ from gitignore-style matching.

## License

MIT
