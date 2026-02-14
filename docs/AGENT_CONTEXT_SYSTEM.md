# Agent Context System — Persistent Memory Architecture

**Document ID:** ACS-001
**Authority:** CLAUDE.md §13 (governance integration)
**Enforcement Level:** BLOCKING
**Scope:** All Claude Code instances operating in this repository

---

## 1. Memory Architecture

### 1.1 Design Principles

The Agent Context System (ACS) provides a durable, Git-versioned memory layer that persists across sessions and coordinates multiple Claude Code instances. The design draws from three validated production patterns:

- **Memory Bank methodology** (Cline/Roo Code): Multiple focused Markdown files with specific responsibilities rather than monolithic instruction files.
- **State-based memory** over retrieval-based: Authoritative fields with clear precedence that support belief updates, not fact accumulation.
- **ADR-adapted decision records**: Machine-parseable YAML frontmatter with enforcement levels and scope tags.

All memory is human-auditable Markdown committed alongside source code. YAML frontmatter provides machine-readable metadata. JSON is reserved for structured tool I/O only.

### 1.2 Directory Structure

```txt
.claude/context/
├── MANIFEST.md                  # Entry point — current project state snapshot
├── decisions/                   # Architecture Decision Records
│   └── ADR-000_template.md      # Canonical ADR template
├── progress/
│   ├── completed.md             # Completed work log (append-only)
│   └── active.md                # Current work in progress (state-based)
├── registry/
│   ├── skills.md                # Installed skills inventory
│   ├── components.md            # Implemented components registry
│   └── constraints.md           # Known constraints and prohibitions
└── sessions/
    └── .gitkeep                 # Session handoff notes (ephemeral, per-session)
```

### 1.3 File Responsibilities

| File | Type | Purpose | Update Frequency |
|------|------|---------|-----------------|
| `MANIFEST.md` | State-based | Project state snapshot: current phase, blocking issues, key metrics | After every significant state change |
| `decisions/ADR-NNN_*.md` | Append-only | Immutable records of architectural decisions with enforcement levels | On each architecture decision |
| `progress/completed.md` | Append-only | Chronological log of completed features, phases, and milestones | After each feature or phase completion |
| `progress/active.md` | State-based | Current work focus, in-progress items, blockers, next steps | At session start and end |
| `registry/skills.md` | State-based | Inventory of installed skills with paths and versions | After skill installation or modification |
| `registry/components.md` | State-based | Registry of implemented Swift types and their status | After component implementation |
| `registry/constraints.md` | State-based | Discovered constraints, gotchas, and environment-specific issues | When constraints are discovered |
| `sessions/*.md` | Ephemeral | Session-specific handoff notes for multi-instance coordination | During active sessions |

### 1.4 Machine-Readable vs Human-Readable Layers

Every file uses dual-layer encoding:

**Layer 1 — YAML frontmatter** (machine-readable):

```yaml
---
last_updated: 2026-02-14T10:30:00Z
updated_by: claude-opus-4-6
schema_version: 1
---
```

**Layer 2 — Markdown body** (human-readable):

Standard Markdown with headers, tables, and checklists. Optimized for both human review and LLM consumption. Terse, declarative, no narrative filler.

---

## 2. Context Data Model

### 2.1 MANIFEST.md Schema

The manifest is the single entry point for any agent beginning a session. It provides a compressed snapshot of project state.

```yaml
---
last_updated: ISO-8601
updated_by: model-id
schema_version: 1
---
```

**Required sections:**

```markdown
# Project Manifest

## Current Phase
Phase ID, name, and completion percentage.

## Blocking Issues
Enumerated list of blockers preventing forward progress.

## Recently Completed
Last 5 completed items with dates.

## Active Decisions
References to ADRs that constrain current work.

## Component Status
Summary table: component name, file path, status (not started | in progress | complete | tested).

## Coordination Notes
Messages for other agent instances (e.g., "Chapter 3 cipher validation in progress on branch feat/ch3-cipher").
```

### 2.2 Architecture Decision Record Schema

Each ADR uses the following template:

```yaml
---
id: ADR-NNN
status: accepted | proposed | deprecated | superseded
enforcement: blocking | advisory
scope: [component-tags]
date: ISO-8601
supersedes: null | ADR-NNN
---
```

**Required sections:**

```markdown
# ADR-NNN: Decision Title

## Context
Why this decision was needed.

## Decision
What was decided.

## Agent Directives
- MUST: mandatory actions
- MUST NOT: prohibited actions
- IF: conditional guidance

## Consequences
What follows from this decision.
```

