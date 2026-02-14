# Epic: INFRA_02 — Initialize Version Control

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | INFRA_02                       |
| **Epic Name** | initialize_version_control     |
| **Phase**     | PH-01                          |
| **Domain**    | INFRA                          |
| **Owner**     | iOS Engineer                   |
| **Status**    | Complete                       |

---

## Problem Statement

The repository has no git history. Governance documents (`CLAUDE.md`, `Design-Doc.md`), skill infrastructure, and agent context files exist on disk but are unversioned. The Xcode project (produced by INFRA_01) has no version control protection. Without git initialization, there is no rollback capability, no commit-gated quality enforcement, no branch isolation for feature work, and no audit trail for architectural decisions. The pre-commit auditor (`scripts/audit.py`) defined in CLAUDE.md §9 cannot execute without a git repository.

Additionally, the Design-Doc §9.4 mandates source control exclusion rules for secrets — Discord webhook URLs must never appear in plaintext in tracked files. The `.gitignore` must be configured before any commit to prevent accidental inclusion of build artifacts, user-specific Xcode state, and sensitive files.

---

## Goals

- Initialize a git repository with a `.gitignore` that excludes Xcode build artifacts, user state, and secret patterns per CLAUDE.md §9 and Design-Doc §9.4.
- Produce a clean initial commit on `main` containing the complete project skeleton (Xcode project, directory structure, governance documents, skill infrastructure, and agent context system).
- Establish the pre-commit audit script skeleton so that commit-gated quality enforcement can activate in subsequent phases.

## Non-Goals

- **No remote repository setup.** Per CLAUDE.md §9, all work is local and pre-remote. No `git remote add`, no GitHub/GitLab configuration, no push operations.
- **No branch creation beyond `main`.** Feature branches (`feat/<chapter>-<desc>`) are created during implementation phases. This epic establishes the trunk only.
- **No CI/CD integration.** No GitHub Actions, no Xcode Cloud, no Fastlane. Pre-commit enforcement is local script-based.
- **No full pre-commit auditor implementation.** The audit script skeleton is created for structural readiness. Rule implementation (PZ-001 through CB-001) is a separate concern addressed by the pre-commit-auditor skill during active development.

---

## Technical Approach

Git initialization follows CLAUDE.md §9 workflow rules. The `.gitignore` will be constructed from the Xcode/Swift standard exclusion set (`*.xcuserdata`, `DerivedData/`, `.build/`, `*.xcworkspace` if unneeded) and augmented with the Design-Doc §9.4 secret exclusion patterns (`Secrets.plaintext`, `*.secret`, `*.env`). The `.gitignore` is created and validated before `git init` to ensure the first commit never tracks excluded artifacts.

The initial commit follows Conventional Commits format per CLAUDE.md §9: `chore(scaffold): initialize Xcode project with directory structure and governance docs`. This commit captures the complete INFRA_01 output plus all pre-existing repository files (governance docs, skill infrastructure, agent context system, phase plan) in a single atomic snapshot.

The pre-commit audit script (`scripts/audit.py`) will be created as a structural placeholder with the check ID registry (PZ-001 through CB-001) defined as stubs. The script will be executable (`chmod 755`) and accept `--staged` and `--all` flags per CLAUDE.md §9. Full rule implementation is deferred to the first phase where commit-gated enforcement becomes actionable (PH-02).

The commit will be verified by checking `git log --oneline` shows exactly one commit, `git status` shows a clean working tree, and `git diff --cached` is empty post-commit.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency                             | Source   | Status    | Owner        |
| -------------------------------------- | -------- | --------- | ------------ |
| Buildable Xcode project with directory structure | INFRA_01 | Complete | iOS Engineer |
| Governance documents on disk (`CLAUDE.md`, `Design-Doc.md`) | External | Committed | Project Owner |

### Outbound (This Epic Unblocks)

| Dependency                           | Target | Description                                                                |
| ------------------------------------ | ------ | -------------------------------------------------------------------------- |
| Git repository with initial commit   | PH-02  | FlowCoordinator implementation requires version-controlled project         |
| Pre-commit audit script skeleton     | PH-02+ | Commit-gated quality enforcement activates once rules are implemented      |
| `.gitignore` with secret exclusions  | PH-12  | WebhookService development requires secret patterns excluded from tracking |
| Version-controlled project baseline  | All    | Every subsequent phase creates commits against this initial baseline       |

