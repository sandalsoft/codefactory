#!/usr/bin/env bash
# Test suite for evaluate-policy.py and format-comment.py
# Runs against the default policy and both example policies.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EVALUATE="${REPO_ROOT}/.github/scripts/evaluate-policy.py"
FORMAT="${REPO_ROOT}/.github/scripts/format-comment.py"

PASS=0
FAIL=0

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    if [[ "${actual}" == "${expected}" ]]; then
        echo "  PASS: ${test_name}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: ${test_name}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    if echo "${haystack}" | grep -q "${needle}"; then
        echo "  PASS: ${test_name}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: ${test_name}"
        echo "    expected to contain: ${needle}"
        echo "    actual: ${haystack}"
        FAIL=$((FAIL + 1))
    fi
}

# Helper: run evaluate-policy.py with given policy and files
run_eval() {
    local policy="$1"
    local files="$2"
    echo "${files}" | python3 "${EVALUATE}" --policy "${policy}"
}

# Extract tier from evaluation JSON
get_tier() {
    echo "$1" | python3 -c "import sys,json; print(json.load(sys.stdin)['tier'])"
}

# Extract required_checks as comma-separated
get_checks() {
    echo "$1" | python3 -c "import sys,json; print(','.join(json.load(sys.stdin)['required_checks']))"
}

# Count matches
count_matches() {
    echo "$1" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['matches']))"
}

# ============================================================
echo "=== Default Policy (.github/file-policy.json) ==="
POLICY="${REPO_ROOT}/.github/file-policy.json"

echo ""
echo "Test 1: No matching files"
RESULT=$(run_eval "${POLICY}" "README.md
LICENSE")
assert_eq "tier is none" "none" "$(get_tier "${RESULT}")"
assert_eq "no required checks" "" "$(get_checks "${RESULT}")"

echo ""
echo "Test 2: Only low-tier files"
RESULT=$(run_eval "${POLICY}" "src/app.ts
src/utils/helper.py")
assert_eq "tier is low" "low" "$(get_tier "${RESULT}")"
assert_eq "low checks" "build,test" "$(get_checks "${RESULT}")"

echo ""
echo "Test 3: Only high-tier files"
RESULT=$(run_eval "${POLICY}" "Dockerfile
package-lock.json")
assert_eq "tier is high" "high" "$(get_tier "${RESULT}")"
assert_eq "high checks" "build,test,lint" "$(get_checks "${RESULT}")"

echo ""
echo "Test 4: Mixed high + low files"
RESULT=$(run_eval "${POLICY}" "src/index.ts
Dockerfile
README.md")
assert_eq "tier is high (highest wins)" "high" "$(get_tier "${RESULT}")"
assert_eq "high checks apply" "build,test,lint" "$(get_checks "${RESULT}")"
assert_eq "3 matches" "3" "$(count_matches "${RESULT}")"

echo ""
echo "Test 5: .github/** glob matches nested files"
RESULT=$(run_eval "${POLICY}" ".github/workflows/ci.yml")
assert_eq "tier is high" "high" "$(get_tier "${RESULT}")"

echo ""
echo "Test 6: *.lock glob matches lock files"
RESULT=$(run_eval "${POLICY}" "yarn.lock")
assert_eq "tier is high" "high" "$(get_tier "${RESULT}")"

# ============================================================
echo ""
echo "=== TypeScript Example Policy ==="
POLICY="${REPO_ROOT}/examples/typescript/file-policy.json"

echo ""
echo "Test 7: TypeScript source files (low tier)"
RESULT=$(run_eval "${POLICY}" "src/components/Button.tsx
tests/Button.test.ts")
assert_eq "tier is low" "low" "$(get_tier "${RESULT}")"
assert_eq "low checks" "build,test" "$(get_checks "${RESULT}")"

echo ""
echo "Test 8: TypeScript config files (high tier)"
RESULT=$(run_eval "${POLICY}" "tsconfig.json
package.json")
assert_eq "tier is high" "high" "$(get_tier "${RESULT}")"
assert_eq "high checks" "build,test,lint,type-check" "$(get_checks "${RESULT}")"

# ============================================================
echo ""
echo "=== Python Example Policy ==="
POLICY="${REPO_ROOT}/examples/python/file-policy.json"

echo ""
echo "Test 9: Python source files (low tier)"
RESULT=$(run_eval "${POLICY}" "src/models/user.py
tests/test_user.py")
assert_eq "tier is low" "low" "$(get_tier "${RESULT}")"
assert_eq "low checks" "pytest,ruff" "$(get_checks "${RESULT}")"

echo ""
echo "Test 10: Python config files (high tier)"
RESULT=$(run_eval "${POLICY}" "pyproject.toml
requirements.txt")
assert_eq "tier is high" "high" "$(get_tier "${RESULT}")"
assert_eq "high checks" "pytest,mypy,ruff,build" "$(get_checks "${RESULT}")"

# ============================================================
echo ""
echo "=== format-comment.py ==="

echo ""
echo "Test 11: Normal mode comment contains tier"
EVAL_JSON=$(run_eval "${REPO_ROOT}/.github/file-policy.json" "Dockerfile")
COMMENT=$(echo "${EVAL_JSON}" | python3 "${FORMAT}")
assert_contains "comment has HIGH tier header" "HIGH Risk Tier" "${COMMENT}"
assert_contains "comment has marker" "file-policy-guard" "${COMMENT}"

echo ""
echo "Test 12: Dry-run mode comment"
COMMENT=$(echo "${EVAL_JSON}" | python3 "${FORMAT}" --dry-run)
assert_contains "dry-run header" "Dry Run" "${COMMENT}"
assert_contains "dry-run note" "dry-run" "${COMMENT}"

echo ""
echo "Test 13: No-match comment"
EVAL_JSON=$(run_eval "${REPO_ROOT}/.github/file-policy.json" "README.md")
COMMENT=$(echo "${EVAL_JSON}" | python3 "${FORMAT}")
assert_contains "no-match message" "No changed files matched" "${COMMENT}"

echo ""
echo "Test 14: Empty input"
RESULT=$(echo "" | python3 "${EVALUATE}" --policy "${REPO_ROOT}/.github/file-policy.json")
assert_eq "empty input tier is none" "none" "$(get_tier "${RESULT}")"

# ============================================================
echo ""
echo "==============================="
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "==============================="

if [[ ${FAIL} -gt 0 ]]; then
    exit 1
fi
