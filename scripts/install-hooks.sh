#!/usr/bin/env bash
#===============================================================================
# install-hooks.sh — Install enhanced pre-commit hook wrappers
#===============================================================================
# Replaces default pre-commit hooks with visual wrappers that provide
# structured, color-coded output with grouped sections and summary footer.
#
# USAGE:
#   ./scripts/install-hooks.sh
#
# PREREQUISITES:
#   pip install pre-commit
#   brew install swiftformat swiftlint   (for Swift hooks)
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
    printf 'Not a git repository.\n' >&2
    exit 1
fi

pre-commit install --install-hooks 2>/dev/null || true
pre-commit install --hook-type commit-msg 2>/dev/null || true

cp "${SCRIPT_DIR}/pre-commit-hook.sh" "${HOOKS_DIR}/pre-commit"
cp "${SCRIPT_DIR}/commit-msg-hook.sh" "${HOOKS_DIR}/commit-msg"
chmod 755 "${HOOKS_DIR}/pre-commit" "${HOOKS_DIR}/commit-msg"

printf 'Enhanced hooks installed at .git/hooks/{pre-commit,commit-msg}\n'
