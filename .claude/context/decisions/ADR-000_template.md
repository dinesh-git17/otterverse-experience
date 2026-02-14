---
id: ADR-000
status: accepted
enforcement: advisory
scope: [all]
date: 2026-02-14
supersedes: null
---

# ADR-000: Architecture Decision Record Template

## Context

This file serves as the canonical template for all ADRs in this repository. Copy this file and increment the sequence number when creating a new decision record.

## Decision

All architecture decisions that are not already captured in `CLAUDE.md` or `Design-Doc.md` MUST be recorded as ADR files in `.claude/context/decisions/`.

## Agent Directives

- MUST copy this template when creating a new ADR.
- MUST use sequential zero-padded numbering (ADR-001, ADR-002, ...).
- MUST fill all required YAML frontmatter fields.
- MUST include all five sections: Context, Decision, Agent Directives, Consequences, (and optionally References).
- MUST NOT modify accepted ADRs. Create a superseding ADR instead.

## Consequences

Standardized decision records enable deterministic retrieval by agents and prevent conflicting implementations across sessions.
