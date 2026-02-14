# Epic: COORD_02 — Wire Walking Skeleton View Routing

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | COORD_02                       |
| **Epic Name** | wire_walking_skeleton          |
| **Phase**     | PH-02                          |
| **Domain**    | COORD                          |
| **Owner**     | iOS Architect                  |
| **Status**    | Draft                          |

---

## Problem Statement

COORD_01 delivers a functional `FlowCoordinator` state machine with chapter progression and persistence, but it exists in isolation. No UI consumes it, no views render chapter content, and the app still launches to the PH-01 placeholder `ContentView`. The walking skeleton cannot be validated until placeholder chapter views exist and the app entry point routes to them based on `FlowCoordinator` state. Without this wiring, the state machine is untestable from a user-interaction perspective, persistence cannot be verified through relaunch cycles, and downstream phases (PH-07 through PH-13) have no integration target for their chapter implementations.

Design-Doc S4.1 specifies a View Factory pattern where `StarlightSyncApp` switches between SwiftUI Views and SpriteKit Scenes based on `FlowCoordinator` state. This epic delivers the view factory with placeholder views, completing the walking skeleton: a runnable app that transitions through empty chapter shells.

---

## Goals

- Deliver 6 placeholder chapter views in correct directories per CLAUDE.md S8, each with `#Preview` macro and chapter completion reporting.
- Wire `StarlightSyncApp.swift` to instantiate `FlowCoordinator`, inject it into the SwiftUI environment, and route to chapter views based on `currentChapter`.
- Enable end-to-end chapter navigation: tap through all 6 chapters via temporary completion actions.
- Validate `UserDefaults` persistence and resume-from-checkpoint behavior with a running app across relaunch cycles.
- Remove the PH-01 `ContentView.swift` scaffold as dead code.

## Non-Goals

- **No actual chapter mechanics, visuals, or interactions.** Placeholder views display chapter identity and a completion trigger only. Real chapter implementations are PH-07 through PH-13.
- **No SpriteView or SpriteKit integration.** Chapters 2 and 4 use plain SwiftUI placeholders. `SpriteView` wrapping is deferred to PH-08 and PH-10.
- **No transition animations.** Chapter-to-chapter transition animations and `matchedGeometryEffect` are PH-14 scope.
- **No audio or haptic feedback.** `AudioManager` and `HapticManager` integration is PH-03 and PH-04 scope.
- **No GameConstants references.** Tuning values and type-safe asset identifiers are PH-06 scope.
- **No CRT turn-on effect, confetti, or progressive slider.** Chapter-specific components are built in their respective chapter phases.
- **No chapter-specific visual identity.** Placeholder views use minimal styling; chapter-specific colors, materials, and animation curves are applied during chapter implementation.

---

## Technical Approach

Six placeholder SwiftUI views are created at the file paths prescribed by CLAUDE.md S8: `HandshakeView.swift` in `Chapters/Chapter1_Handshake/`, `PacketRunView.swift` in `Chapters/Chapter2_PacketRun/`, `CipherView.swift` in `Chapters/Chapter3_Cipher/`, `FirewallView.swift` in `Chapters/Chapter4_Firewall/`, `BlueprintView.swift` in `Chapters/Chapter5_Blueprint/`, and `EventHorizonView.swift` in `Chapters/Chapter6_EventHorizon/`. Each placeholder displays its chapter number and title, and provides a temporary completion action that calls `FlowCoordinator.completeCurrentChapter()`. These placeholders are intentionally minimal and will be replaced wholesale during chapter implementation phases.

Each placeholder view receives `FlowCoordinator` via `@Environment(FlowCoordinator.self)`, the modern `@Observable` environment injection pattern. This is distinct from `@EnvironmentObject` (which requires `ObservableObject` and is prohibited by CLAUDE.md S4.2). Every view includes a `#Preview` macro that supplies a fresh `FlowCoordinator` instance.

The app entry point (`StarlightSyncApp.swift`) is modified to instantiate `FlowCoordinator` as a `@State private var` property and inject it into the SwiftUI environment via `.environment(coordinator)`. A root content view uses an exhaustive `switch` on `coordinator.currentChapter` (no `default` case) to render the correct chapter view. This exhaustive match guarantees a compile-time error if a `Chapter` case is added without a corresponding view — a deliberate safety net for the immutable 6-chapter structure.

The existing `ContentView.swift` is deleted as dead code once routing is in place. All `.gitkeep` files in chapter directories that now contain Swift source files are also removed.