### 2.3 Completed Work Log Schema

```yaml
---
last_updated: ISO-8601
total_entries: integer
---
```

**Entry format (append-only):**

```markdown
### YYYY-MM-DD — Summary
- **Phase:** PH-XX
- **Scope:** component or chapter identifier
- **Commit:** conventional commit reference
- **Files:** list of primary files created or modified
- **Verification:** how completion was verified (build, test, manual)
```

### 2.4 Active Work Schema

```yaml
---
last_updated: ISO-8601
updated_by: model-id
session_id: string
---
```

**Required sections:**

```markdown
# Active Work

## In Progress
Bulleted list of items currently being worked on, with branch names.

## Blockers
Items preventing forward progress.

## Next Steps
Ordered list of immediate next actions.

## Session Notes
Terse observations from current session relevant to future agents.
```

### 2.5 Component Registry Schema

```yaml
---
last_updated: ISO-8601
schema_version: 1
---
```

**Table format:**

```markdown
| Component | File Path | Status | Phase | Tests | Notes |
|-----------|-----------|--------|-------|-------|-------|
| FlowCoordinator | Coordinators/FlowCoordinator.swift | complete | PH-02 | yes | — |
```

Status values: `not_started` | `in_progress` | `complete` | `tested`

### 2.6 Skills Registry Schema

```yaml
---
last_updated: ISO-8601
total_skills: integer
---
```

**Table format:**

```markdown
| Skill | Path | Key Assets | CLAUDE.md Ref |
|-------|------|------------|---------------|
| skill-name | .claude/skills/skill-name/ | asset list | §X.Y |
```

### 2.7 Constraints Registry Schema

```yaml
---
last_updated: ISO-8601
---
```

**Entry format:**

```markdown
- **[CATEGORY]** Constraint description. Discovered during [context]. Reference: [CLAUDE.md §X | Design-Doc.md §Y | empirical].
```

Categories: `BUILD`, `RUNTIME`, `API`, `TOOLING`, `ENVIRONMENT`, `FRAMEWORK`.

---

## 3. Update Protocol

### 3.1 Mandatory Update Triggers

Updates to ACS files are REQUIRED (not optional) at the following events:

| Event | Files Updated | Rule |
|-------|--------------|------|
| Feature implementation complete | `progress/completed.md`, `registry/components.md`, `progress/active.md`, `MANIFEST.md` | Append completion entry. Update component status. Remove from active. Refresh manifest. |
| Architecture decision made | `decisions/ADR-NNN_*.md`, `MANIFEST.md` | Create new ADR file. Add reference to manifest. |
| Skill installed or modified | `registry/skills.md` | Update skill table entry. |
| Phase milestone reached | `progress/completed.md`, `MANIFEST.md` | Record milestone. Update current phase in manifest. |
| Constraint discovered | `registry/constraints.md` | Append constraint with category and reference. |
| Session start | `progress/active.md` | Read and verify. Update `session_id` and `updated_by`. |
| Session end | `progress/active.md`, `MANIFEST.md` | Record session notes. Refresh manifest state. |
| Design document amended | `decisions/ADR-NNN_*.md` | Create ADR documenting the amendment. |
| Blocker identified or resolved | `progress/active.md`, `MANIFEST.md` | Update blockers list in both files. |

### 3.2 Update Ordering

When multiple files require updates from a single event, update in this order:

1. `progress/completed.md` (append-only, lowest conflict risk)
2. `registry/components.md` or `registry/skills.md` (state update)
3. `registry/constraints.md` (if applicable)
4. `progress/active.md` (state update)
5. `MANIFEST.md` (last, reflects all other changes)

This ordering ensures the manifest always reflects the latest state of all other files.

### 3.3 Deterministic Update Rules

Agents MUST NOT skip ACS updates. The following rules are enforced:

- **No orphaned completions:** If a feature is reported as complete to `FlowCoordinator` or the user, a `progress/completed.md` entry MUST exist.
- **No phantom components:** If a Swift file is created under `StarlightSync/`, a `registry/components.md` entry MUST exist.
- **No silent decisions:** If a design choice deviates from `Design-Doc.md` or establishes a new pattern, an ADR MUST be created.
- **No stale manifests:** `MANIFEST.md` MUST be updated as the final step of any session that modifies project state.

### 3.4 Commit Integration

ACS file updates SHOULD be committed alongside the code changes they document. Use the conventional commit format:

