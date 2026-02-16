# Secure Autonomous Agent Workflow — Claude Code with Elevated Permissions

**Document ID:** WORKFLOW-001
**Scope:** Starlight Sync (Project OtterVerse)
**Classification:** Internal Engineering Standard
**Authority:** Supplements `CLAUDE.md` governance. Does not override it.
**Last Updated:** 2026-02-15

---

## 1. Purpose

This document defines the operational workflow for running Claude Code with
`--dangerously-skip-permissions` (hereafter "skip-permissions mode") inside the
Starlight Sync repository. It specifies when the mode is permitted, what
safeguards must be active before invocation, how to scope the agent to specific
tasks, and how to recover if the agent produces incorrect output.

Skip-permissions mode removes all interactive approval prompts from Claude Code.
The agent reads files, writes files, executes shell commands, and performs
network operations without confirmation. This eliminates human checkpoints
during execution. The safeguards in this document replace those checkpoints with
infrastructure-level enforcement that operates independently of the agent's
behavior.

---

## 2. When Skip-Permissions Mode Is Allowed

### 2.1 Permitted Use Cases

Skip-permissions mode is authorized for the following task categories only:

| Task Category | Example | Rationale |
|---|---|---|
| Single-chapter implementation | `feat(ch2): implement PacketRunScene` | Scoped to one chapter directory; pre-commit hooks catch violations |
| Single-service implementation | `feat(webhook): implement WebhookService` | Scoped to one file in `Services/` |
| Bulk lint/format fixes | Applying SwiftFormat or SwiftLint auto-fixes | Deterministic transformations; no architectural risk |
| Test suite authoring | Writing XCTest cases per coverage matrix | Read-heavy; write-scoped to test target |
| Asset integration | Importing images, audio, AHAP files per ASSET_INT_PLAN | File placement per documented plan |
| Documentation generation | Writing epics, phase plans, ACS updates | Markdown only; no executable code |
| GameConstants updates | Adding tuning values, beat map entries | Single file; type-safe enums prevent cascading errors |

### 2.2 Prohibited Use Cases

Skip-permissions mode is **never** authorized for:

- Operations touching `main` branch directly (commits, merges, force pushes)
- Modifications to `.claude/skills/` (skill definitions are frozen without explicit approval)
- Modifications to `scripts/` (audit infrastructure is governance-critical)
- Modifications to `.pre-commit-config.yaml` or `.git/hooks/`
- Modifications to `CLAUDE.md`, `Design-Doc.md`, or `docs/ASSET_INT_PLAN.md`
- Operations involving plaintext secrets, `.env` files, signing certificates, or provisioning profiles
- Any operation requiring `--force`, `--hard`, or `--no-verify` git flags
- Cross-chapter refactors touching 3+ chapter directories simultaneously
- Dependency introduction (SPM, CocoaPods, Carthage — prohibited by architecture)
- Direct `.pbxproj` edits (high corruption risk; see §5.5)

### 2.3 Decision Framework

Before enabling skip-permissions mode, answer these three questions:

1. **Is the task scoped to a single directory or file group?** If the task
   touches files across 3+ unrelated directories, use interactive mode instead.
2. **Will pre-commit hooks catch all governance violations the agent could
   produce?** If the task involves operations that bypass git (e.g., direct file
   deletion, network calls), use interactive mode instead.
3. **Is a clean git checkpoint available for rollback?** If uncommitted work
   exists that would be lost on `git checkout .`, commit or stash first.

All three must be YES before proceeding.

---

## 3. Preconditions Checklist

Complete every item before invoking skip-permissions mode. No exceptions.

### 3.1 Repository State

- [ ] Working tree is clean (`git status` shows no uncommitted changes)
- [ ] Current branch is a feature/fix branch (never `main`)
- [ ] Branch is up to date with `origin/main` (`git pull origin main` or rebase)
- [ ] A rollback tag exists at the current HEAD (see §3.3)

### 3.2 Toolchain Verification

