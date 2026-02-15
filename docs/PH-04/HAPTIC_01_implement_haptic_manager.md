# Epic: HAPTIC_01 — Implement HapticManager Singleton

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | HAPTIC_01                      |
| **Epic Name** | implement_haptic_manager       |
| **Phase**     | PH-04                          |
| **Domain**    | HAPTIC                         |
| **Owner**     | iOS Engineer                   |
| **Status**    | Complete                       |

---

## Problem Statement

PH-03 delivered `AudioManager` as the centralized audio playback singleton, completing the audio channel of the multi-sensory feedback architecture. The haptic channel remains unimplemented. Every chapter in the Design-Doc specifies haptic feedback: a capacitor charge pattern with rising intensity during the Chapter 1 long-press (§3.2), click detents on cipher wheel scrolling in Chapter 3 (§3.4), a heavy thud on correct segment alignment in Chapter 3 (§3.4), and a heartbeat pattern during the Chapter 6 progressive-resistance slider drag (§3.7). Without a centralized haptic management layer, each chapter would independently create `CHHapticEngine` instances, parse AHAP patterns, implement crash recovery handlers, and handle device capability detection — producing duplicated lifecycle code, inconsistent engine state, and unrecoverable crashes when the engine stalls mid-playback.

The Design-Doc (§4.2, §7.6, §8.3) mandates a singleton `HapticManager` wrapping `CHHapticEngine` with `stoppedHandler` and `resetHandler` crash recovery, AHAP pattern caching at launch, and graceful degradation when the haptic engine is unavailable. CLAUDE.md §4.4 codifies the engineering constraints: `@Observable` `@MainActor` isolation, no Combine, no GCD, `CACurrentMediaTime()` for haptic timing, AHAP files for complex patterns, inline `CHHapticEvent` arrays for simple one-shot feedback, and failure isolation preventing haptic errors from propagating to the UI layer or gating chapter progression.

This epic delivers `HapticManager` as the sole haptic entry point for the entire application, satisfying the component boundary defined in CLAUDE.md §3.3: `HapticManager` owns AHAP playback and engine lifecycle, accessing only `CHHapticEngine` and `CHHapticPattern`.

---

## Goals

- Deliver `HapticManager` as a production-ready `@Observable` `@MainActor` singleton at `Managers/HapticManager.swift`.
- Detect device haptic capability via `CHHapticEngine.capabilitiesForHardware().supportsHaptics` and silently degrade to a no-op on unsupported hardware.
- Configure `CHHapticEngine` with `stoppedHandler` and `resetHandler` crash recovery per Design-Doc §8.3.
- Parse and cache all three AHAP patterns (`heartbeat.ahap`, `capacitor_charge.ahap`, `thud.ahap`) as `CHHapticPattern` instances during the launch pre-load sequence.
- Expose a fire-and-forget `play(_:)` API that creates transient `CHHapticPatternPlayer` instances per-playback from the pattern cache.
- Expose an inline transient event API for simple one-shot haptic feedback (click detents, tap confirmations) without requiring AHAP files.
- Use `CACurrentMediaTime()` as the sole timing source for haptic-audio synchronization.
- Ensure haptic engine failure does not propagate to the UI layer, block chapter progression, or gate Auto-Assist.

## Non-Goals

- **No AHAP file creation.** Actual `.ahap` pattern files are authored by the project owner and placed in the `Haptics/` bundle directory. This epic builds the parsing and playback infrastructure with the three pattern identifiers defined in Design-Doc §7.6.
- **No FlowCoordinator integration for haptic triggers.** Wiring specific chapter events (capacitor snap, cipher thud, heartbeat) to `HapticManager.play(_:)` calls is PH-07 through PH-13 scope when chapters consume the API.
- **No audio-haptic synchronization wiring.** Multi-sensory coordination between `AudioManager` and `HapticManager` (firing SFX and haptic pattern simultaneously) is chapter-level scope (PH-07 through PH-13).
- **No unit tests.** Formal test suite is PH-15 scope. Injectable design (bundle URL resolver) prepares the class for testability. CoreHaptics requires physical hardware — CLAUDE.md §7.3 prohibits `CHHapticEngine` in test code.
- **No GameConstants integration.** Pattern identifiers are defined as local constants in this epic. PH-06 will extract them to `GameConstants` type-safe enums.
- **No AudioManager interaction.** `HapticManager` and `AudioManager` are parallel, independent singletons per CLAUDE.md §3.3. Neither depends on nor calls the other.
- **No asset pre-load orchestration.** The launch sequence coordinator that calls `preloadPatterns()` alongside `AudioManager.preloadAssets()` and image/texture pre-loading is PH-05 scope. This epic exposes the pre-load API.