Chapters 2 and 4 are documented as future SpriteKit targets but receive plain SwiftUI placeholders in this epic. Their placeholder views do not import SpriteKit. The `PacketRunScene.swift`, `FirewallScene.swift`, and `SpriteView` wrapper patterns are deferred to PH-08 and PH-10. Only the view-layer files (`PacketRunView.swift`, `FirewallView.swift`) are created here.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency                                    | Source   | Status    | Owner         |
| --------------------------------------------- | -------- | --------- | ------------- |
| `FlowCoordinator` class with `Chapter` enum   | COORD_01 | Draft     | iOS Architect |
| Buildable Xcode project with chapter directories | INFRA_01 | Complete  | iOS Engineer  |

### Outbound (This Epic Unblocks)

| Dependency                                    | Target                | Description                                                                    |
| --------------------------------------------- | --------------------- | ------------------------------------------------------------------------------ |
| Runnable walking skeleton with view routing    | PH-07 through PH-13  | Chapter implementations replace placeholder views in their respective directories |
| `StarlightSyncApp` with FlowCoordinator wiring | PH-14                | Cross-chapter transition polish modifies the routing layer                      |
| End-to-end navigation for persistence testing  | PH-15                | Unit tests validate FlowCoordinator behavior already wired into a running app  |
| App entry point pattern                        | PH-03, PH-04         | AudioManager and HapticManager inject alongside FlowCoordinator at app level   |

---

## Stories

### Story 1: Create placeholder views for SwiftUI-target chapters (1, 3, 5, 6)

**Acceptance Criteria:**

- [ ] `HandshakeView.swift` created at `StarlightSync/Chapters/Chapter1_Handshake/HandshakeView.swift`.
- [ ] `CipherView.swift` created at `StarlightSync/Chapters/Chapter3_Cipher/CipherView.swift`.
- [ ] `BlueprintView.swift` created at `StarlightSync/Chapters/Chapter5_Blueprint/BlueprintView.swift`.
- [ ] `EventHorizonView.swift` created at `StarlightSync/Chapters/Chapter6_EventHorizon/EventHorizonView.swift`.
- [ ] Each view receives `FlowCoordinator` via `@Environment(FlowCoordinator.self)`.
- [ ] Each view displays its chapter number and title (e.g., "Chapter 1: The Handshake").
- [ ] Each view includes a temporary "Complete Chapter" `Button` that calls `coordinator.completeCurrentChapter()`.
- [ ] Each view includes a `#Preview` macro supplying a `FlowCoordinator` instance.
- [ ] Each view body is 80 lines or fewer.
- [ ] No force unwraps, no print statements, no deprecated APIs in any view file.
- [ ] `.gitkeep` files removed from all four chapter directories.

**Dependencies:** COORD_01
**Completion Signal:** All 4 views compile. All 4 `#Preview` macros render in Xcode canvas without error.

---

### Story 2: Create placeholder views for SpriteKit-target chapters (2, 4)

**Acceptance Criteria:**

- [ ] `PacketRunView.swift` created at `StarlightSync/Chapters/Chapter2_PacketRun/PacketRunView.swift`.
- [ ] `FirewallView.swift` created at `StarlightSync/Chapters/Chapter4_Firewall/FirewallView.swift`.
- [ ] Both views are plain SwiftUI (no `SpriteView`, no SpriteKit imports). SpriteKit integration is deferred to PH-08 and PH-10.
- [ ] Both views receive `FlowCoordinator` via `@Environment(FlowCoordinator.self)`.
- [ ] Both views display chapter number and title.
- [ ] Both views include a temporary "Complete Chapter" `Button`.
- [ ] Both views include a `#Preview` macro.
- [ ] Both view bodies are 80 lines or fewer.
- [ ] No `PacketRunScene.swift` or `FirewallScene.swift` created in this story. Scene files are PH-08 and PH-10 deliverables.
- [ ] `.gitkeep` files removed from both chapter directories.

**Dependencies:** COORD_01
**Completion Signal:** Both views compile. `#Preview` macros render. No SpriteKit imports present.

---

### Story 3: Wire StarlightSyncApp with FlowCoordinator and chapter view routing

**Acceptance Criteria:**

- [ ] `StarlightSyncApp` instantiates `FlowCoordinator` as `@State private var coordinator = FlowCoordinator()`.
- [ ] `FlowCoordinator` injected into SwiftUI environment via `.environment(coordinator)`.
- [ ] A root view implements an exhaustive `switch` on `coordinator.currentChapter` rendering the correct chapter view for all 6 cases.
- [ ] No `default` case in the switch statement. All `Chapter` enum cases are explicitly matched.
- [ ] No `@EnvironmentObject`, no `@StateObject`, no `ObservableObject` usage.
- [ ] `ContentView.swift` deleted from project. All references to `ContentView` removed from `StarlightSyncApp.swift`.
- [ ] `.gitkeep` file removed from `Coordinators/` if not already removed in COORD_01.
- [ ] App launches and displays the view corresponding to `FlowCoordinator.currentChapter`.