```bash
# Verify all tools are installed and functional
pre-commit --version          # >= 3.0
swiftformat --version         # Installed
swiftlint version             # Installed
python3 scripts/audit.py --all  # Exits 0 (all checks pass)
xcodebuild build \
  -project StarlightSync.xcodeproj \
  -scheme StarlightSync \
  -destination 'generic/platform=iOS Simulator' \
  2>&1 | tail -1             # "BUILD SUCCEEDED"
```

Every command above must succeed. If any fails, resolve the issue before
proceeding. Do not run skip-permissions mode with broken toolchain state.

### 3.3 Create Rollback Tag

```bash
git tag -a "pre-agent/$(date +%Y%m%d-%H%M%S)" -m "Checkpoint before skip-permissions run"
```

This tag enables instant rollback via:

```bash
git reset --hard pre-agent/<timestamp>
git clean -fd
```

### 3.4 Verify Pre-Commit Hooks Are Active

```bash
# Confirm hooks are installed and executable
test -x .git/hooks/pre-commit && echo "ACTIVE" || echo "MISSING"
test -x .git/hooks/commit-msg && echo "ACTIVE" || echo "MISSING"

# Dry-run the pre-commit suite
pre-commit run --all-files
```

If hooks are missing, reinstall:

```bash
pre-commit install
pre-commit install --hook-type commit-msg
```

Pre-commit hooks are the primary safety net in skip-permissions mode. The agent
can write any file, but it cannot commit governance-violating code because the
hooks reject the commit. This is infrastructure-level enforcement independent of
the agent's behavior.

### 3.5 Verify `.gitignore` Coverage

```bash
# Confirm secret patterns are excluded
grep -c '\.env' .gitignore        # Should be >= 2
grep -c 'Secrets' .gitignore      # Should be >= 1
grep -c '\.secret' .gitignore     # Should be >= 1
```

---

## 4. Required Repository Safeguards

These safeguards must be permanently active in the repository. They are not
optional. They function as the safety perimeter within which the agent operates.

### 4.1 Pre-Commit Hook Chain

The `.pre-commit-config.yaml` enforces the following checks on every commit
attempt. The agent cannot bypass these without modifying the config file itself,
which is prohibited (§2.2).

| Order | Hook ID | Check | Governance Reference |
|---|---|---|---|
| 1 | `protocol-zero` | No AI attribution markers | CLAUDE.md §1 |
| 2 | `trailing-whitespace` | Clean whitespace | Hygiene |
| 3 | `end-of-file-fixer` | Newline at EOF | Hygiene |
| 4 | `check-merge-conflict` | No conflict markers | Hygiene |
| 5 | `check-yaml` | Valid YAML syntax | Hygiene |
| 6 | `check-json` | Valid JSON syntax | Hygiene |
| 7 | `check-added-large-files` | No files > 10MB | Hygiene |
| 8 | `governance-audit` | FU/DA/DP/SL/CB checks | CLAUDE.md §9.5 |
| 9 | `shellcheck` | Shell script quality | Lint |
| 10 | `ruff` | Python lint + fix | Lint |
| 11 | `ruff-format` | Python formatting | Format |
| 12 | `markdownlint` | Markdown formatting | Lint |
| 13 | `swiftformat` | Swift formatting | Format |
| 14 | `swiftlint` | Swift lint (strict) | Lint |

Commit-msg hooks additionally enforce:

| Hook ID | Check | Governance Reference |
|---|---|---|
| `protocol-zero-commit-msg` | No AI attribution in commit messages | CLAUDE.md §1 |
| `conventional-commits` | Format: `type(scope): description` | CLAUDE.md §9.3 |

### 4.2 Branch Protection

`main` is protected on GitHub. Direct pushes are rejected server-side. This
protection is independent of the local environment and cannot be circumvented by
the agent.

### 4.3 Build Validation

After the agent completes work, the project must build:

```bash
xcodebuild build \
  -project StarlightSync.xcodeproj \
  -scheme StarlightSync \
  -destination 'generic/platform=iOS Simulator'
```

Build failure after an agent run is treated as a failed run. See §9 for
recovery.

### 4.4 Audit Script

The `scripts/audit.py` script provides on-demand governance scanning independent
of the git commit cycle:

```bash
python3 scripts/audit.py --all    # Full repository scan
python3 scripts/audit.py --staged  # Staged files only
```

