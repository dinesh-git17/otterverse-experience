---
name: Feature Request
about: Propose a new capability or enhancement for Starlight Sync
title: "feat(<scope>): "
labels: enhancement
assignees: dinesh-git17
---

## Problem Statement

<!-- What user-facing or developer-facing problem does this solve? -->
<!-- Reference Design-Doc.md §2.2 (Non-Goals) to confirm this is in scope. -->

## Proposed Solution

<!-- Concrete description of the feature. Include interaction model, visual behavior, and system effects. -->

## Design Doc Alignment

<!-- How does this relate to the existing architecture? -->

- **Existing section:** `Design-Doc.md §` or **New capability (requires design doc amendment)**
- **Chapter(s) affected:** Ch. 1 / Ch. 2 / Ch. 3 / Ch. 4 / Ch. 5 / Ch. 6 / Global
- **Component(s) affected:** FlowCoordinator / AudioManager / HapticManager / WebhookService / New component

## Architectural Impact

<!-- Evaluate against CLAUDE.md §3 (Architecture) and §3.1 (Prohibitions). -->

- **New files required:** List with directory placement per CLAUDE.md §8
- **Component boundary changes:** None / Describe additions to §3.3 matrix
- **Singleton additions:** None / Requires design doc amendment per CLAUDE.md §3
- **Persistence schema changes:** None / Requires approval per CLAUDE.md §6
- **Third-party dependencies:** None (prohibited per CLAUDE.md §3.1)

## Governance Checkpoints

- [ ] Does not violate Design-Doc.md chapter integrity (§3.2 — 6-chapter structure is immutable)
- [ ] Does not modify Auto-Assist thresholds without design doc amendment
- [ ] Does not modify webhook payload format without design doc amendment
- [ ] Does not introduce prohibited patterns (Combine, GCD, UIKit, Core Data)
- [ ] Does not require new `UserDefaults` keys without approval

## Alternative Approaches

<!-- List at least one alternative considered and why the proposed solution is preferred. -->

| Approach | Trade-offs | Why rejected / selected |
|----------|-----------|------------------------|
| | | |
| | | |

## Acceptance Criteria

<!-- Measurable conditions that define "done" for this feature. -->

- [ ]
- [ ]
- [ ]

## Test Plan

<!-- How will this be validated? Reference CLAUDE.md §7 for test requirements. -->

- **Unit tests:**
- **On-device validation:**
