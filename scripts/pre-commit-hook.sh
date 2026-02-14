#!/usr/bin/env bash
#===============================================================================
# pre-commit-hook.sh — Visual pre-commit wrapper
#===============================================================================
# Wraps pre-commit framework execution with structured, color-coded output
# inspired by cargo, biome, and pytest terminal UX patterns.
#
# Installed to .git/hooks/pre-commit by scripts/install-hooks.sh.
#===============================================================================

set -uo pipefail
trap 'exit 130' INT TERM

#===============================================================================
# Color configuration (NO_COLOR compliant — https://no-color.org/)
#===============================================================================

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    CYAN=$'\033[36m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    NC=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' NC=''
fi

RULE="${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

#===============================================================================
# Pre-flight
#===============================================================================

if ! command -v pre-commit &>/dev/null; then
    printf '\n  %s✖%s  pre-commit not installed\n' "$RED" "$NC" >&2
    printf '    %sRun: pip install pre-commit%s\n\n' "$DIM" "$NC" >&2
    exit 1
fi

#===============================================================================
# Execute pre-commit and capture output
#===============================================================================

exit_code=0
output=$(pre-commit run --hook-stage pre-commit "$@" 2>&1) || exit_code=$?

# Strip ANSI escape codes for reliable parsing
output=$(printf '%s' "$output" | sed $'s/\033\\[[0-9;]*m//g')

#===============================================================================
# Parse results
#===============================================================================

hook_count=0
declare -a h_names h_statuses h_outputs h_modified

current_idx=-1
capturing=0
current_output=""
current_modified=0

while IFS= read -r line; do
    [[ "$line" == "[INFO]"* ]] && continue

    if [[ "$line" == *"..."*"Passed"* ]] || [[ "$line" == *"..."*"Failed"* ]] || [[ "$line" == *"..."*"Skipped"* ]]; then
        raw_name="${line%%...*}"
        raw_tail="${line##*...}"
        status=""

        [[ "$raw_tail" == *"Passed"* ]] && status="passed"
        [[ "$raw_tail" == *"Failed"* ]] && status="failed"
        [[ "$raw_tail" == *"Skipped"* ]] && status="skipped"

        if [[ -n "$status" ]]; then
            if [[ $capturing -eq 1 ]] && [[ $current_idx -ge 0 ]]; then
                h_outputs[$current_idx]="$current_output"
                h_modified[$current_idx]=$current_modified
            fi

            raw_name="${raw_name%"${raw_name##*[![:space:]]}"}"

            h_names[$hook_count]="$raw_name"
            h_statuses[$hook_count]="$status"
            h_outputs[$hook_count]=""
            h_modified[$hook_count]=0
            current_idx=$hook_count
            hook_count=$((hook_count + 1))
            current_output=""
            current_modified=0

            if [[ "$status" == "failed" ]]; then
                capturing=1
            else
                capturing=0
            fi
            continue
        fi
    fi

    if [[ $capturing -eq 1 ]]; then
        [[ "$line" == "- hook id:"* ]] && continue
        [[ "$line" == "- exit code:"* ]] && continue
        [[ "$line" == "- duration:"* ]] && continue
        if [[ "$line" == *"files were modified"* ]]; then
            current_modified=1
            continue
        fi
        current_output="${current_output}${line}"$'\n'
    fi
done <<< "$output"

if [[ $capturing -eq 1 ]] && [[ $current_idx -ge 0 ]]; then
    h_outputs[$current_idx]="$current_output"
    h_modified[$current_idx]=$current_modified
fi

#===============================================================================
# Fallback: if no hooks parsed, show raw output
#===============================================================================

if [[ $hook_count -eq 0 ]]; then
    printf '%s\n' "$output"
    exit "$exit_code"
fi

#===============================================================================
# Lookup functions
#===============================================================================

get_group() {
    case "$1" in
        "PZ-001 Protocol Zero"|"Governance Audit"*)
            echo "governance" ;;
        "trim trailing"*|"fix end of"*|"check for merge"*|"check yaml"*|"check json"*|"check for added"*)
            echo "hygiene" ;;
        "ruff format"*|"ruff-format"*|"SwiftFormat"*)
            echo "format" ;;
        "shellcheck"*|"ruff"*|"markdownlint"*|"SwiftLint"*)
            echo "lint" ;;
        *)
            echo "other" ;;
    esac
}

get_display() {
    case "$1" in
        "PZ-001 Protocol Zero")                echo "Protocol Zero" ;;
        "Governance Audit"*)                   echo "Governance Audit" ;;
        "trim trailing whitespace")            echo "Trailing whitespace" ;;
        "fix end of files")                    echo "End-of-file fixer" ;;
        "check for merge conflicts")           echo "Merge conflict markers" ;;
        "check yaml")                          echo "YAML syntax" ;;
        "check json")                          echo "JSON syntax" ;;
        "check for added large files")         echo "Large file check" ;;
        "shellcheck")                          echo "ShellCheck" ;;
        "ruff (legacy alias)"|"ruff-check")    echo "Ruff" ;;
        "ruff format"|"ruff-format")           echo "Ruff Format" ;;
        "markdownlint")                        echo "markdownlint" ;;
        "SwiftFormat")                         echo "SwiftFormat" ;;
        "SwiftLint")                           echo "SwiftLint" ;;
        *)                                     echo "$1" ;;
    esac
}

