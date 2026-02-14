---
name: epic-writer
description: Produce FAANG-grade execution-ready epics with deterministic structure. Use when creating epics, planning project phases, decomposing initiatives into stories, or structuring technical work for engineering execution. Triggers on requests for epic creation, backlog structuring, story decomposition, or phase planning.
---

# Epic Writer

Produce execution-ready epics that meet Staff TPM standards. Every epic follows a deterministic structure enforcing problem clarity, scope boundaries, dependency mapping, story decomposition, and measurable completion criteria.

## Workflow

### Step 1: Gather Epic Inputs

Collect before writing:

- **Problem**: What specific pain exists? Describe from the user or system perspective.
- **Scope**: What is in? What is explicitly out (non-goals)?
- **Phase**: Which project phase does this epic belong to?
- **Dependencies**: What must exist before this work starts? What does this work unblock?

If any input is ambiguous, stop and clarify. Do not infer scope.

### Step 2: Assign Epic Identity

Generate deterministic identifiers:

- **Epic ID**: `<DOMAIN>_<SEQ>` (e.g., `INFRA_01`, `UI_03`, `AUDIO_02`)
- **Domain**: Uppercase. Maps to the primary engineering domain.
- **Sequence**: Two-digit, zero-padded, monotonically increasing within the phase.
- **Epic Name**: `snake_case`, concise, action-oriented (e.g., `bootstrap_repo`, `implement_cipher_wheel`).

### Step 3: Write the Epic

Use the strict template from [assets/epic-template.md](assets/epic-template.md). Every field is mandatory. No field may be left blank or contain placeholder text.

**Required sections in order:**

1. Metadata block (ID, name, phase, domain, owner, status)
2. Problem Statement
3. Goals
4. Non-Goals
5. Technical Approach
6. Dependencies (inbound and outbound)
7. Stories (decomposed, each with acceptance criteria)
8. Risks
9. Definition of Done
10. Exit Criteria

### Step 4: Decompose Stories

Each epic MUST contain 4-15 stories. Each story MUST:

- Start with an **action verb** (Add, Implement, Configure, Create, Validate, Wire, Extract)
- Include **acceptance criteria** (Given/When/Then or checklist format)
- Declare **dependencies** on other stories within or outside the epic
- Define a **completion signal** (what artifact or behavior proves the story is done)

Apply vertical slicing. Every story delivers an observable increment. No horizontal-layer stories (e.g., "set up database" without any consuming feature).

**Story decomposition patterns** — reference [references/story-patterns.md](references/story-patterns.md) for splitting strategies.

### Step 5: Define Completion

**Definition of Done** applies universally to all stories in the epic:

- All stories completed and verified
- Tests passing (unit + integration where applicable)
- Documentation updated for affected interfaces
- Integration verified against dependent systems
- No regressions introduced

**Exit Criteria** are epic-specific governance gates:

- All DoD conditions met
- Stakeholder demo or review completed
- Residual work captured as new stories in subsequent epics
- Metrics baseline established (where applicable)

### Step 6: Save the Epic

Write the epic file to the deterministic path:

```
docs/<phase_directory>/<epic_id>_<epic_name>.md
```

**Rules:**

- Phase directory MUST already exist. If it does not, create it.
- File name: `<EPIC_ID>_<epic_name>.md` (e.g., `INFRA_01_bootstrap_repo.md`)
- Epic ID in the file name MUST match the metadata block inside the file.
- One epic per file. No multi-epic documents.

**Examples:**

```
docs/PH0-01/INFRA_01_bootstrap_repo.md
docs/PH1-02/UI_03_implement_cipher_wheel.md
docs/PH2-03/AUDIO_02_integrate_beat_map.md
```

### Step 7: Validate

After writing, verify:

- [ ] Every field in the template is populated (no TODOs, no placeholders)
- [ ] Epic ID is unique across all existing epics in `docs/`
- [ ] File name matches epic metadata
- [ ] All stories have acceptance criteria
- [ ] Dependencies reference real epic or story IDs
- [ ] Definition of Done is concrete, not aspirational
- [ ] Exit Criteria are verifiable by a third party

## Naming Standards

| Element         | Convention       | Example                         |
| --------------- | ---------------- | ------------------------------- |
| Epic ID         | `DOMAIN_SEQ`     | `INFRA_01`, `UI_03`             |
| Epic name       | `snake_case`     | `bootstrap_repo`                |
| Phase directory | Hyphenated       | `PH0-01`, `PH1-02`              |
| File name       | `<ID>_<name>.md` | `INFRA_01_bootstrap_repo.md`    |
| Story prefix    | Action verb      | "Add", "Implement", "Configure" |

## Anti-Patterns (Reject These)

- **Unbounded epic**: No measurable outcome. Scope grows indefinitely.
- **Vague stories**: "Improve performance" without target metric.
- **Missing non-goals**: Scope creep becomes inevitable.
- **Horizontal slicing**: "Set up database layer" without a consuming vertical feature.
- **Placeholder acceptance criteria**: "Works correctly" is not testable.
- **Orphan dependencies**: Referencing epic or story IDs that do not exist.

## Resources

- **Template**: See [assets/epic-template.md](assets/epic-template.md) for the strict output format
- **Story Patterns**: See [references/story-patterns.md](references/story-patterns.md) for decomposition strategies