Checks enforced: PZ-001 (no AI attribution), FU-001 (no force unwraps), DA-001
(no debug artifacts), DP-001 (no deprecated APIs), SL-001 (no plaintext
secrets), CC-001 (conventional commits), CB-001 (no Combine).

### 4.5 Protocol Zero Scanner

The `scripts/protocol-zero.sh` script provides deep scanning for AI attribution
markers across the entire codebase:

```bash
./scripts/protocol-zero.sh           # Full scan
./scripts/protocol-zero.sh --verbose  # Extended diagnostics
```

Run this after every skip-permissions session, regardless of whether the agent's
commits passed pre-commit hooks.

---

## 5. Risk Surface Analysis and Mitigations

### 5.1 File Deletion Risk

**Threat:** Agent executes `rm`, `git rm`, or overwrites files with empty
content, destroying source code or assets.

**Mitigations:**

- Rollback tag (§3.3) enables instant recovery via `git reset --hard`
- Git tracks all deletions; `git diff` reveals any removed files before commit
- Feature branch isolation means `main` is never at risk

**Post-run validation:**

```bash
git diff --stat HEAD  # Review all file changes before committing
git diff --name-only --diff-filter=D HEAD  # List any deleted files
```

### 5.2 Secret Exposure Risk

**Threat:** Agent writes plaintext Discord webhook URL, API keys, or other
secrets into source files, comments, logs, or documentation.

**Mitigations:**

- SL-001 pre-commit check scans staged files for `https://discord.com/api/webhooks/` patterns
- `.gitignore` excludes `.env`, `*.secret`, `Secrets.plaintext`, `*.pem`, `*.p12`
- CLAUDE.md §5 instructs the agent to never handle plaintext secrets
- Protocol Zero scanner catches attribution-adjacent secret leakage

**Post-run validation:**

```bash
grep -r "discord.com/api/webhooks" StarlightSync/ --include="*.swift"  # Must return 0 results
grep -r "https://hooks" StarlightSync/ --include="*.swift"  # Must return 0 results
```

### 5.3 Unauthorized Architecture Changes

**Threat:** Agent introduces third-party dependencies, adds Combine imports,
uses `ObservableObject` instead of `@Observable`, creates unauthorized
singletons, or violates component boundaries.

**Mitigations:**

- CB-001 pre-commit check scans for Combine imports
- DP-001 pre-commit check scans for deprecated APIs (`ObservableObject`, `@Published`, etc.)
- SwiftLint rules enforce coding standards
- CLAUDE.md §3 explicitly prohibits SPM/CocoaPods/Carthage

**Post-run validation:**

```bash
grep -r "import Combine" StarlightSync/ --include="*.swift"        # Must return 0
grep -r "ObservableObject" StarlightSync/ --include="*.swift"      # Must return 0
grep -r "@Published" StarlightSync/ --include="*.swift"            # Must return 0
grep -r "DispatchQueue" StarlightSync/ --include="*.swift"         # Must return 0
grep -r "\.package(url:" . --include="Package.swift"               # Must return 0
```

### 5.4 pbxproj Corruption Risk

**Threat:** Agent modifies `StarlightSync.xcodeproj/project.pbxproj` with
malformed entries, breaking the Xcode project.

**Mitigations:**

- CLAUDE.md §6 prohibits manual `.pbxproj` edits
- Any `.pbxproj` modification must be validated by a successful `xcodebuild build`
- Rollback tag enables recovery if the project file is corrupted

**Post-run validation:**

```bash
# Verify project file parses correctly
xcodebuild -list -project StarlightSync.xcodeproj 2>&1 | head -5
# If this fails, the pbxproj is corrupted — rollback immediately
```

**Recovery:**

```bash
git checkout -- StarlightSync.xcodeproj/project.pbxproj
```

### 5.5 Git Operations Risk

**Threat:** Agent executes `git push --force`, `git reset --hard`, commits
directly to `main`, or deletes remote branches.

**Mitigations:**

- GitHub branch protection rejects direct pushes to `main`
- CLAUDE.md §9.1 instructs the agent to refuse direct `main` commits
- The agent does not have `--force` in its allowed patterns
- Rollback tag preserves local state regardless of git operations