get_hint() {
    case "$1" in
        "PZ-001 Protocol Zero")
            echo "Remove attribution markers from flagged files" ;;
        "Governance Audit"*)
            echo "Run: python3 .claude/skills/pre-commit-auditor/scripts/audit.py --all" ;;
        "trim trailing"*|"fix end of"*|"SwiftFormat"*)
            echo "Files auto-fixed. Stage changes and commit again" ;;
        "shellcheck"*)
            echo "Review shell script warnings above" ;;
        "ruff (legacy"*|"ruff-check"*)
            echo "Run: ruff check --fix" ;;
        "ruff format"*|"ruff-format"*)
            echo "Run: ruff format ." ;;
        "markdownlint"*)
            echo "Review markdown formatting above" ;;
        "SwiftLint"*)
            echo "Review SwiftLint violations above" ;;
        "check yaml"*)
            echo "Fix YAML syntax errors in flagged files" ;;
        "check json"*)
            echo "Fix JSON syntax errors in flagged files" ;;
        "check for merge"*)
            echo "Resolve merge conflict markers in flagged files" ;;
        "check for added large"*)
            echo "Remove or .gitignore files exceeding 5 MB" ;;
        *)
            echo "Resolve issues above" ;;
    esac
}

#===============================================================================
# Rendering
#===============================================================================

# Reclassify: ruff lint vs ruff format
# "ruff" hooks that are NOT "ruff format" belong in lint, not format
get_group_fixed() {
    local name="$1"
    if [[ "$name" == "ruff format"* || "$name" == "ruff-format"* ]]; then
        echo "format"
    elif [[ "$name" == "ruff"* ]]; then
        echo "lint"
    else
        get_group "$name"
    fi
}

render_hook() {
    local idx=$1
    local name="${h_names[$idx]}"
    local status="${h_statuses[$idx]}"
    local hook_output="${h_outputs[$idx]}"
    local modified="${h_modified[$idx]}"
    local display
    display=$(get_display "$name")

    case "$status" in
        passed)
            printf '    %s✔%s  %s\n' "$GREEN" "$NC" "$display"
            ;;
        skipped)
            printf '    %s○  %-44s%sskip%s\n' "$DIM" "$display" "" "$NC"
            ;;
        failed)
            printf '    %s✖%s  %s%s%s\n' "$RED" "$NC" "$BOLD" "$display" "$NC"

            if [[ -n "$hook_output" ]]; then
                local line_count=0
                local stripped
                stripped=$(printf '%s' "$hook_output" | sed $'s/\033\\[[0-9;]*m//g')

                while IFS= read -r oline; do
                    [[ -z "$oline" ]] && continue
                    line_count=$((line_count + 1))
                    if [[ $line_count -le 10 ]]; then
                        printf '    %s│%s  %s%s%s\n' "$DIM" "$NC" "$DIM" "$oline" "$NC"
                    fi
                done <<< "$stripped"

                if [[ $line_count -gt 10 ]]; then
                    printf '    %s│  … and %d more lines%s\n' "$DIM" $((line_count - 10)) "$NC"
                fi
            fi

            local hint
            if [[ $modified -eq 1 ]]; then
                hint="Files auto-fixed. Stage changes and commit again"
            else
                hint=$(get_hint "$name")
            fi
            printf '    %s│%s\n' "$DIM" "$NC"
            printf '    %s│%s  %s%s%s\n' "$DIM" "$NC" "$YELLOW" "$hint" "$NC"
            printf '\n'
            ;;
    esac
}

render_group() {
    local group_id="$1"
    local group_label="$2"
    local found=0

    for (( i=0; i<hook_count; i++ )); do
        local g
        g=$(get_group_fixed "${h_names[$i]}")
        if [[ "$g" == "$group_id" ]]; then
            if [[ $found -eq 0 ]]; then
                printf '  %s%s%s%s\n' "$CYAN" "$BOLD" "$group_label" "$NC"
                found=1
            fi
            render_hook "$i"
        fi
    done

    [[ $found -eq 1 ]] && printf '\n'
}

#===============================================================================
# Count results
#===============================================================================

pass_count=0; fail_count=0; skip_count=0
for (( i=0; i<hook_count; i++ )); do
    case "${h_statuses[$i]}" in
        passed)  pass_count=$((pass_count + 1)) ;;
        failed)  fail_count=$((fail_count + 1)) ;;
        skipped) skip_count=$((skip_count + 1)) ;;
    esac
done

#===============================================================================
# Render
#===============================================================================

printf '\n'
printf '  %s\n' "$RULE"
printf '  %s%s STARLIGHT SYNC%s%s                            pre-commit%s\n' \
    "$CYAN" "$BOLD" "$NC" "$DIM" "$NC"
printf '  %s\n' "$RULE"
printf '\n'

render_group "governance" "GOVERNANCE"
render_group "hygiene"    "HYGIENE"
render_group "lint"       "LINT"
render_group "format"     "FORMAT"
render_group "other"      "OTHER"

printf '  %s\n' "$RULE"
if [[ $exit_code -eq 0 ]]; then
    printf '  %s%s ✔ ALL CLEAR%s' "$GREEN" "$BOLD" "$NC"
else
    printf '  %s%s ✖ BLOCKED%s' "$RED" "$BOLD" "$NC"
fi
printf '%s%*s%d passed · %d skipped · %d failed%s\n' \
    "$DIM" 10 "" "$pass_count" "$skip_count" "$fail_count" "$NC"
printf '  %s\n' "$RULE"

if [[ $exit_code -ne 0 ]]; then
    printf '\n  %sFix violations above, then commit again.%s\n' "$DIM" "$NC"
fi

printf '\n'
exit "$exit_code"
