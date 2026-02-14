# Epic: {EPIC_ID} — {Epic Title}

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | {EPIC_ID}                      |
| **Epic Name** | {epic_name}                    |
| **Phase**     | {Phase Directory}              |
| **Domain**    | {DOMAIN}                       |
| **Owner**     | {Owner Name}                   |
| **Status**    | Draft / In Progress / Complete |

---

## Problem Statement

{One to three paragraphs describing the specific problem from the user or system perspective. What fails, degrades, or is missing today? What is the cost of inaction?}

---

## Goals

- {Measurable outcome this epic achieves}
- {Second goal if applicable}
- {Third goal if applicable}

## Non-Goals

- {Reasonable capability deliberately excluded from this epic and why}
- {Second non-goal}

---

## Technical Approach

{Two to five paragraphs summarizing the implementation strategy. Reference specific patterns, frameworks, components, or architectural decisions. Identify key trade-offs and justify the chosen approach over alternatives.}

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency             | Source                       | Status                  | Owner  |
| ---------------------- | ---------------------------- | ----------------------- | ------ |
| {What this epic needs} | {Epic ID or external system} | Committed / Uncommitted | {Name} |

### Outbound (This Epic Unblocks)

| Dependency                | Target                         | Description       |
| ------------------------- | ------------------------------ | ----------------- |
| {What this epic produces} | {Epic ID or downstream system} | {How it unblocks} |

---

## Stories

### Story 1: {Action Verb} {concise description}

**Acceptance Criteria:**

- [ ] {Given/When/Then or concrete checklist item}
- [ ] {Second criterion}
- [ ] {Third criterion}

**Dependencies:** {Story IDs or "None"}
**Completion Signal:** {Observable artifact or verifiable behavior}

---

### Story 2: {Action Verb} {concise description}

**Acceptance Criteria:**

- [ ] {Criterion}
- [ ] {Criterion}

**Dependencies:** {Story IDs or "None"}
**Completion Signal:** {Observable artifact or verifiable behavior}

---

### Story N: {Action Verb} {concise description}

**Acceptance Criteria:**

- [ ] {Criterion}
- [ ] {Criterion}

**Dependencies:** {Story IDs or "None"}
**Completion Signal:** {Observable artifact or verifiable behavior}

---

## Risks

| Risk               | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner  |
| ------------------ | :----------: | :--------------: | :---: | ---------- | ------ |
| {Risk description} |     {N}      |       {N}        | {N×N} | {Strategy} | {Name} |
| {Risk description} |     {N}      |       {N}        | {N×N} | {Strategy} | {Name} |

---

## Definition of Done

- [ ] All stories completed and individually verified
- [ ] Unit tests passing with zero failures
- [ ] Integration tests passing where applicable
- [ ] Documentation updated for all affected public interfaces
- [ ] No regressions introduced in existing functionality
- [ ] Code reviewed and merged to target branch
- [ ] {Epic-specific DoD item if needed}

## Exit Criteria

- [ ] All Definition of Done conditions satisfied
- [ ] Stakeholder review or demo completed
- [ ] Residual or deferred work captured as stories in subsequent epics
- [ ] {Epic-specific governance gate}