**Post-run validation:**

```bash
git log --oneline -5  # Review recent commits for unexpected entries
git branch -a         # Verify no unexpected branch creation/deletion
```

---

## 6. Safe Invocation Patterns

### 6.1 Standard Invocation (Recommended)

```bash
# 1. Ensure clean state
git status

# 2. Create feature branch
git checkout -b feat/ch2-packet-run

# 3. Create rollback checkpoint
git tag -a "pre-agent/$(date +%Y%m%d-%H%M%S)" -m "Checkpoint before agent run"

# 4. Invoke Claude Code with skip-permissions
claude --dangerously-skip-permissions \
  -p "Implement Chapter 2 PacketRunScene per Design-Doc §3.3 and CLAUDE.md §4.3. \
      Use the chapter-scaffold skill. Write files only to \
      StarlightSync/Chapters/Chapter2_PacketRun/. Do not modify any files outside \
      that directory except GameConstants.swift and project.pbxproj. \
      Do not commit. Do not push."

# 5. Validate (see §8)
```

### 6.2 Scoped Invocation with AllowedTools (Preferred Alternative)

Instead of skip-permissions mode, use granular tool allowlists. This provides
autonomous execution for safe operations while retaining prompts for dangerous
ones.

Create or update `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Glob",
      "Grep",
      "Write(StarlightSync/**)",
      "Edit(StarlightSync/**)",
      "Bash(xcodebuild:*)",
      "Bash(python3 scripts/audit.py:*)",
      "Bash(pre-commit run:*)",
      "Bash(swiftformat:*)",
      "Bash(swiftlint:*)",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git add:*)",
      "Bash(git checkout -b:*)",
      "Bash(git branch:*)"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Bash(git push --force:*)",
      "Bash(git reset --hard:*)",
      "Bash(git checkout .)",
      "Bash(curl:*)",
      "Bash(wget:*)",
      "Write(.claude/skills/**)",
      "Write(scripts/**)",
      "Write(CLAUDE.md)",
      "Write(Design-Doc.md)",
      "Write(.pre-commit-config.yaml)",
      "Write(.git/**)"
    ]
  }
}
```

Then invoke normally (without skip-permissions):

```bash
claude -p "Implement Chapter 2 PacketRunScene per Design-Doc §3.3."
```

The agent operates autonomously within the allow list. Operations matching deny
rules are blocked. Operations not in either list prompt for confirmation. This
is the approach recommended by Anthropic's engineering team as superior to
skip-permissions mode.

### 6.3 Headless CI/CD Invocation

For automated pipeline execution (e.g., running the agent in a GitHub Actions
workflow):

```bash
claude --dangerously-skip-permissions \
  -p "Run the full audit suite and report results." \
  --output-format stream-json \
  --max-turns 10
```

**Mandatory conditions for CI/CD usage:**

- The runner must be ephemeral (destroyed after each job)
- The runner must have no access to production secrets
- The runner must have no push access to `main`
- The runner must have network access restricted to `github.com` only
- Results must be reviewed by a human before merge

### 6.4 Prompt Engineering for Safety

Every prompt to the agent in skip-permissions mode must include explicit
constraints. The agent follows CLAUDE.md, but reinforcing critical boundaries in
the prompt adds defense-in-depth.

**Required prompt elements:**

1. **Task scope:** Name the specific files or directories the agent should touch
2. **Boundary statement:** Name files or directories the agent must not touch
3. **Commit prohibition:** "Do not commit. Do not push." (human commits after review)
4. **Architecture reference:** Cite the Design-Doc section governing the task

**Template:**

```
Implement [FEATURE] per Design-Doc §[SECTION] and CLAUDE.md §[SECTION].

Scope:
- Write files to: [DIRECTORY]
- Modify existing: [FILE1], [FILE2]

Boundaries:
- Do not modify files outside the scope above
- Do not modify CLAUDE.md, Design-Doc.md, or any file in scripts/
- Do not add third-party dependencies
- Do not commit or push

References:
- [SKILL] skill for implementation patterns
- GameConstants for all tuning values
```

---

## 7. Required Hooks and Automation

### 7.1 Git Hooks (Currently Installed)

