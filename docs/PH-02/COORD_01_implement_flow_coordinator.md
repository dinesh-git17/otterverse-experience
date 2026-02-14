# Epic: COORD_01 — Implement FlowCoordinator State Machine

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | COORD_01                       |
| **Epic Name** | implement_flow_coordinator     |
| **Phase**     | PH-02                          |
| **Domain**    | COORD                          |
| **Owner**     | iOS Architect                  |
| **Status**    | Complete                       |

---

## Problem Statement

PH-01 delivered a buildable Xcode project shell with directory structure, asset catalog skeletons, and version control hardening. The app launches to a static placeholder `ContentView` with no concept of chapters, progression, persistence, or navigation. Every downstream phase (PH-03 through PH-17) depends on a functional state machine to coordinate chapter transitions, persist progress, and serve as the integration point for managers, views, and services. Without `FlowCoordinator`, no chapter code can report completion, no progress can be saved, and no view routing can occur. The entire 6-chapter narrative arc is unnavigable.

The Design-Doc (S4.1-S4.3) specifies a Flow Coordinator pattern managing a strictly linear 6-chapter state machine with `UserDefaults`-backed checkpoint persistence. This epic delivers that state machine as the foundational coordination layer for the walking skeleton.

---

## Goals

- Deliver `FlowCoordinator` as a production-ready `@Observable` `@MainActor` class at `Coordinators/FlowCoordinator.swift`.
- Define a type-safe `Chapter` enum with 6 cases matching Design-Doc S3 chapter definitions, backed by `Int` raw values for `UserDefaults` compatibility.
- Implement strictly linear chapter progression (Chapter 1 through 6) with no backward navigation and a terminal state after Chapter 6.
- Implement `UserDefaults` checkpoint persistence with injectable `UserDefaults` for testability.
- Implement resume-from-checkpoint on initialization, handling first-launch and corrupted-value edge cases.

## Non-Goals

- **No chapter view implementations.** Placeholder views are COORD_02 scope. This epic delivers the state machine only.
- **No view routing or UI integration.** `StarlightSyncApp.swift` wiring is COORD_02 scope.
- **No GameConstants or tuning values.** Type-safe constants for thresholds, timing, and asset identifiers are PH-06 scope. The `UserDefaults` key is defined locally as a private constant.
- **No AudioManager or HapticManager integration.** Manager singletons are PH-03 and PH-04 scope. FlowCoordinator exposes no audio or haptic API in this epic.
- **No Auto-Assist logic.** Auto-Assist is chapter-specific and implemented in PH-07 through PH-11.
- **No unit tests.** Formal test suite is PH-15 scope. Injectable `UserDefaults` prepares the class for testability.
- **No interruption handling.** `AVAudioSession` interruption-driven game state pause is PH-03 scope; FlowCoordinator will expose a pause API when that integration occurs.

---

## Technical Approach

`FlowCoordinator` is implemented as a `final class` annotated with `@Observable` (Swift 5.9+ Observation framework) and `@MainActor` isolation, conforming to CLAUDE.md S4.1 and S4.2. No `ObservableObject`, `@Published`, `@StateObject`, or Combine usage. SwiftUI views observe `FlowCoordinator` property changes automatically through the `@Observable` macro's synthesized tracking.

The `Chapter` enum is defined as a nested type within `FlowCoordinator`, backed by `Int` raw values (0 through 5) and conforming to `CaseIterable`. The 0-indexed raw values provide direct compatibility with the `UserDefaults` integer storage specified in Design-Doc S4.3 (`highestUnlockedChapter: Int`, default `0`). Case names follow CLAUDE.md S4.6 lowerCamelCase convention: `handshake`, `packetRun`, `cipher`, `firewall`, `blueprint`, `eventHorizon`.

State transitions are forward-only. The sole mutation method `completeCurrentChapter()` advances `currentChapter` to the next enum case via raw value arithmetic. No backward navigation method exists on the public API. The final chapter (`.eventHorizon`, rawValue 5) is a terminal state; calling `completeCurrentChapter()` on it is a safe no-op. This enforces Design-Doc S3.1: "strictly linear, no backward navigation or chapter selection."

`UserDefaults` persistence uses the key `"highestUnlockedChapter"` defined as a private static constant (not a raw string literal at call sites), satisfying CLAUDE.md S4.7's prohibition on stringly-typed APIs. The `UserDefaults` instance is injected via an initializer parameter (defaulting to `.standard`) to enable test-scoped suites per CLAUDE.md S7.3. On `completeCurrentChapter()`, the new chapter's raw value is written immediately.