```
docs(context): update manifest after ch2 implementation
docs(context): add ADR-003 for physics collision strategy
docs(context): record PH-07 completion
```

If ACS updates are committed separately (e.g., session-end cleanup), use:

```
docs(context): sync context state after session
```

---

## 4. Multi-Instance Coordination Rules

### 4.1 Memory Detection

At the start of every session, agents MUST:

1. Check for the existence of `.claude/context/MANIFEST.md`.
2. If it exists, read `MANIFEST.md` in full.
3. Read `progress/active.md` to determine current work state.
4. Check `sessions/` for any handoff notes from prior instances.
5. Proceed with full awareness of recorded state.

If `.claude/context/` does not exist, the agent MUST scaffold it before performing any implementation work.

### 4.2 State Sovereignty

Each ACS file has a defined ownership model:

| File | Ownership | Conflict Resolution |
|------|-----------|-------------------|
| `MANIFEST.md` | Last writer wins | Regenerate from source files if conflict detected |
| `progress/completed.md` | Append-only | Git merge handles naturally; no overwrites |
| `progress/active.md` | Current session owns | Overwrite is expected; previous state preserved in git history |
| `decisions/ADR-*.md` | Immutable after creation | Never modify accepted ADRs; create superseding ADR instead |
| `registry/*.md` | Last writer wins | Merge conflicts resolved by re-scanning source files |
| `sessions/*.md` | Per-instance | Each instance writes its own file; never modify another's |

### 4.3 Append Safety

For append-only files (`progress/completed.md`), agents MUST:

- Append new entries at the end of the file, before the closing `---` separator if present.
- Never reorder, edit, or delete existing entries.
- Use ISO-8601 timestamps to establish ordering.

For state-based files (`MANIFEST.md`, `progress/active.md`, `registry/*.md`), agents MUST:

- Read the current file before writing.
- Update the `last_updated` and `updated_by` frontmatter fields.
- Preserve any section they did not modify.

### 4.4 Session Handoff

When an agent session ends with work remaining, the agent MUST:

1. Write a session handoff note to `sessions/handoff_YYYYMMDD_HHMMSS.md`:

```yaml
---
agent: model-id
session_end: ISO-8601
branch: current-git-branch
---
```

```markdown
# Session Handoff

## Completed This Session
- Items completed

## In Progress (Unfinished)
- Items started but not completed, with current state

## Warnings
- Anything the next agent should know

## Recommended Next Actions
- Ordered list of what to do next
```

1. Update `progress/active.md` with session notes.
2. Update `MANIFEST.md` coordination notes.

### 4.5 Conflict Prevention

Multiple instances MUST NOT work on the same file simultaneously. Coordination is achieved through:

- **Branch isolation:** Each agent works on a separate git branch. Branch names recorded in `progress/active.md`.
- **Scope declaration:** Before starting work, agents record their scope in `MANIFEST.md` coordination notes (e.g., "Agent working on Chapter 3 cipher validation on branch feat/ch3-cipher").
- **Manifest polling:** Before claiming a scope, agents read `MANIFEST.md` to verify no other agent has claimed it.

---

## 5. Retrieval Strategy

### 5.1 Session Initialization Protocol

At the start of every session, agents MUST load context in this order:

1. `CLAUDE.md` (loaded automatically by Claude Code)
2. `Design-Doc.md` (reference, loaded on demand)
3. `.claude/context/MANIFEST.md` (project state snapshot)
4. `.claude/context/progress/active.md` (current work state)
5. `.claude/context/sessions/*.md` (recent handoff notes, if any)

Additional files are loaded on demand based on task requirements:

- Working on a chapter → read `registry/components.md` for status
- Making an architectural choice → read `decisions/` for existing ADRs
- Debugging → read `registry/constraints.md` for known issues
- Installing a skill → read `registry/skills.md` for current inventory

### 5.2 Retrieval Rules

- **Prefer memory over assumptions.** If a question is answered by an ACS file, use that answer. Do not speculate about project state when recorded state exists.
- **Never hallucinate missing knowledge.** If an ACS file does not contain information about a topic, state that explicitly rather than fabricating a plausible answer.
- **Trust append-only files.** Entries in `progress/completed.md` represent verified completions. Do not re-implement completed work without explicit instruction.
- **Respect ADR enforcement levels.** `blocking` ADRs are mandatory constraints. `advisory` ADRs are recommendations. `deprecated` ADRs should be noted but not followed.
- **Check constraints before implementation.** Read `registry/constraints.md` before starting work in an area where constraints may apply.