| Hook | Location | Purpose |
|---|---|---|
| `pre-commit` | `.git/hooks/pre-commit` | Runs pre-commit framework with visual output |
| `commit-msg` | `.git/hooks/commit-msg` | Validates commit message format and Protocol Zero |

Both hooks delegate to the pre-commit framework, which executes the full check
chain defined in `.pre-commit-config.yaml` (§4.1).

### 7.2 Claude Code Hooks (Recommended Addition)

Claude Code supports user-defined hooks that execute shell commands in response
to agent events. Create `.claude/hooks.json` to add enforcement at the agent
level:

```json
{
  "hooks": [
    {
      "event": "preToolCall",
      "command": "python3 scripts/audit.py --all",
      "description": "Run governance audit before every tool call",
      "enabled": false
    }
  ]
}
```

**Note:** This hook configuration is not currently active in the repository. The
`preToolCall` event fires before every tool invocation, which creates
significant latency. Enable selectively during high-risk sessions only. The
primary enforcement remains the pre-commit hook chain, which fires at commit
time.

### 7.3 Post-Session Automation Script

Create and run this script after every skip-permissions session:

```bash
#!/usr/bin/env bash
# post-agent-validate.sh — Run after every skip-permissions session

set -euo pipefail

echo "=== Post-Agent Validation ==="

echo "[1/6] Protocol Zero scan..."
./scripts/protocol-zero.sh

echo "[2/6] Governance audit..."
python3 scripts/audit.py --all

echo "[3/6] Pre-commit dry run..."
pre-commit run --all-files

echo "[4/6] Build validation..."
xcodebuild build \
  -project StarlightSync.xcodeproj \
  -scheme StarlightSync \
  -destination 'generic/platform=iOS Simulator' \
  2>&1 | tail -5

echo "[5/6] Secret scan..."
SECRETS=$(grep -r "discord.com/api/webhooks" StarlightSync/ --include="*.swift" 2>/dev/null | wc -l)
if [ "$SECRETS" -gt 0 ]; then
  echo "FAIL: Plaintext webhook URL detected"
  exit 1
fi
echo "PASS: No plaintext secrets"

echo "[6/6] Architecture scan..."
for PATTERN in "import Combine" "ObservableObject" "@Published" "DispatchQueue"; do
  COUNT=$(grep -r "$PATTERN" StarlightSync/ --include="*.swift" 2>/dev/null | wc -l)
  if [ "$COUNT" -gt 0 ]; then
    echo "FAIL: Prohibited pattern '$PATTERN' found ($COUNT occurrences)"
    exit 1
  fi
done
echo "PASS: No prohibited patterns"

echo ""
echo "=== ALL CHECKS PASSED ==="
```

---

## 8. Monitoring and Validation Steps

### 8.1 During Execution

Skip-permissions mode streams agent output to the terminal. Monitor for:

- **File operations outside the declared scope.** If the agent writes to a
  directory not specified in the prompt, terminate immediately with `Ctrl+C`.
- **Git operations.** If the agent attempts `git commit`, `git push`, or
  `git checkout main`, terminate immediately.
- **Network operations.** If the agent attempts `curl`, `wget`, or any network
  call, terminate immediately.
- **Destructive operations.** If the agent attempts `rm -rf`, `git reset`, or
  `git clean`, terminate immediately.

Termination with `Ctrl+C` is safe. The agent stops immediately. Partial file
writes may exist; the rollback tag (§3.3) recovers to the pre-session state.

### 8.2 After Execution

Run the full validation suite in this exact order:

```bash
# Step 1: Review what changed
git status
git diff

# Step 2: Run post-session validation
bash scripts/post-agent-validate.sh  # Or run §7.3 commands manually

# Step 3: Verify build
xcodebuild build \
  -project StarlightSync.xcodeproj \
  -scheme StarlightSync \
  -destination 'generic/platform=iOS Simulator'

# Step 4: Run tests (if test target exists)
xcodebuild test \
  -project StarlightSync.xcodeproj \
  -scheme StarlightSync \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Step 5: Human review of diff
git diff HEAD  # Read every line before staging
```

### 8.3 Validation Checklist