---

## Stories

### Story 1: Create .gitignore with Xcode/Swift exclusion rules

**Acceptance Criteria:**

- [x] `.gitignore` file exists at the repository root.
- [x] Excludes `*.xcuserdata` (Xcode user-specific state).
- [x] Excludes `DerivedData/` (build intermediates and indexes).
- [x] Excludes `.build/` (Swift Package Manager build directory, defensive).
- [x] Excludes `*.xcworkspace` if no workspace is required by the project structure.
- [x] Excludes `*.pbxuser`, `*.perspectivev3`, `xcuserdata/` variants.
- [x] Excludes OS artifacts: `.DS_Store`, `._*`, `Thumbs.db`.
- [x] Does NOT exclude the `.xcodeproj` bundle (required for version control).
- [x] Does NOT exclude `Assets.xcassets` or any source directories.

**Dependencies:** None
**Completion Signal:** `.gitignore` file exists at repository root with all specified patterns. Manual verification against CLAUDE.md §9 exclusion list.

---

### Story 2: Configure source control exclusion for secrets per Design-Doc §9.4

**Acceptance Criteria:**

- [x] `.gitignore` includes `Secrets.plaintext` pattern.
- [x] `.gitignore` includes `*.secret` glob pattern.
- [x] `.gitignore` includes `*.env` glob pattern.
- [x] `.gitignore` includes `.env` (dotenv files).
- [x] `.gitignore` includes `*.pem`, `*.p12`, `*.mobileprovision` (certificate/provisioning artifacts).
- [x] No plaintext Discord webhook URL pattern (`https://discord.com/api/webhooks/`) exists in any tracked file.
- [x] Comment in `.gitignore` references Design-Doc §9.4 for secret exclusion rationale.

**Dependencies:** INFRA_02-S1
**Completion Signal:** `grep -r "discord.com/api/webhooks" .` returns zero results across all files staged for commit.

---

### Story 3: Create pre-commit audit script skeleton

**Acceptance Criteria:**

- [x] `scripts/audit.py` exists with executable permissions (`chmod 755`).
- [x] Script accepts `--staged` flag (runs checks on staged files only).
- [x] Script accepts `--all` flag (runs checks on entire repository).
- [x] Check ID registry is defined with all 7 check IDs from CLAUDE.md §9: PZ-001 (AI attribution), FU-001 (force unwraps), DA-001 (debug artifacts), DP-001 (deprecated APIs), SL-001 (plaintext secrets), CC-001 (Conventional Commits), CB-001 (Combine prohibition).
- [x] Each check is implemented as a named stub that returns pass (no false negatives on empty project).
- [x] Script prints check results in a structured format (check ID, status, file count).
- [x] Script exits with code 0 when all checks pass, code 1 when any check fails.
- [x] No `print` statements — uses structured output only.

**Dependencies:** None
**Completion Signal:** `python3 scripts/audit.py --all` executes successfully and exits with code 0 on the clean project skeleton.

---

### Story 4: Initialize git repository on main branch

**Acceptance Criteria:**

- [x] `git init` executed at the repository root.
- [x] Default branch is `main` (not `master`).
- [x] `git config` for the repository does not contain AI-attributed user names or emails (Protocol Zero).
- [x] `.git/` directory exists and is a valid git repository.
- [x] `git status` shows untracked files ready for staging.

**Dependencies:** INFRA_02-S1, INFRA_02-S2
**Completion Signal:** `git rev-parse --is-inside-work-tree` returns `true`. `git branch --show-current` returns `main`.

---

### Story 5: Create initial commit with project skeleton and governance documents

**Acceptance Criteria:**

