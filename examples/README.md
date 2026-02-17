# Example Policies

Starter `file-policy.json` configurations for common project types. Copy one into your `.github/` directory and adjust the patterns and check names to match your project.

## TypeScript

**File:** [`typescript/file-policy.json`](typescript/file-policy.json)

| Tier | Patterns | Required Checks |
|------|----------|-----------------|
| HIGH | `.github/**`, `tsconfig.json`, `package.json`, `package-lock.json`, `Dockerfile`, `docker-compose*.yml` | `build`, `test`, `lint`, `type-check` |
| LOW | `src/**/*.ts`, `src/**/*.tsx`, `tests/**/*.ts` | `build`, `test` |

**Rationale:** Config and infrastructure files affect the entire build pipeline — a bad `tsconfig.json` or `package.json` change can break everything. Source and test files are lower risk since they're caught by the standard build/test cycle.

## Python

**File:** [`python/file-policy.json`](python/file-policy.json)

| Tier | Patterns | Required Checks |
|------|----------|-----------------|
| HIGH | `.github/**`, `pyproject.toml`, `setup.py`, `requirements*.txt`, `Dockerfile`, `docker-compose*.yml`, `Makefile`, `tox.ini` | `pytest`, `mypy`, `ruff`, `build` |
| LOW | `src/**/*.py`, `tests/**/*.py`, `docs/**` | `pytest`, `ruff` |

**Rationale:** Dependency and packaging files (`pyproject.toml`, `requirements.txt`) can introduce breaking changes or security issues across the entire project. Python source files are lower risk and only need linting and tests.

## Customizing

To adapt an example for your project:

1. **Adjust glob patterns** to match your directory structure (e.g., `app/**/*.py` instead of `src/**/*.py`)
2. **Update check names** to match the actual job names in your GitHub Actions workflows
3. **Move files between tiers** based on your team's risk tolerance
