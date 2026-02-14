#!/usr/bin/env bash
#===============================================================================
# validate-commit-msg.sh — Conventional Commits Enforcement
#===============================================================================
#
# Validates commit messages against the Conventional Commits format
# defined in CLAUDE.md §9.3.
#
# AUTHORITY: CLAUDE.md §9.3 — Commit Format
#
# FORMAT: type(scope): imperative description
#
# EXIT CODES:
#   0   Valid commit message
#   1   Invalid commit message
#
# USAGE:
#   ./scripts/validate-commit-msg.sh <commit-msg-file>
#
#===============================================================================

set -euo pipefail

#===============================================================================
# CONFIGURATION
#===============================================================================

readonly VALID_TYPES="feat|fix|refactor|test|chore|docs"
readonly VALID_SCOPES="coordinator|audio|haptics|webhook|ch[1-6]|assets|tests|ci|repo"
readonly MAX_LENGTH=72

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    readonly RED=$'\033[31m'
    readonly GREEN=$'\033[32m'
    readonly YELLOW=$'\033[33m'
    readonly BOLD=$'\033[1m'
    readonly DIM=$'\033[2m'
    readonly NC=$'\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BOLD=''
    readonly DIM=''
    readonly NC=''
fi

#===============================================================================
# VALIDATION
#===============================================================================

if [[ $# -lt 1 ]]; then
    printf '  %s✗%s  Missing commit message file argument\n' "${RED}" "${NC}" >&2
    exit 1
fi

commit_msg_file="$1"

if [[ ! -f "${commit_msg_file}" ]]; then
    printf '  %s✗%s  Commit message file not found: %s\n' "${RED}" "${NC}" "${commit_msg_file}" >&2
    exit 1
fi

first_line="$(head -1 "${commit_msg_file}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"

if [[ -z "${first_line}" ]]; then
    printf '  %s✗%s  Empty commit message\n' "${RED}" "${NC}" >&2
    exit 1
fi

# Skip merge commits
if [[ "${first_line}" == Merge* ]]; then
    exit 0
fi

errors=0

# Check max length
if [[ ${#first_line} -gt ${MAX_LENGTH} ]]; then
    printf '  %s✗%s  First line exceeds %d characters (%d chars)\n' \
        "${RED}" "${NC}" "${MAX_LENGTH}" "${#first_line}" >&2
    errors=$((errors + 1))
fi

# Check conventional commits format
if ! echo "${first_line}" | grep -qE "^(${VALID_TYPES})\((${VALID_SCOPES})\): [a-z]"; then
    printf '  %s✗%s  Does not match format: %stype(scope): description%s\n' \
        "${RED}" "${NC}" "${BOLD}" "${NC}" >&2
    printf '    %sGot:%s %s\n' "${DIM}" "${NC}" "${first_line}" >&2
    printf '    %sTypes:%s %s\n' "${DIM}" "${NC}" "${VALID_TYPES}" >&2
    printf '    %sScopes:%s %s\n' "${DIM}" "${NC}" "${VALID_SCOPES}" >&2
    errors=$((errors + 1))
fi

# Check trailing period
if [[ "${first_line}" == *. ]]; then
    printf '  %s✗%s  Description must not end with a period\n' "${RED}" "${NC}" >&2
    errors=$((errors + 1))
fi

if [[ ${errors} -gt 0 ]]; then
    printf '\n  %s⚠%s  %sCommit message rejected (CC-001)%s\n' \
        "${YELLOW}" "${NC}" "${BOLD}" "${NC}" >&2
    printf '    %sCLAUDE.md §9.3 — Commit Format%s\n\n' "${DIM}" "${NC}" >&2
    exit 1
fi

printf '  %s✓%s  Commit message compliant (CC-001)\n' "${GREEN}" "${NC}"
exit 0