- [x] All project files staged via `git add`: Xcode project, source directories (with `.gitkeep` files), `Assets.xcassets`, `Audio/`, `Haptics/`, `StarlightSyncApp.swift`.
- [x] All governance documents staged: `CLAUDE.md`, `Design-Doc.md`, `docs/PHASES.md`, `docs/AGENT_CONTEXT_SYSTEM.md`.
- [x] All skill infrastructure staged: `.claude/skills/` directory tree.
- [x] All agent context files staged: `.claude/context/` directory tree.
- [x] Pre-commit audit script staged: `scripts/audit.py`.
- [x] `.gitignore` staged.
- [x] Commit message follows Conventional Commits format: `chore(scaffold): initialize Xcode project with directory structure and governance docs`.
- [x] No files matching `.gitignore` patterns are included in the commit.
- [x] No plaintext secrets in any committed file.

**Dependencies:** INFRA_01 (all stories), INFRA_02-S1, INFRA_02-S2, INFRA_02-S3, INFRA_02-S4
**Completion Signal:** `git log --oneline` shows exactly one commit with the correct message format. `git status` shows clean working tree.

---

### Story 6: Validate repository state and PH-01 Definition of Done

**Acceptance Criteria:**

- [x] `git log --oneline` shows one commit on `main`.
- [x] `git status` returns clean working tree (nothing to commit, working tree clean).
- [x] `git diff` returns empty (no unstaged changes).
- [x] `xcodebuild build` succeeds from a clean state (delete DerivedData first).
- [x] `python3 scripts/audit.py --all` exits with code 0.
- [x] Directory tree matches CLAUDE.md §8 canonical structure (verified via `find` comparison).
- [x] No `.gitignore`-excluded files appear in `git ls-files` output.
- [x] `git ls-files` includes `CLAUDE.md` and `Design-Doc.md`.
- [x] PH-01 Definition of Done checklist from PHASES.md is fully satisfied: buildable project, correct directory tree, `.gitignore` with required exclusions, governance docs committed.

**Dependencies:** INFRA_02-S5
**Completion Signal:** All 9 acceptance criteria verified. PH-01 phase gate passed. PH-02 (FlowCoordinator State Machine) is unblocked for execution.

---

## Risks

| Risk                                                                   | Impact (1-5) | Likelihood (1-5) | Score | Mitigation                                                                                               | Owner        |
| ---------------------------------------------------------------------- | :----------: | :--------------: | :---: | -------------------------------------------------------------------------------------------------------- | ------------ |
| Accidental commit of sensitive file before `.gitignore` is configured  |      5       |        2         |  10   | Create `.gitignore` as the absolute first file operation. Validate with `git status` before first `git add`. | iOS Engineer |
| `.pbxproj` merge conflicts in future multi-agent sessions              |      3       |        3         |   9   | Record in ACS constraints. Mandate single-agent Xcode project edits. Resolve via Xcode GUI, not manual edit. | iOS Engineer |
| Pre-commit script Python version incompatibility                       |      2       |        2         |   4   | Target Python 3.9+ (ships with macOS). No external pip dependencies. Verify with `python3 --version`.    | iOS Engineer |
| `.gitkeep` files pollute project navigator in Xcode                    |      1       |        3         |   3   | Remove `.gitkeep` from each directory as real source files are added. Track removal in commit messages.   | iOS Engineer |

---

## Definition of Done

- [x] All 6 stories completed and individually verified.
- [x] Git repository initialized with clean working tree on `main` branch.
- [x] `.gitignore` excludes all required patterns (build artifacts, user state, secrets).
- [x] Initial commit contains complete project skeleton and all governance documents.
- [x] `scripts/audit.py` executes successfully with `--staged` and `--all` flags.
- [x] No plaintext secrets in any committed file (`grep` verification).
- [x] Commit message follows Conventional Commits format per CLAUDE.md §9.
- [x] No AI attribution artifacts in commit message or committed files (Protocol Zero).

## Exit Criteria

- [x] All Definition of Done conditions satisfied.
- [x] `git log --oneline` shows exactly one commit with correct format.
- [x] `git status` returns clean working tree.
- [x] `xcodebuild build` succeeds on clean checkout (DerivedData deleted).
- [x] `python3 scripts/audit.py --all` exits with code 0.
- [x] PH-01 phase Definition of Done from PHASES.md is fully satisfied.
- [x] PH-02 (FlowCoordinator State Machine) and PH-12 (WebhookService) are unblocked.
- [x] ACS files updated: `MANIFEST.md` reflects PH-01 complete, `progress/completed.md` records deliverables.