**Dependencies:** COORD_02-S1, COORD_02-S2
**Completion Signal:** App launches on simulator displaying `HandshakeView`. `ContentView.swift` no longer exists in the project. Tapping "Complete Chapter" on `HandshakeView` navigates to `PacketRunView`.

---

### Story 4: Validate end-to-end walking skeleton navigation and persistence

**Acceptance Criteria:**

- [ ] App launches on simulator displaying Chapter 1 (HandshakeView) placeholder.
- [ ] Tapping "Complete Chapter" on each view advances to the next chapter view in sequence: 1 -> 2 -> 3 -> 4 -> 5 -> 6.
- [ ] After reaching Chapter 6 (EventHorizonView), tapping "Complete Chapter" is a no-op. App remains on Chapter 6.
- [ ] Force-quit and relaunch: app resumes at the highest reached chapter (e.g., if Chapter 4 was reached, relaunch shows FirewallView).
- [ ] First launch with clean `UserDefaults`: app starts at Chapter 1.
- [ ] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0 and zero errors.
- [ ] `python3 scripts/audit.py --all` passes with zero violations.
- [ ] No `.gitkeep` files remain in any directory that now contains Swift source files.
- [ ] No `ContentView.swift` in the project.
- [ ] Zero force unwraps, zero print statements, zero deprecated APIs across all files created or modified in this epic.
- [ ] No AI attribution artifacts in any file (Protocol Zero).

**Dependencies:** COORD_02-S3
**Completion Signal:** Full Chapter 1 through 6 navigation demonstrated. Kill-and-relaunch persistence verified. Clean build. Audit passes. Walking skeleton is operational.

---

## Risks

| Risk                                                      | Impact (1-5) | Likelihood (1-5) | Score | Mitigation                                                                                       | Owner         |
| --------------------------------------------------------- | :----------: | :--------------: | :---: | ------------------------------------------------------------------------------------------------ | ------------- |
| @Environment(FlowCoordinator.self) pattern fails at runtime |      4       |        1         |   4   | Pattern is standard for @Observable classes in iOS 17+. Target SDK is iOS 26. Well-documented.   | iOS Architect |
| Removing ContentView.swift breaks Xcode project references |      3       |        2         |   6   | Verify project navigator and build phases after deletion. Rebuild to confirm no missing references. | iOS Architect |
| Placeholder views diverge in pattern, causing chapter-phase rework |      2       |        2         |   4   | All 6 placeholders follow identical structure. Chapter implementations replace entire file contents. | iOS Architect |
| Exhaustive switch on Chapter enum becomes stale if enum changes |      2       |        1         |   2   | Chapter enum is immutable per CLAUDE.md S3.2 (6-chapter structure is frozen). Compile-time safety net. | iOS Architect |

---

## Definition of Done

- [ ] All 4 stories completed and individually verified.
- [ ] Six placeholder chapter views exist at correct file paths per CLAUDE.md S8.
- [ ] All 6 views include `#Preview` macros that render without error.
- [ ] `StarlightSyncApp.swift` routes to chapter views based on `FlowCoordinator.currentChapter`.
- [ ] `ContentView.swift` removed. Zero dead code references remain.
- [ ] End-to-end Chapter 1 through 6 navigation works via "Complete Chapter" actions.
- [ ] UserDefaults persistence verified: kill-and-relaunch resumes at correct chapter.
- [ ] `xcodebuild build` succeeds with zero errors.
- [ ] `scripts/audit.py --all` passes with zero violations.
- [ ] Zero force unwraps, zero print statements, zero deprecated APIs.
- [ ] No AI attribution artifacts (Protocol Zero).
- [ ] All `.gitkeep` files removed from directories now containing source files.

## Exit Criteria

- [ ] All Definition of Done conditions satisfied.
- [ ] Walking skeleton demonstrated: app launches, navigates all 6 chapters, persists state across relaunches.
- [ ] PH-02 phase gate passed. All PH-02 deliverables present: `FlowCoordinator.swift`, `StarlightSyncApp.swift` (updated), 6 placeholder chapter views.
- [ ] Downstream phases unblocked: PH-03, PH-04, PH-06, PH-07 through PH-13, PH-12.
- [ ] PH-02 completion recorded in `.claude/context/progress/completed.md` and `MANIFEST.md` updated.