---

## Technical Approach

`HapticManager` is implemented as a `@MainActor` `@Observable` `final class` conforming to CLAUDE.md §4.4 and §4.2. No `ObservableObject`, `@Published`, `@StateObject`, or Combine usage. The class exposes observable state via the `@Observable` macro — specifically `engineAvailable: Bool` which downstream views can observe to conditionally display haptic-dependent UI (though no chapter gates on this value per the degradation guarantee).

The singleton access pattern uses a `static let shared` instance with a `private init()`. The initializer accepts an injectable bundle URL resolver closure (`(String, String?) -> URL?`) defaulting to `Bundle.main.url(forResource:withExtension:)` to enable test isolation of AHAP file loading per CLAUDE.md §7.3.

**Device capability detection** is the first operation in `init()`. `CHHapticEngine.capabilitiesForHardware().supportsHaptics` is checked before any engine creation. If the device lacks a Taptic Engine (e.g., iOS Simulator), `engineAvailable` is set to `false` and all subsequent `play(_:)` calls return immediately as no-ops. This satisfies Design-Doc §12.3 multi-sensory redundancy: the visual and audio channels operate independently.

**Engine creation** follows capability confirmation. A `CHHapticEngine` instance is created and stored as a private optional property. Engine creation failure is caught in a `do/catch` block, logged via `os.Logger` under `#if DEBUG`, and results in `engineAvailable = false` — no crash, no throw.

**Crash recovery handlers** are registered immediately after engine creation per Design-Doc §8.3. The `stoppedHandler` captures `[weak self]`, logs the stop reason under `#if DEBUG`, and attempts a single `engine.start()` restart. If restart fails, `engineAvailable` is set to `false`. The `resetHandler` captures `[weak self]` and performs a full engine recreation sequence: create a new `CHHapticEngine`, re-register both handlers on the new instance, re-parse all AHAP patterns into the cache, and call `engine.start()`. If any step in the reset sequence fails, `engineAvailable` is set to `false` and the manager silently degrades.