- [ ] `git status` shows only expected file modifications
- [ ] `git diff` shows no changes to prohibited files (CLAUDE.md, Design-Doc.md, scripts/, .claude/skills/)
- [ ] Protocol Zero scan passes
- [ ] Governance audit passes
- [ ] Pre-commit dry run passes on all files
- [ ] Project builds without errors
- [ ] No plaintext secrets in Swift source files
- [ ] No prohibited patterns (Combine, ObservableObject, DispatchQueue)
- [ ] No force unwraps added
- [ ] No `print` statements added
- [ ] SwiftUI views include `#Preview` macros
- [ ] All tuning values reference `GameConstants`

---

## 9. Failure Recovery Procedures

### 9.1 Agent Produced Invalid Code (Build Fails)

```bash
# Option A: Fix specific issues
# Read build errors, fix manually, validate again

# Option B: Full rollback
git checkout -- .
git clean -fd
# Or if rollback tag exists:
git reset --hard pre-agent/<timestamp>
```

### 9.2 Agent Modified Prohibited Files

```bash
# Restore specific files
git checkout HEAD -- CLAUDE.md
git checkout HEAD -- Design-Doc.md
git checkout HEAD -- scripts/
git checkout HEAD -- .claude/skills/
git checkout HEAD -- .pre-commit-config.yaml

# Then re-validate
python3 scripts/audit.py --all
```

### 9.3 Agent Corrupted pbxproj

```bash
# Restore project file from last known good state
git checkout HEAD -- StarlightSync.xcodeproj/project.pbxproj

# Verify
xcodebuild -list -project StarlightSync.xcodeproj
```

### 9.4 Agent Created Unwanted Commits

```bash
# Identify the last good commit
git log --oneline -10

# Reset to before agent commits (preserving working tree)
git reset --soft <last-good-commit-hash>

# Review staged changes, then re-commit manually
git diff --cached
```

### 9.5 Agent Pushed to Remote

If the agent pushed to a feature branch (not `main`):

```bash
# Force-push the corrected branch
git push --force-with-lease origin <branch-name>
```

If the agent somehow pushed to `main` (should be blocked by GitHub branch
protection):

```bash
# Contact repository administrator immediately
# Do NOT attempt to force-push main
# Create an issue documenting the incident
```

### 9.6 Nuclear Recovery

If the repository state is unclear or multiple issues compound:

```bash
# Clone fresh from remote
cd /tmp
git clone https://github.com/dinesh-git17/otterverse-experience.git otterverse-clean
# Copy the fresh clone back to the working directory
```

---

## 10. Human Review Checkpoints

Skip-permissions mode removes approval prompts during execution. The following
human review checkpoints compensate by inserting verification gates between
execution and integration.

### 10.1 Mandatory Review Gates

| Gate | Timing | Action | Reviewer |
|---|---|---|---|
| **G1: Diff Review** | After agent completes, before `git add` | Read every line of `git diff`. Reject if scope exceeded. | Engineer |
| **G2: Build Verification** | After staging, before commit | `xcodebuild build` must succeed | Automated |
| **G3: Pre-Commit Hooks** | During `git commit` | Full hook chain must pass | Automated |
| **G4: PR Review** | After push, before merge | GitHub PR review with full diff | Engineer |
| **G5: CI Checks** | During PR lifecycle | PR title validation, status checks | Automated |

### 10.2 Review Focus Areas

When reviewing agent output at G1 and G4, prioritize:

1. **Component boundary violations** (CLAUDE.md §3.3) — Does the code access
   components outside the authorized matrix?
2. **State management patterns** — Is `@Observable` used (not `ObservableObject`)?
   Is `async/await` used (not GCD/Combine)?
3. **Magic numbers** — Are all numeric literals defined in `GameConstants`?
4. **Force unwraps** — Any `!` operator outside Apple-required contexts?
5. **File scope** — Did the agent create files outside the declared scope?
6. **Protocol Zero** — Any conversational filler, apologetic preambles, or AI
   attribution markers in comments or documentation?
7. **Security** — Any plaintext URLs, secrets, or logging of sensitive data?

### 10.3 Non-Negotiable Rule

**No agent output reaches `main` without passing through all five gates (G1-G5).**

