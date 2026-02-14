---
name: Governance Violation
about: Report a violation of CLAUDE.md or Design-Doc.md engineering standards
title: "fix(<scope>): resolve governance violation — "
labels: governance, priority-high
assignees: dinesh-git17
---

## Violated Rule

<!-- Cite the exact section and rule from CLAUDE.md or Design-Doc.md. -->

- **Document:** CLAUDE.md / Design-Doc.md
- **Section:** `§`
- **Rule:** <!-- Paste or summarize the specific rule text. -->

## Violation Category

- [ ] **PZ — Protocol Zero** (AI attribution artifact in codebase) — CLAUDE.md §1
- [ ] **ARCH — Architecture** (prohibited pattern, boundary violation, unauthorized singleton) — CLAUDE.md §3
- [ ] **ENG — Engineering Standards** (force unwrap, deprecated API, magic number, Combine usage) — CLAUDE.md §4
- [ ] **SEC — Security** (plaintext secret, webhook URL exposure, .env file) — CLAUDE.md §5
- [ ] **AGENT — Agent Discipline** (silent refactor, speculative feature, unauthorized file) — CLAUDE.md §6
- [ ] **TEST — Testing** (missing coverage, real network call, sleep-based sync) — CLAUDE.md §7
- [ ] **STRUCT — Project Structure** (wrong directory, multi-type file, cross-chapter import) — CLAUDE.md §8
- [ ] **WF — Workflow** (non-conventional commit, audit bypass) — CLAUDE.md §9
- [ ] **SKILL — Skill Infrastructure** (manual skill creation, missing validation) — CLAUDE.md §11
- [ ] **ACS — Agent Context System** (missing update, stale manifest) — CLAUDE.md §12

## Location

<!-- Exact file path(s) and line number(s) where the violation exists. -->

- **File(s):**
- **Line(s):**
- **Commit SHA (if known):**

## Evidence

<!-- Paste the violating code, commit message, or artifact. -->

```
<!-- paste here -->
```

## Impact Assessment

<!-- How does this violation affect system integrity? -->

- **Severity:** Critical / High / Medium / Low
- **Blast radius:** Single file / Single component / Cross-component / Repository-wide
- **User-facing impact:** None / Degraded experience / Broken functionality / Security exposure
- **Blocks release:** Yes / No

## Suggested Correction

<!-- Describe the specific fix. Reference the correct pattern from governance docs. -->

## Pre-Commit Auditor Status

<!-- Did `scripts/audit.py` catch this? If not, the auditor may need a rule update. -->

- [ ] Caught by `audit.py` — violation was committed despite warning
- [ ] Not caught by `audit.py` — auditor rule gap (file issue against PH-01 auditor scope)
- [ ] Not applicable (violation is in non-code artifact)

## Related Check IDs

<!-- Reference applicable pre-commit check IDs from CLAUDE.md §9. -->

| Check ID | Rule | Applicable |
|----------|------|-----------|
| PZ-001 | No AI attribution | Yes / No |
| FU-001 | No force unwraps | Yes / No |
| DA-001 | No debug artifacts | Yes / No |
| DP-001 | No deprecated APIs | Yes / No |
| SL-001 | No plaintext secrets | Yes / No |
| CC-001 | Conventional Commits | Yes / No |
| CB-001 | No Combine | Yes / No |
