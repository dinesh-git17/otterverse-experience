---
name: Bug Report
about: Report a defect in Starlight Sync
title: "fix(<scope>): "
labels: bug
assignees: dinesh-git17
---

## Environment

- **Device:** iPhone 17 Pro / Simulator
- **iOS Version:**
- **Build:** TestFlight / Debug / Release
- **Chapter affected:** Ch. 1 / Ch. 2 / Ch. 3 / Ch. 4 / Ch. 5 / Ch. 6 / Global

## Description

<!-- Precise description of the defect. State what is broken, not what you expected. -->

## Reproduction Steps

1.
2.
3.

## Expected Behavior

<!-- What should happen according to Design-Doc.md. Cite the relevant section. -->

**Design Doc reference:** `Design-Doc.md §`

## Actual Behavior

<!-- What actually happens. Include timing, visual state, and error indicators. -->

## Frequency

- [ ] Always reproducible
- [ ] Intermittent (approximate rate: ___%)
- [ ] Occurred once

## Regression Risk

<!-- Does this bug indicate a broader system issue? -->

- **Component affected:** FlowCoordinator / AudioManager / HapticManager / WebhookService / Chapter View / SKScene
- **Cross-boundary impact:** None / Describe
- **Blocks chapter progression:** Yes / No
- **Data integrity risk:** None / UserDefaults corruption / Webhook misfire

## Severity

- [ ] **P0 — Crash / data loss / blocks experience completion**
- [ ] **P1 — Major feature broken, workaround exists**
- [ ] **P2 — Minor visual or interaction defect**
- [ ] **P3 — Cosmetic / polish issue**

## Logs / Screenshots / Recordings

<!-- Attach Xcode console output, crash logs, screenshots, or screen recordings. -->
<!-- Redact any webhook URLs or secrets before posting. -->

## Additional Context

<!-- Relevant prior state: was Auto-Assist active? Was app resumed from background? -->
<!-- Was Reduce Motion enabled? Was Silent Switch on? -->