The agent produces code. Pre-commit hooks validate governance. The engineer
reviews the diff. The PR process validates integration. This is a four-layer
defense model:

1. **Agent-level:** CLAUDE.md instructions constrain behavior at the prompt level
2. **Infrastructure-level:** Pre-commit hooks reject violations at commit time
3. **Human-level:** Engineer reviews diff before staging and PR before merge
4. **Platform-level:** GitHub branch protection enforces PR-only access to `main`

---

## 11. Recommended Daily Workflow

### 11.1 Session Start

```bash
# 1. Pull latest main
git checkout main
git pull origin main

# 2. Create feature branch
git checkout -b feat/<scope>-<description>

# 3. Verify toolchain
pre-commit run --all-files
xcodebuild build -project StarlightSync.xcodeproj \
  -scheme StarlightSync \
  -destination 'generic/platform=iOS Simulator'

# 4. Create rollback checkpoint
git tag -a "pre-agent/$(date +%Y%m%d-%H%M%S)" \
  -m "Checkpoint before skip-permissions run"
```

### 11.2 Agent Execution

```bash
# 5. Invoke agent with explicit scope (choose one approach)

# Approach A: Skip-permissions with scoped prompt
claude --dangerously-skip-permissions \
  -p "<task prompt with scope, boundaries, and references per §6.4>"

# Approach B: AllowedTools (preferred — see §6.2)
claude -p "<task prompt>"
```

### 11.3 Post-Execution

```bash
# 6. Validate output
git status
git diff

# 7. Run governance checks
./scripts/protocol-zero.sh
python3 scripts/audit.py --all
pre-commit run --all-files

# 8. Build
xcodebuild build -project StarlightSync.xcodeproj \
  -scheme StarlightSync \
  -destination 'generic/platform=iOS Simulator'

# 9. Human review (G1 — read every line)
git diff HEAD

# 10. Stage and commit
git add <specific-files>
git commit -m "$(cat <<'EOF'
feat(ch2): add obstacle spawning with parallax scrolling
EOF
)"

# 11. Push and create PR
git push -u origin feat/<scope>-<description>
gh pr create --title "feat(ch2): add obstacle spawning" \
  --body "$(cat <<'EOF'
## Summary
- Implement PacketRunScene with physics-based collision
- Add obstacle spawning with parallax background
- Wire Auto-Assist after 3 deaths

## Test plan
- [ ] Build succeeds on iOS Simulator
- [ ] Pre-commit hooks pass
- [ ] On-device playtest validates gameplay
EOF
)"
```

### 11.4 Session End

```bash
# 12. Clean up rollback tags (keep last 5)
git tag -l "pre-agent/*" | sort | head -n -5 | xargs -I {} git tag -d {}

# 13. Update ACS if applicable
# Edit .claude/context/progress/active.md with current state
# Edit .claude/context/MANIFEST.md if phase milestone reached
```

---

## 12. Security Considerations and Warnings

### 12.1 What Skip-Permissions Mode Disables

When `--dangerously-skip-permissions` is active, Claude Code does **not**
prompt for confirmation before:

- Reading any file on the filesystem (including outside the repository)
- Writing or overwriting any file on the filesystem
- Deleting files
- Executing arbitrary shell commands
- Making network requests
- Spawning child processes

The agent operates with the full permissions of the invoking user's shell
session. It can access anything the user can access.

### 12.2 Prompt Injection Risk

In skip-permissions mode, the agent processes content from files it reads. If a
file in the repository contains adversarial instructions (prompt injection), the
agent may follow those instructions instead of or in addition to the user's
prompt.

**Mitigations in this repository:**

- All source files are authored by known contributors
- Pre-commit hooks scan for known injection patterns
- The repository does not fetch external content during build

**Remaining risk:** If the agent reads files from outside the repository (e.g.,
system files, downloaded content), prompt injection is possible. The scoped
prompts in §6.4 reduce this risk by constraining the agent's operational
directory.

### 12.3 Credential Exposure

The agent runs in the user's shell environment with access to:

- `~/.ssh/` (SSH keys)
- `~/.gitconfig` (Git credentials)
- `~/.zshrc` / `~/.bashrc` (environment variables)
- macOS Keychain (via `security` command)
- Any environment variable in the current shell