**AHAP pattern caching** uses a `[String: CHHapticPattern]` dictionary keyed by pattern name (e.g., `"heartbeat"`, `"capacitor_charge"`, `"thud"`). The `preloadPatterns()` method iterates the three pattern identifiers, resolves each AHAP file URL via the injectable bundle resolver, parses via `CHHapticPattern(contentsOf:)`, and stores the result. Parse failures are handled per-pattern: logged under `#if DEBUG` and skipped — a single corrupt AHAP file does not abort the batch or crash the app. The cache is populated once at launch (called during PH-05's pre-load sequence) and is read-only thereafter.

**Pattern playback** via `play(_:)` is fire-and-forget. The method looks up the cached `CHHapticPattern` by name, creates a transient `CHHapticPatternPlayer` via `engine.makePlayer(with:)`, and calls `player.start(atTime: CHHapticTimeImmediate)`. Players are created per-playback and never cached — `CHHapticPatternPlayer` is lightweight and transient by design. All `try` calls are wrapped in `do/catch` with `#if DEBUG` logging. If the engine is unavailable or the pattern is not cached, the call returns silently.

**Inline transient events** expose a `playTransientEvent(intensity:sharpness:)` method for simple one-shot haptic feedback that does not warrant a full AHAP file — cipher wheel click detents, tap confirmations, error buzzes. The method creates a `CHHapticEvent` of type `.hapticTransient` with the specified `CHHapticEventParameter` values for intensity and sharpness, wraps it in a `CHHapticPattern`, creates a transient player, and fires immediately. This satisfies CLAUDE.md §4.4: "Inline `CHHapticEvent` arrays for simple one-shot feedback."

**Failure isolation** is enforced throughout: every CoreHaptics API call uses `do/catch` or optional chaining. No `throws` propagates to the public API surface. No force unwraps on engine, pattern, or URL optionals. `HapticManager` continues to accept API calls after a failure — if the engine recovers via `resetHandler`, subsequent calls succeed transparently.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| FlowCoordinator with Chapter enum and state machine | COORD_01 (PH-02) | Complete | iOS Architect |
| Walking skeleton with chapter routing | COORD_02 (PH-02) | Complete | iOS Architect |
| `Managers/` directory in project structure | INFRA_01 (PH-01) | Complete | iOS Engineer |
| `Haptics/` bundle resource directory | INFRA_01 (PH-01) | Complete | iOS Engineer |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| HapticManager singleton with preload API | PH-05 | Asset Pre-load Pipeline calls `preloadPatterns()` during launch sequence |
| HapticManager AHAP playback API | PH-07 | Chapter 1 triggers `capacitor_charge.ahap` during long-press and thud on snap |
| HapticManager AHAP playback API | PH-09 | Chapter 3 triggers `thud.ahap` on correct cipher segment alignment |
| HapticManager inline transient event API | PH-09 | Chapter 3 fires haptic click detent per wheel scroll tick |
| HapticManager AHAP playback API | PH-13 | Chapter 6 triggers `heartbeat.ahap` during slider drag |
| HapticManager inline transient event API | PH-11 | Chapter 5 fires error haptic on invalid node connection |
| HapticManager engine availability for degradation | PH-14 | Cross-chapter transitions verify multi-sensory redundancy |

---

## Stories

### Story 1: Implement HapticManager @Observable @MainActor singleton class

**Acceptance Criteria:**

- [ ] `HapticManager` declared as `@Observable @MainActor final class` at `StarlightSync/Managers/HapticManager.swift`.
- [ ] `static let shared` singleton accessor.
- [ ] `private init()` preventing external instantiation.
- [ ] Observable state property: `private(set) var engineAvailable: Bool = false`.
- [ ] Injectable bundle URL resolver closure `(String, String?) -> URL?` on initializer (default: `Bundle.main.url(forResource:withExtension:)`).
- [ ] No `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject`, or Combine imports.
- [ ] No force unwraps in the entire file.
- [ ] File contains exactly one primary type (`HapticManager`).
- [ ] `import CoreHaptics` and `import os` as the only non-Foundation imports.

**Dependencies:** None
**Completion Signal:** `HapticManager.shared` compiles and returns a configured singleton. SwiftUI view referencing `hapticManager.engineAvailable` compiles without error.

---

### Story 2: Configure CHHapticEngine with device capability detection

**Acceptance Criteria:**

- [ ] `CHHapticEngine.capabilitiesForHardware().supportsHaptics` checked before engine creation.
- [ ] If `supportsHaptics` is `false`, `engineAvailable` remains `false` and no engine instance is created. All subsequent API calls are silent no-ops.
- [ ] If `supportsHaptics` is `true`, a `CHHapticEngine` instance is created and stored as a private optional property.
- [ ] Engine creation wrapped in `do/catch` — failure logged via `os.Logger` under `#if DEBUG`, `engineAvailable` set to `false`, no crash.
- [ ] `engine.start()` called after creation with `do/catch` protection.
- [ ] No `DispatchQueue`, `Timer`, or Combine usage in engine setup.
- [ ] `engineAvailable` set to `true` only after successful `engine.start()`.

**Dependencies:** HAPTIC_01-S1
**Completion Signal:** On a device with Taptic Engine, `HapticManager.shared.engineAvailable == true` after initialization. On iOS Simulator (no Taptic Engine), `engineAvailable == false` with zero crashes or error propagation.

---

### Story 3: Register stoppedHandler for engine crash recovery

**Acceptance Criteria:**

- [ ] `engine.stoppedHandler` registered immediately after engine creation, before `engine.start()`.
- [ ] Handler uses `[weak self]` capture list — no strong self retention.
- [ ] Handler logs the stop reason via `os.Logger` under `#if DEBUG`.
- [ ] Handler attempts engine restart via `try engine.start()` exactly once.
- [ ] On successful restart, `engineAvailable` remains `true`.
- [ ] On failed restart, `engineAvailable` set to `false` — no crash, no error propagation.
- [ ] Handler dispatches state mutations to `@MainActor` context.
- [ ] No `DispatchQueue`, `Timer`, or Combine in handler implementation.

**Dependencies:** HAPTIC_01-S2
**Completion Signal:** If the engine stops unexpectedly, the handler fires, attempts restart, and either recovers or degrades silently. No crash path exists in the handler.

---

### Story 4: Register resetHandler for engine reset recovery

**Acceptance Criteria:**

- [ ] `engine.resetHandler` registered immediately after `stoppedHandler`, before `engine.start()`.
- [ ] Handler uses `[weak self]` capture list — no strong self retention.
- [ ] Handler creates a new `CHHapticEngine` instance (the old instance is invalid after reset).
- [ ] Handler re-registers both `stoppedHandler` and `resetHandler` on the new engine instance.
- [ ] Handler re-parses and re-caches all AHAP patterns from the bundle.
- [ ] Handler calls `engine.start()` on the new instance.
- [ ] On successful reset, the old engine reference is replaced with the new one, `engineAvailable` remains `true`.
- [ ] On failure at any step, `engineAvailable` set to `false` — no crash, no error propagation.
- [ ] Handler dispatches state mutations to `@MainActor` context.
- [ ] Pattern cache is fully repopulated after reset — stale cache entries from the old engine are cleared.

**Dependencies:** HAPTIC_01-S2, HAPTIC_01-S3
**Completion Signal:** After an engine reset event, the handler recreates the engine, re-registers handlers, re-caches patterns, and restarts. Subsequent `play(_:)` calls succeed with the new engine.

---

### Story 5: Implement AHAP pattern parsing and caching

**Acceptance Criteria:**

- [ ] Public method `func preloadPatterns()` parses and caches all AHAP patterns.
- [ ] Three pattern identifiers parsed: `"heartbeat"`, `"capacitor_charge"`, `"thud"` per Design-Doc §7.6.
- [ ] Pattern identifiers defined as private named constants (no magic strings in parsing logic).
- [ ] Each AHAP file resolved via the injectable bundle URL resolver with extension `"ahap"`.
- [ ] Parsing uses `CHHapticPattern(contentsOf:)` on the resolved URL.
- [ ] Parsed patterns cached in a `private var cachedPatterns: [String: CHHapticPattern]` dictionary keyed by identifier.
- [ ] Parse failure for individual patterns is logged via `os.Logger` under `#if DEBUG` and skipped — does not abort the batch.
- [ ] `preloadPatterns()` can be called multiple times without duplicating work for already-cached identifiers.
- [ ] If `engineAvailable` is `false`, `preloadPatterns()` returns immediately as a no-op.
- [ ] Total cache memory footprint is <1MB (AHAP patterns are lightweight JSON-derived structs per Design-Doc §7.9.3).

**Dependencies:** HAPTIC_01-S2
**Completion Signal:** After calling `preloadPatterns()`, the internal cache contains `CHHapticPattern` entries for all three identifiers (assuming AHAP files exist in the bundle). Subsequent `play("heartbeat")` retrieves the cached pattern without re-parsing.

---

### Story 6: Implement fire-and-forget AHAP pattern playback API

**Acceptance Criteria:**

- [ ] Public method `func play(_ patternName: String)` triggers haptic playback from the pattern cache.
- [ ] Method looks up `cachedPatterns[patternName]` — if not found, returns silently (pattern may have failed to parse).
- [ ] Method creates a transient `CHHapticPatternPlayer` via `engine.makePlayer(with: pattern)`.
- [ ] Method starts the player via `player.start(atTime: CHHapticTimeImmediate)`.
- [ ] Player creation and start wrapped in `do/catch` — failure logged under `#if DEBUG`, no crash, no throw to caller.
- [ ] Method signature has no return value and does not throw — pure fire-and-forget.
- [ ] Players are never cached — created per-playback and released after completion.
- [ ] If `engineAvailable` is `false`, method returns immediately as a no-op.
- [ ] Multiple concurrent `play(_:)` calls for different patterns execute without interference.

**Dependencies:** HAPTIC_01-S5
**Completion Signal:** Calling `play("thud")` on a device with Taptic Engine produces a perceptible heavy transient haptic event. Calling `play("nonexistent")` returns silently with no crash.

---

### Story 7: Implement inline transient event playback for simple one-shot feedback

**Acceptance Criteria:**

- [ ] Public method `func playTransientEvent(intensity: Float, sharpness: Float)` triggers a single transient haptic event without requiring an AHAP file.
- [ ] `intensity` and `sharpness` parameters clamped to the valid `CHHapticEventParameter` range [0.0, 1.0].
- [ ] Method creates a `CHHapticEvent` of type `.hapticTransient` with duration `0` and the specified intensity/sharpness parameters.
- [ ] Method wraps the event in a `CHHapticPattern`, creates a transient player, and starts at `CHHapticTimeImmediate`.
- [ ] All `try` calls wrapped in `do/catch` — failure logged under `#if DEBUG`, no crash, no throw to caller.
- [ ] Method signature has no return value and does not throw — pure fire-and-forget.
- [ ] If `engineAvailable` is `false`, method returns immediately as a no-op.
- [ ] Multiple rapid calls (e.g., cipher wheel scroll detents) execute without interference or accumulation.

**Dependencies:** HAPTIC_01-S2
**Completion Signal:** Calling `playTransientEvent(intensity: 0.5, sharpness: 0.3)` on a device with Taptic Engine produces a perceptible short tap. Calling it on simulator returns silently.

---

### Story 8: Implement graceful degradation across all public APIs

**Acceptance Criteria:**

- [ ] Every public method on `HapticManager` is non-throwing — no `throws` keyword on any public function signature.
- [ ] All `CHHapticEngine`, `CHHapticPattern`, and `CHHapticPatternPlayer` operations wrapped in `do/catch` or use optional chaining.
- [ ] Failures logged via `os.Logger` with `OSLog` subsystem under `#if DEBUG` only. No `print` statements.
- [ ] No haptic failure propagates to views, FlowCoordinator, chapter completion logic, or Auto-Assist thresholds.
- [ ] `HapticManager` continues to accept API calls after a failure — subsequent calls may succeed if the engine recovers via `resetHandler`.
- [ ] Chapter progression is never gated on `engineAvailable` state.
- [ ] Visual feedback (animations, color changes) and audio feedback (`AudioManager` SFX) provide full multi-sensory redundancy per Design-Doc §12.3 — haptic absence does not degrade the user-facing experience beyond the loss of tactile feedback.
- [ ] Zero force unwraps (`!`) in the entire file.
- [ ] Zero implicitly unwrapped optionals except where Apple API requires.

**Dependencies:** HAPTIC_01-S1 through HAPTIC_01-S7
**Completion Signal:** Calling `play("heartbeat")` when the engine has stalled does not crash, does not throw, and logs a debug message. All subsequent API calls remain functional. `FlowCoordinator.completeCurrentChapter()` proceeds regardless of haptic engine state.

---

### Story 9: Validate governance compliance and build

**Acceptance Criteria:**

- [ ] Zero force unwraps (`!`) in `HapticManager.swift`.
- [ ] Zero `print` statements — all diagnostics use `os.Logger` under `#if DEBUG`.
- [ ] Zero deprecated API usage (`ObservableObject`, `@Published`, `@StateObject`, `DispatchQueue`, `Combine`).
- [ ] Zero Combine imports.
- [ ] Zero AI attribution artifacts (Protocol Zero compliance).
- [ ] Zero magic numbers — all pattern identifiers and tuning values as named constants.
- [ ] `import CoreHaptics` and `import os` as the only framework imports beyond Foundation.
- [ ] `HapticManager.swift` exists at `StarlightSync/Managers/HapticManager.swift`.
- [ ] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0.
- [ ] `python3 scripts/audit.py --all` passes with zero violations.
- [ ] File registered in `project.pbxproj` — PBXFileReference, PBXBuildFile, PBXGroup (Managers), and PBXSourcesBuildPhase entries present.
- [ ] No direct `CHHapticEngine` usage exists anywhere in the codebase outside `HapticManager.swift`.

**Dependencies:** HAPTIC_01-S1 through HAPTIC_01-S8
**Completion Signal:** Clean build with zero errors. Audit script passes 7/7 checks. `HapticManager.swift` compiles and is linkable from any chapter view or coordinator.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| CHHapticEngine unavailable on iOS Simulator (no Taptic Engine hardware) | 2 | 5 | 10 | Capability check (`supportsHaptics`) gates all engine operations. Build validates on generic simulator destination; runtime haptics tested on device in PH-16. Graceful degradation ensures zero crashes on simulator. | iOS Engineer |
| Engine stoppedHandler or resetHandler fires during active pattern playback | 3 | 2 | 6 | Transient players are not cached — if the engine stalls mid-playback, the player is abandoned. Recovery handlers recreate the engine for subsequent calls. No state corruption risk. | iOS Engineer |
| AHAP file missing from Haptics/ bundle directory (files not yet authored) | 2 | 4 | 8 | `preloadPatterns()` handles missing files per-pattern via `do/catch`. Individual parse failures are logged and skipped. The manager operates with partial or empty cache without error. Actual AHAP files are placed during chapter implementation phases. | iOS Engineer |
| @MainActor isolation prevents stoppedHandler/resetHandler from mutating state | 4 | 2 | 8 | Handler closures dispatch state mutations to `@MainActor` via `Task { @MainActor in }`. Engine operations within handlers execute in the handler's own context; only `engineAvailable` mutation requires main actor dispatch. | iOS Engineer |
| CHHapticPatternPlayer.start() throws on rapid sequential calls | 2 | 2 | 4 | Each `play(_:)` call creates a fresh transient player. Players are independent — rapid sequential calls create independent players. All `start()` calls are in `do/catch` for safety. | iOS Engineer |

---

## Definition of Done

- [ ] All 9 stories completed and individually verified.
- [ ] `HapticManager` compiles as `@Observable @MainActor final class` with `static let shared`.
- [ ] Device capability detected via `CHHapticEngine.capabilitiesForHardware().supportsHaptics`.
- [ ] `CHHapticEngine` starts successfully on supported hardware.
- [ ] `stoppedHandler` registered and attempts engine restart on unexpected stop.
- [ ] `resetHandler` registered and recreates engine, re-registers handlers, re-caches patterns on reset.
- [ ] All 3 AHAP patterns (`heartbeat`, `capacitor_charge`, `thud`) parse and cache without error.
- [ ] `play(_:)` creates transient `CHHapticPatternPlayer` per-playback from cached patterns.
- [ ] `playTransientEvent(intensity:sharpness:)` fires inline one-shot haptic events without AHAP files.
- [ ] Engine failure does not crash the app, propagate to the view layer, or gate chapter progression.
- [ ] Zero force unwraps, zero print statements, zero deprecated APIs, zero Combine usage.
- [ ] `xcodebuild build` succeeds with zero errors.
- [ ] `scripts/audit.py --all` passes with zero violations.
- [ ] No AI attribution artifacts (Protocol Zero).
- [ ] File registered in `project.pbxproj` with all required build phase entries.

## Exit Criteria

- [ ] All Definition of Done conditions satisfied.
- [ ] `HapticManager.swift` exists at `StarlightSync/Managers/HapticManager.swift` as a fully compilable singleton.
- [ ] PH-05 (Asset Pre-load Pipeline) is unblocked — `preloadPatterns()` API is callable.
- [ ] PH-07 (Chapter 1) is unblocked — `play("capacitor_charge")` API is callable.
- [ ] PH-09 (Chapter 3) is unblocked — `play("thud")` and `playTransientEvent(intensity:sharpness:)` APIs are callable.
- [ ] PH-13 (Chapter 6) is unblocked — `play("heartbeat")` API is callable.
- [ ] PH-14 (Cross-Chapter Transitions) is unblocked — `engineAvailable` state is observable for multi-sensory redundancy verification.
- [ ] Epic ID `HAPTIC_01` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