### 5.3 Context Depth Levels

Agents should load context at the appropriate depth:

| Depth | What is Loaded | When to Use |
|-------|---------------|-------------|
| **Shallow** | `MANIFEST.md` only | Quick status check, answering questions about project state |
| **Standard** | `MANIFEST.md` + `progress/active.md` + relevant registry file | Most implementation tasks |
| **Deep** | All ACS files + relevant ADRs + `PHASES.md` | Architectural decisions, phase transitions, cross-cutting changes |
| **Full** | All ACS files + `Design-Doc.md` + `CLAUDE.md` | Design amendments, governance changes, system-level debugging |

---

## 6. Governance Integration

### 6.1 Authority Hierarchy Update

The ACS integrates into the existing governance hierarchy (CLAUDE.md §2):

1. `CLAUDE.md` — supreme authority (unchanged)
2. `Design-Doc.md` — architecture alignment (unchanged)
3. `.claude/context/decisions/ADR-*.md` — implementation-level decisions (new)
4. `.claude/context/MANIFEST.md` — current state of truth (new)
5. Apple HIG and API documentation — framework usage (unchanged)

ADRs MUST NOT contradict `CLAUDE.md` or `Design-Doc.md`. If a contradiction is discovered, the ADR is invalid and must be superseded.

### 6.2 Enforcement Rules

The following rules are BLOCKING for all agents:

- **ACS-001:** Agents MUST read `MANIFEST.md` before starting implementation work.
- **ACS-002:** Agents MUST update ACS files according to the mandatory update triggers (§3.1).
- **ACS-003:** Agents MUST NOT re-implement work recorded as complete in `progress/completed.md` without explicit user instruction.
- **ACS-004:** Agents MUST create an ADR for any architectural decision not already covered by `CLAUDE.md` or `Design-Doc.md`.
- **ACS-005:** Agents MUST record discovered constraints in `registry/constraints.md`.
- **ACS-006:** Agents MUST NOT modify accepted ADRs. Create superseding ADRs instead.
- **ACS-007:** Agents MUST update `MANIFEST.md` as the final action of any session that modifies project state.
- **ACS-008:** Agents MUST write a session handoff note when ending a session with unfinished work.

### 6.3 CLAUDE.md Integration

`CLAUDE.md` §13 mandates this system. The following instruction is added:

> All agents MUST read `.claude/context/MANIFEST.md` at session start and update ACS files per `docs/AGENT_CONTEXT_SYSTEM.md` §3.1. ACS update omission is a governance violation.

### 6.4 Pre-Commit Auditor Integration

The Pre-Commit Auditor (`scripts/audit.py`) SHOULD be extended to verify:

- **ACS-SYNC:** If `.swift` files are staged, at least one `.claude/context/` file should also be staged (warning, not blocking).
- **ACS-ADR:** New ADR files must contain valid YAML frontmatter with required fields.

These checks are advisory (non-blocking) to avoid impeding rapid iteration, but agents SHOULD treat them as mandatory.

---

## 7. File Format Reference

### 7.1 YAML Frontmatter Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `last_updated` | ISO-8601 string | Yes | Timestamp of last modification |
| `updated_by` | string | Yes | Model identifier of updating agent |
| `schema_version` | integer | Yes | Schema version for forward compatibility |
| `session_id` | string | No | Session identifier for traceability |
| `id` | string | ADRs only | Unique ADR identifier (ADR-NNN format) |
| `status` | enum | ADRs only | `accepted`, `proposed`, `deprecated`, `superseded` |
| `enforcement` | enum | ADRs only | `blocking`, `advisory` |
| `scope` | string[] | ADRs only | Component or chapter tags affected |
| `date` | ISO-8601 date | ADRs only | Decision date |
| `supersedes` | string | ADRs only | ID of superseded ADR, or `null` |

### 7.2 Naming Conventions

| File Type | Pattern | Example |
|-----------|---------|---------|
| ADR | `ADR-NNN_snake_case_title.md` | `ADR-001_use_observable_over_combine.md` |
| Session handoff | `handoff_YYYYMMDD_HHMMSS.md` | `handoff_20260214_103000.md` |
| All other files | Predefined names per §1.2 | `MANIFEST.md`, `completed.md` |

ADR numbering is sequential, zero-padded to 3 digits, starting at `001`. `ADR-000` is reserved for the template.