On initialization, `FlowCoordinator` reads the persisted value and maps it to a `Chapter` case. Edge cases are handled defensively: first launch (key absent, `integer(forKey:)` returns 0, correctly mapping to `.handshake`), value exceeding valid range (clamped to `.eventHorizon`), negative value (clamped to `.handshake`). The user resumes at the **start** of the highest unlocked chapter, per Design-Doc S4.3.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency                          | Source   | Status    | Owner        |
| ----------------------------------- | -------- | --------- | ------------ |
| Buildable Xcode project with `Coordinators/` directory | INFRA_01 | Complete  | iOS Engineer |
| Version control with pre-commit audit | INFRA_02 | Complete  | iOS Engineer |

### Outbound (This Epic Unblocks)

| Dependency                          | Target   | Description                                                  |
| ----------------------------------- | -------- | ------------------------------------------------------------ |
| FlowCoordinator class with Chapter enum | COORD_02 | Walking skeleton view routing requires FlowCoordinator to exist |
| Chapter enum for alignment          | PH-06    | GameConstants type-safe models reference the canonical chapter enum |
| FlowCoordinator for chapter completion reporting | PH-07 through PH-13 | All chapter implementations report completion to FlowCoordinator |
| FlowCoordinator for state transitions | PH-03   | AudioManager interruption handling pauses/resumes FlowCoordinator state |
| FlowCoordinator for persistence testing | PH-15  | Unit tests validate chapter progression and checkpoint logic |

---

## Stories

### Story 1: Define Chapter enum with 6 type-safe cases

**Acceptance Criteria:**

- [x] `Chapter` enum defined as a nested type within `FlowCoordinator` (or at file scope in `FlowCoordinator.swift`).
- [x] Six cases: `handshake`, `packetRun`, `cipher`, `firewall`, `blueprint`, `eventHorizon`.
- [x] Enum backed by `Int` raw values: `handshake = 0` through `eventHorizon = 5`.
- [x] Enum conforms to `CaseIterable` for enumeration and count access.
- [x] Case names follow CLAUDE.md S4.6 lowerCamelCase convention.
- [x] Cases match Design-Doc S3 chapter definitions exactly: no additions, no omissions, no reordering.

**Dependencies:** None
**Completion Signal:** `Chapter.allCases.count == 6`. `Chapter.handshake.rawValue == 0`. `Chapter.eventHorizon.rawValue == 5`. Enum compiles without errors.

---

### Story 2: Implement FlowCoordinator @Observable @MainActor class with chapter tracking

**Acceptance Criteria:**

- [x] `FlowCoordinator` declared as `@Observable @MainActor final class`.
- [x] `currentChapter` property of type `Chapter` tracks the active chapter.
- [x] `currentChapter` is publicly readable, privately settable (`private(set) var`).
- [x] No `ObservableObject` protocol conformance, no `@Published` properties, no Combine imports.
- [x] No `DispatchQueue`, `Timer`, or GCD usage.
- [x] File located at `StarlightSync/Coordinators/FlowCoordinator.swift`.
- [x] File contains exactly one primary type (`FlowCoordinator`). Nested `Chapter` enum is permitted.

**Dependencies:** COORD_01-S1
**Completion Signal:** `FlowCoordinator` compiles. A SwiftUI view referencing `coordinator.currentChapter` triggers view updates on state change via `@Observable` tracking.

---

### Story 3: Implement forward-only chapter progression

**Acceptance Criteria:**

- [x] Public method `completeCurrentChapter()` advances `currentChapter` to the next `Chapter` case by raw value increment.
- [x] No public method exists for backward navigation or arbitrary chapter selection.
- [x] Calling `completeCurrentChapter()` when `currentChapter == .eventHorizon` is a safe no-op (no crash, no state change).
- [x] Progression is strictly sequential: `handshake` -> `packetRun` -> `cipher` -> `firewall` -> `blueprint` -> `eventHorizon`. No chapter can be skipped.
- [x] `currentChapter` cannot be set to a previous value from outside the class.

**Dependencies:** COORD_01-S2
**Completion Signal:** Calling `completeCurrentChapter()` five times starting from `.handshake` results in `currentChapter == .eventHorizon`. A sixth call leaves `currentChapter` unchanged at `.eventHorizon`.

---

### Story 4: Implement UserDefaults checkpoint persistence

**Acceptance Criteria:**

- [x] `UserDefaults` key `"highestUnlockedChapter"` defined as a private static constant within `FlowCoordinator` (not a raw string literal at call sites).
- [x] `completeCurrentChapter()` writes the new chapter's `rawValue` to `UserDefaults` immediately after advancing `currentChapter`.
- [x] `UserDefaults` instance is accepted as an initializer parameter with default value `.standard`.
- [x] Injecting a custom `UserDefaults(suiteName:)` instance works correctly, enabling test isolation per CLAUDE.md S7.3.
- [x] No stringly-typed `UserDefaults` access at any call site in the file.

