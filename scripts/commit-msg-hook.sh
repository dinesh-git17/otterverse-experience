#!/usr/bin/env bash
#===============================================================================
# commit-msg-hook.sh — Visual commit-msg wrapper
#===============================================================================
# Wraps pre-commit commit-msg hooks with structured, color-coded output.
# Installed to .git/hooks/commit-msg by scripts/install-hooks.sh.
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

if [[ $# -lt 1 ]]; then
    printf '  %s✖%s  No commit message file provided\n' "$RED" "$NC" >&2
    exit 1
fi

#===============================================================================
# Execute pre-commit commit-msg hooks
#===============================================================================

exit_code=0
output=$(pre-commit run --hook-stage commit-msg --commit-msg-filename "$1" 2>&1) || exit_code=$?

# Strip ANSI escape codes for reliable parsing
output=$(printf '%s' "$output" | sed $'s/\033\\[[0-9;]*m//g')

#===============================================================================
# Parse results
#===============================================================================

hook_count=0
declare -a h_names h_statuses h_outputs

current_idx=-1
capturing=0
current_output=""

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
            fi

            raw_name="${raw_name%"${raw_name##*[![:space:]]}"}"

            h_names[$hook_count]="$raw_name"
            h_statuses[$hook_count]="$status"
            h_outputs[$hook_count]=""
            current_idx=$hook_count
            hook_count=$((hook_count + 1))
            current_output=""

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
        current_output="${current_output}${line}"$'\n'
    fi
done <<< "$output"

if [[ $capturing -eq 1 ]] && [[ $current_idx -ge 0 ]]; then
    h_outputs[$current_idx]="$current_output"
fi

#===============================================================================
# Fallback
#===============================================================================

if [[ $hook_count -eq 0 ]]; then
    printf '%s\n' "$output"
    exit "$exit_code"
fi

#===============================================================================
# Lookup
#===============================================================================

get_display() {
    case "$1" in
        "PZ-001 Commit Message"|"PZ-001 Protocol Zero") echo "Protocol Zero" ;;
        "CC-001 Conventional Commits")                   echo "Conventional Commits" ;;
        *)                                               echo "$1" ;;
    esac
}

get_hint() {
    case "$1" in
        "PZ-001"*)
            echo "Remove attribution markers from commit message" ;;
        "CC-001"*)
            echo "Format: type(scope): description  (CLAUDE.md §9.3)" ;;
        *)
            echo "Fix commit message" ;;
    esac
}

#===============================================================================
# Render
#===============================================================================

pass_count=0; fail_count=0; skip_count=0
for (( i=0; i<hook_count; i++ )); do
    case "${h_statuses[$i]}" in
        passed)  pass_count=$((pass_count + 1)) ;;
        failed)  fail_count=$((fail_count + 1)) ;;
        skipped) skip_count=$((skip_count + 1)) ;;
    esac
done

printf '\n'
printf '  %s\n' "$RULE"
printf '  %s%s STARLIGHT SYNC%s%s                             commit-msg%s\n' \
    "$CYAN" "$BOLD" "$NC" "$DIM" "$NC"
printf '  %s\n' "$RULE"
printf '\n'

printf '  %s%sCOMMIT MESSAGE%s\n' "$CYAN" "$BOLD" "$NC"

for (( i=0; i<hook_count; i++ )); do
    display=$(get_display "${h_names[$i]}")
    status="${h_statuses[$i]}"
    hook_output="${h_outputs[$i]}"

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
                local_count=0
                stripped=$(printf '%s' "$hook_output" | sed $'s/\033\\[[0-9;]*m//g')

                while IFS= read -r oline; do
                    [[ -z "$oline" ]] && continue
                    local_count=$((local_count + 1))
                    if [[ $local_count -le 8 ]]; then
                        printf '    %s│%s  %s%s%s\n' "$DIM" "$NC" "$DIM" "$oline" "$NC"
                    fi
                done <<< "$stripped"

                if [[ $local_count -gt 8 ]]; then
                    printf '    %s│  … and %d more lines%s\n' "$DIM" $((local_count - 8)) "$NC"
                fi
            fi

            hint=$(get_hint "${h_names[$i]}")
            printf '    %s│%s\n' "$DIM" "$NC"
            printf '    %s│%s  %s%s%s\n' "$DIM" "$NC" "$YELLOW" "$hint" "$NC"
            printf '\n'
            ;;
    esac
done

printf '\n'
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
    printf '\n  %sFix commit message, then commit again.%s\n' "$DIM" "$NC"
fi

printf '\n'
exit "$exit_code"