**Mitigations:**

- CLAUDE.md §5 prohibits the agent from reading, modifying, or creating files
  containing secrets
- The scoped prompts in §6.4 constrain the agent to the repository directory
- The AllowedTools approach (§6.2) restricts Write operations to `StarlightSync/`

**Recommendation:** For maximum isolation, run skip-permissions sessions in a
shell with a minimal environment:

```bash
env -i HOME="$HOME" PATH="/usr/bin:/usr/local/bin:$PATH" \
  claude --dangerously-skip-permissions -p "<prompt>"
```

### 12.4 Network Exfiltration Risk

In skip-permissions mode, the agent can execute `curl`, `wget`, or any network
command without approval.

**Mitigations in this repository:**

- The application has no network dependencies beyond the Discord webhook
- The repository contains no API keys or tokens (webhook URL is XOR-encoded)
- Pre-commit SL-001 check scans for plaintext secrets before commit

**Recommendation:** If network isolation is required, use macOS application
firewall rules or run inside a Docker container with `--network none`.

### 12.5 The AllowedTools Alternative

Anthropic's engineering team explicitly recommends `AllowedTools` configuration
over `--dangerously-skip-permissions` for production workflows. The AllowedTools
approach (§6.2) provides:

- **Granular control:** Auto-approve safe operations (read, search, build) while
  retaining prompts for dangerous ones (delete, push, network)
- **Deny rules:** Hard blocks on operations that should never execute regardless
  of context
- **Audit trail:** Operations that required explicit approval are logged
  separately from auto-approved operations
- **No behavioral difference for safe operations:** The agent still operates
  autonomously for the majority of its work

Skip-permissions mode is appropriate only when the AllowedTools approach cannot
cover the required operations, or when running in an ephemeral, isolated
environment (CI/CD, Docker container, VM).

### 12.6 Incident Response

If a skip-permissions session produces a security-relevant event (secret
exposure, unauthorized network call, file access outside repository):

1. **Terminate** the agent immediately (`Ctrl+C`)
2. **Rollback** to the pre-session tag (`git reset --hard pre-agent/<timestamp>`)
3. **Audit** the filesystem for unexpected modifications (`find . -newer <rollback-tag-file> -type f`)
4. **Rotate** any credentials that may have been exposed
5. **Document** the incident with the exact prompt used, agent output observed,
   and files affected

---

## Appendix A: Quick Reference Card

```
BEFORE:
  git checkout -b feat/<scope>-<desc>
  git tag -a "pre-agent/$(date +%Y%m%d-%H%M%S)" -m "Checkpoint"
  pre-commit run --all-files  # Must pass

INVOKE:
  claude --dangerously-skip-permissions -p "<scoped prompt>"

  OR (preferred):
  claude -p "<prompt>"  # With AllowedTools configured per §6.2

AFTER:
  git diff                          # Read every line
  ./scripts/protocol-zero.sh       # Must pass
  python3 scripts/audit.py --all   # Must pass
  pre-commit run --all-files        # Must pass
  xcodebuild build ...              # Must succeed

COMMIT:
  git add <specific-files>          # Never git add -A
  git commit -m "type(scope): desc" # Hooks enforce governance
  git push -u origin <branch>
  gh pr create ...

ROLLBACK:
  git reset --hard pre-agent/<timestamp>
  git clean -fd
```

## Appendix B: Compatibility Notes

- **macOS Seatbelt sandboxing** (`/sandbox` command in Claude Code) provides
  OS-level filesystem and network isolation. When available, prefer sandbox mode
  over skip-permissions mode for equivalent autonomy with stronger isolation.
- **Docker isolation** provides the strongest guarantees. Mount the repository as
  a volume, run Claude Code inside the container with `--network none`, and copy
  results out for review. Anthropic provides a reference container configuration
  at `github.com/anthropic-experimental/sandbox-runtime`.
- **Claude Code hooks** (`.claude/hooks.json`) are a developing feature. As
  hook event types expand, integrate `preToolCall` and `postToolCall` hooks to
  add enforcement points between the agent and the filesystem.