**Dependencies:** COORD_01-S3
**Completion Signal:** After calling `completeCurrentChapter()` on a `FlowCoordinator` initialized with a test-scoped `UserDefaults`, reading `defaults.integer(forKey: "highestUnlockedChapter")` returns the new chapter's raw value.

---

### Story 5: Implement resume-from-checkpoint on initialization

**Acceptance Criteria:**

- [x] `FlowCoordinator` initializer reads `"highestUnlockedChapter"` from the injected `UserDefaults` instance.
- [x] `currentChapter` is set to the `Chapter` case matching the persisted raw value.
- [x] First launch (key absent): `UserDefaults.integer(forKey:)` returns `0`, mapping to `.handshake`. Correct default behavior without explicit registration.
- [x] Corrupted value exceeding valid range (rawValue > 5): clamped to `.eventHorizon`.
- [x] Corrupted value below valid range (negative rawValue): clamped to `.handshake`.
- [x] No force unwraps on the `Chapter(rawValue:)` initializer. Failed mapping falls back to `.handshake`.

**Dependencies:** COORD_01-S4
**Completion Signal:** `FlowCoordinator(defaults: testDefaults)` where `testDefaults` contains `highestUnlockedChapter = 3` results in `currentChapter == .firewall`. `testDefaults` containing `highestUnlockedChapter = 99` results in `currentChapter == .eventHorizon`. Empty `testDefaults` results in `currentChapter == .handshake`.

---

### Story 6: Validate FlowCoordinator governance compliance and build

**Acceptance Criteria:**

- [x] Zero force unwraps (`!`) in `FlowCoordinator.swift`.
- [x] Zero `print` statements in `FlowCoordinator.swift`.
- [x] Zero deprecated API usage (`ObservableObject`, `@Published`, `@StateObject`, `DispatchQueue`, `Combine`).
- [x] Zero Combine imports.
- [x] Zero AI attribution artifacts (Protocol Zero compliance).
- [x] Zero magic numbers outside the enum raw value definitions.
- [x] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0.
- [x] `python3 scripts/audit.py --all` passes with zero violations.
- [x] `.gitkeep` file removed from `Coordinators/` directory (replaced by `FlowCoordinator.swift`).

**Dependencies:** COORD_01-S1 through COORD_01-S5
**Completion Signal:** Clean build with zero errors. Audit script passes. `FlowCoordinator.swift` is the sole file in `Coordinators/`.

---

## Risks

| Risk                                          | Impact (1-5) | Likelihood (1-5) | Score | Mitigation                                                                                          | Owner         |
| --------------------------------------------- | :----------: | :--------------: | :---: | --------------------------------------------------------------------------------------------------- | ------------- |
| @Observable macro unavailable in target SDK    |      5       |        1         |   5   | iOS 26 SDK (Swift 6.2) fully supports @Observable. Verified during PH-01 build validation.          | iOS Architect |
| UserDefaults.integer(forKey:) edge case on missing key |      2       |        1         |   2   | Returns 0 by default, which maps to `.handshake`. Defensive clamping handles all other cases.       | iOS Architect |
| @MainActor isolation blocks future async access |      3       |        2         |   6   | All downstream consumers (views, managers) also run on @MainActor. Cross-actor access uses `await`. | iOS Architect |
| Chapter enum case names drift from Design-Doc  |      3       |        1         |   3   | Case names derived directly from Design-Doc S3 section headers. No interpretation applied.          | iOS Architect |

---

## Definition of Done

- [x] All 6 stories completed and individually verified.
- [x] `FlowCoordinator` compiles as `@Observable @MainActor final class`.
- [x] `Chapter` enum has exactly 6 cases with correct raw values (0-5).
- [x] Forward-only progression works. No backward navigation API exists.
- [x] `UserDefaults` persistence writes on completion and reads on initialization.
- [x] Resume-from-checkpoint handles first-launch, valid, and corrupted value edge cases.
- [x] Zero force unwraps, zero print statements, zero deprecated APIs, zero Combine usage.
- [x] `xcodebuild build` succeeds with zero errors.
- [x] `scripts/audit.py --all` passes with zero violations.
- [x] No AI attribution artifacts (Protocol Zero).

## Exit Criteria

- [x] All Definition of Done conditions satisfied.
- [x] `FlowCoordinator.swift` exists at `StarlightSync/Coordinators/FlowCoordinator.swift` as the sole file in that directory.
- [x] COORD_02 (walking skeleton view routing) is unblocked and ready to execute.
- [x] Epic ID `COORD_01` recorded in `.claude/context/progress/completed.md` upon completion.
