# Epic: AUDIO_01 — Implement AudioManager Singleton

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | AUDIO_01                       |
| **Epic Name** | implement_audio_manager        |
| **Phase**     | PH-03                          |
| **Domain**    | AUDIO                          |
| **Owner**     | iOS Engineer                   |
| **Status**    | Complete                       |

---

## Problem Statement

PH-02 delivered a functional FlowCoordinator state machine and walking skeleton that transitions through six placeholder chapter views. The app is silent — no background music, no sound effects, no audio session management. Every chapter in the Design-Doc (§3.2–§3.7) specifies audio feedback: capacitor snap SFX in Chapter 1, heart pickup chimes in Chapter 2, cipher click and thud SFX in Chapter 3, beat-synchronized BGM in Chapter 4, connection chimes and error SFX in Chapter 5, and finale song playback in Chapter 6. Without a centralized audio management layer, each chapter would independently configure `AVAudioSession`, create `AVAudioPlayer` instances, and handle system interruptions — producing duplicated lifecycle code, inconsistent session behavior, and audio gaps on chapter transitions.

The Design-Doc (§4.2, §8.1–§8.4) mandates a singleton `AudioManager` wrapping `AVAudioPlayer` with `.playback` session category, dual-player cross-fade architecture, interruption recovery, and pre-load guarantees. CLAUDE.md §4.5 codifies the engineering constraints: `@Observable` `@MainActor` isolation, no Combine, no GCD, `CACurrentMediaTime()` for beat-critical timing, and failure isolation preventing audio errors from propagating to the UI layer.

This epic delivers `AudioManager` as the sole audio entry point for the entire application, satisfying the component boundary defined in CLAUDE.md §3.3: `AudioManager` owns playback, cross-fade, and session lifecycle, accessing only `AVAudioSession` and `AVAudioPlayer`.

---

## Goals

- Deliver `AudioManager` as a production-ready `@Observable` `@MainActor` singleton at `Managers/AudioManager.swift`.
- Configure `AVAudioSession` with `.playback` category at initialization, ensuring audio plays with the Silent Switch on.
- Implement dual-`AVAudioPlayer` cross-fade architecture with 500ms overlapping fade for seamless BGM transitions between chapters.
- Register `AVAudioSession.interruptionNotification` and `routeChangeNotification` observers with correct pause/resume semantics.
- Expose a `prepareToPlay()` pre-load API that accepts all audio asset identifiers and prepares players for zero-latency playback.
- Expose a one-shot SFX playback API independent of BGM cross-fade logic.
- Use `CACurrentMediaTime()` as the sole timing source for beat-critical playback coordination.
- Ensure audio failure does not propagate to the UI layer, block chapter progression, or gate Auto-Assist.

## Non-Goals

- **No asset file creation.** Actual `.m4a` audio files are provided by the project owner and integrated during PH-05 (Asset Pre-load Pipeline). This epic builds the playback infrastructure with placeholder asset identifiers.
- **No FlowCoordinator integration for interruption-driven game state pause.** The `AudioManager` posts interruption state changes that FlowCoordinator can observe; wiring the pause/resume flow into FlowCoordinator is PH-07+ scope when chapters consume the API.
- **No beat map implementation.** Beat map data structures and Chapter 4 synchronization logic are PH-06 (GameConstants) and PH-10 (Chapter 4) scope. This epic provides `CACurrentMediaTime()`-based timing primitives that those phases consume.
- **No cross-chapter transition wiring.** Triggering cross-fade on chapter transitions is PH-14 scope. This epic exposes the cross-fade API.
- **No unit tests.** Formal test suite is PH-15 scope. Injectable design (asset loader closure, notification center) prepares the class for testability.
- **No GameConstants integration.** Tuning values (500ms fade duration, asset identifier enums) are defined as local constants in this epic. PH-06 will extract them to `GameConstants`.
- **No HapticManager interaction.** Multi-sensory coordination between audio and haptics is chapter-level scope (PH-07 through PH-13).

---

## Technical Approach

`AudioManager` is implemented as a `@MainActor` `@Observable` `final class` conforming to CLAUDE.md §4.5 and §4.2. No `ObservableObject`, `@Published`, `@StateObject`, or Combine usage. The class exposes observable state properties (`isPlaying`, `isMuted`, `isInterrupted`) that SwiftUI views can track automatically through the `@Observable` macro's synthesized observation.

The singleton access pattern uses a `static let shared` instance. The initializer accepts an injectable `NotificationCenter` parameter (defaulting to `.default`) to enable test isolation of interruption notification handling per CLAUDE.md §7.3. An injectable asset loader closure (`(String) -> URL?`) abstracts `Bundle.main.url(forResource:withExtension:)` for testability without requiring real audio files.

**AVAudioSession** is configured once during `AudioManager` initialization with category `.playback` and mode `.default` per Design-Doc §8.1. The `.playback` category ensures audio output continues when the device Silent Switch is on — critical for the experience. No `.mixWithOthers` option is set per Design-Doc §8.1 ("the app's audio should be the sole audio output"). Session activation failure is handled gracefully: the manager logs via `os.Logger` under `#if DEBUG` and continues with a degraded state flag.

**Dual-player cross-fade** uses two `AVAudioPlayer` instances (`playerA` and `playerB`) for background music. On a BGM transition, the standby player loads the next track, calls `prepareToPlay()`, begins playback, and fades volume from 0.0 to 1.0 over 500ms while the active player simultaneously fades from 1.0 to 0.0. The fade is driven by a `CADisplayLink`-based timer (or `withAnimation` if pure SwiftUI timing suffices) ticking at display refresh rate, computing volume interpolation against `CACurrentMediaTime()` elapsed delta. After fade completion, the outgoing player is stopped and its reference is recycled as the next standby. This eliminates audible gaps between chapters per Design-Doc §7.4.

**SFX playback** maintains a separate pool of `AVAudioPlayer` instances for one-shot sound effects. Each SFX call creates or reuses a prepared player, sets volume to 1.0, plays from the beginning, and releases upon completion via the `AVAudioPlayerDelegate` `audioPlayerDidFinishPlaying(_:successfully:)` callback. SFX players operate independently of BGM cross-fade — neither pauses, fades, nor interrupts the other.

**Interruption handling** registers for `AVAudioSession.interruptionNotification` and `routeChangeNotification` via `NotificationCenter`. On `.began`, all active players are paused and `isInterrupted` is set to `true`. On `.ended` with `.shouldResume` option present, players resume and `isInterrupted` resets. Route change monitoring handles headphone disconnect (pause playback to prevent unexpected speaker output). All notification handling runs on `@MainActor` via `MainActor.assumeIsolated` or structured `Task { @MainActor in }` from the notification callback.

**Pre-load API** exposes `func preloadAllAssets(_ identifiers: [String])` that iterates the provided asset identifiers, creates `AVAudioPlayer` instances, and calls `prepareToPlay()` on each. This satisfies Design-Doc §8.4 and §7.9.2 step 4: all audio players prepared during the launch sequence. Prepared players are cached in a dictionary keyed by asset identifier for O(1) retrieval during playback.

**Failure isolation** is enforced throughout: all `AVAudioPlayer` and `AVAudioSession` operations use `do/catch` or optional chaining. Failures are logged via `os.Logger` under `#if DEBUG`. No `throws` propagates to the public API. No force unwraps on player creation, URL resolution, or session configuration.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| FlowCoordinator with Chapter enum and state machine | COORD_01 (PH-02) | Complete | iOS Architect |
| Walking skeleton with chapter routing | COORD_02 (PH-02) | Complete | iOS Architect |
| `Managers/` directory in project structure | INFRA_01 (PH-01) | Complete | iOS Engineer |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| AudioManager singleton with session config and cross-fade API | PH-05 | Asset Pre-load Pipeline calls `preloadAllAssets()` during launch sequence |
| AudioManager SFX playback API | PH-07 through PH-11 | All chapters trigger SFX via AudioManager |
| AudioManager BGM cross-fade API | PH-14 | Cross-chapter transitions trigger BGM cross-fade |
| AudioManager interruption state | PH-07+ | Chapters observe `isInterrupted` for game state pause |
| AudioManager beat-timing primitives | PH-10 | Chapter 4 FirewallScene uses `CACurrentMediaTime()`-based sync |
| AudioManager finale playback API | PH-13 | Chapter 6 triggers `audio_bgm_finale` at slider completion |
| AudioManager for webhook non-blocking verification | PH-12 | WebhookService fire-and-forget pattern validated against AudioManager's non-blocking playback |

---

## Stories

### Story 1: Configure AVAudioSession with .playback category

**Acceptance Criteria:**

- [ ] `AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)` called during `AudioManager` initialization.
- [ ] No `.mixWithOthers` option set per Design-Doc §8.1.
- [ ] Session activation via `setActive(true)` called after category configuration.
- [ ] Session configuration failure caught in `do/catch` — logged via `os.Logger` under `#if DEBUG`, no crash, no error propagation.
- [ ] `AudioManager` sets a `sessionConfigured: Bool` flag reflecting configuration success.
- [ ] No `DispatchQueue`, `Timer`, or Combine usage in session setup.

**Dependencies:** None
**Completion Signal:** `AVAudioSession.sharedInstance().category == .playback` after `AudioManager` initialization. Silent Switch on device does not mute app audio.

---

### Story 2: Implement AudioManager @Observable @MainActor singleton class

**Acceptance Criteria:**

- [ ] `AudioManager` declared as `@Observable @MainActor final class` at `StarlightSync/Managers/AudioManager.swift`.
- [ ] `static let shared` singleton accessor.
- [ ] Observable state properties: `private(set) var isPlaying: Bool`, `private(set) var isMuted: Bool`, `private(set) var isInterrupted: Bool`.
- [ ] Injectable `NotificationCenter` parameter on initializer (default: `.default`).
- [ ] Injectable asset loader closure `(String, String?) -> URL?` on initializer (default: `Bundle.main.url(forResource:withExtension:)`).
- [ ] No `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject`, or Combine imports.
- [ ] No force unwraps in the entire file.
- [ ] File contains exactly one primary type (`AudioManager`).
- [ ] `import AVFoundation` and `import os` as the only non-Foundation imports.

**Dependencies:** AUDIO_01-S1
**Completion Signal:** `AudioManager.shared` compiles and returns a configured singleton. SwiftUI view referencing `audioManager.isPlaying` triggers view updates on state change.

---

### Story 3: Implement dual-player BGM cross-fade architecture

**Acceptance Criteria:**

- [ ] Two `AVAudioPlayer` optional properties (`playerA`, `playerB`) for BGM cross-fade.
- [ ] `private var activePlayer` reference tracking which player is currently audible.
- [ ] Public method `func crossFadeToBGM(named identifier: String, fileExtension: String)` initiates cross-fade.
- [ ] Standby player loads the new track via the injected asset loader, calls `prepareToPlay()`, begins playback at volume 0.0.
- [ ] Active player fades from 1.0 to 0.0 over 500ms while standby fades from 0.0 to 1.0 over 500ms simultaneously.
- [ ] Volume interpolation computed against `CACurrentMediaTime()` elapsed delta — no `Timer`, `DispatchQueue.asyncAfter`, or `Task.sleep`.
- [ ] After fade completes, outgoing player is stopped; active player reference swaps to the new player.
- [ ] BGM loops indefinitely (`numberOfLoops = -1`) until explicitly stopped or cross-faded.
- [ ] Cross-fade duration stored as a named constant (`crossFadeDuration: TimeInterval = 0.5`).
- [ ] Calling `crossFadeToBGM` while a cross-fade is in progress cancels the current fade and starts a new one.

**Dependencies:** AUDIO_01-S2
**Completion Signal:** Calling `crossFadeToBGM(named: "track_a")` followed by `crossFadeToBGM(named: "track_b")` produces overlapping playback with no audible gap. Volume ramp completes in 500ms.

---

### Story 4: Implement SFX one-shot playback API

**Acceptance Criteria:**

- [ ] Public method `func playSFX(named identifier: String, fileExtension: String)` triggers one-shot playback.
- [ ] SFX players are created from the pre-loaded cache (if available) or on-demand via the asset loader.
- [ ] SFX playback is independent of BGM — SFX does not pause, fade, or interfere with BGM players.
- [ ] SFX players set `numberOfLoops = 0` (play once).
- [ ] SFX players start at volume 1.0 from the beginning (`currentTime = 0`).
- [ ] Multiple concurrent SFX can play simultaneously (e.g., chime + thud overlap).
- [ ] Completed SFX players are recycled to a reuse pool keyed by identifier to avoid repeated allocation.
- [ ] Audio player creation failure (bad URL, corrupt file) is silently handled — no crash, no error propagation to caller.

**Dependencies:** AUDIO_01-S2
**Completion Signal:** Calling `playSFX(named: "sfx_success_chime")` three times in rapid succession produces three overlapping chime playbacks without affecting BGM.

---

### Story 5: Implement prepareToPlay pre-load API

**Acceptance Criteria:**

- [ ] Public method `func preloadAssets(_ manifest: [(identifier: String, fileExtension: String)])` accepts an array of asset descriptors.
- [ ] For each descriptor, an `AVAudioPlayer` instance is created via the injected asset loader and `prepareToPlay()` is called.
- [ ] Prepared players are cached in a `[String: AVAudioPlayer]` dictionary keyed by identifier.
- [ ] Pre-load failure for individual assets is logged via `os.Logger` under `#if DEBUG` and skipped — does not abort the batch.
- [ ] Pre-load can be called multiple times without duplicating players for already-cached identifiers.
- [ ] Method is synchronous and non-blocking (players prepare on the calling thread per AVFoundation semantics).

**Dependencies:** AUDIO_01-S2
**Completion Signal:** After calling `preloadAssets([("audio_bgm_main", "m4a"), ("sfx_haptic_thud", "m4a")])`, the internal cache contains prepared players for both identifiers. Subsequent `playSFX(named: "sfx_haptic_thud")` plays with zero preparation latency.

---

### Story 6: Implement AVAudioSession interruption notification handling

**Acceptance Criteria:**

- [ ] `AudioManager` registers for `AVAudioSession.interruptionNotification` via the injected `NotificationCenter` during initialization.
- [ ] On interruption `.began`: all active BGM and SFX players are paused, `isInterrupted` set to `true`, `isPlaying` set to `false`.
- [ ] On interruption `.ended` with `.shouldResume` option: BGM resumes from paused position, `isInterrupted` set to `false`, `isPlaying` set to `true`.
- [ ] On interruption `.ended` without `.shouldResume`: players remain paused, `isInterrupted` set to `false`, `isPlaying` remains `false`.
- [ ] Notification callback dispatches to `@MainActor` for state mutation (no data races).
- [ ] No `DispatchQueue`, `Timer`, or Combine in notification handling.

**Dependencies:** AUDIO_01-S2, AUDIO_01-S3
**Completion Signal:** Simulating an interruption notification with `.began` type pauses BGM. Simulating `.ended` with `.shouldResume` resumes BGM from the paused position. `isInterrupted` toggles correctly throughout.

---

### Story 7: Implement AVAudioSession route change notification handling

**Acceptance Criteria:**

- [ ] `AudioManager` registers for `AVAudioSession.routeChangeNotification` via the injected `NotificationCenter` during initialization.
- [ ] On route change reason `.oldDeviceUnavailable` (headphone disconnect): pause all active players, set `isPlaying` to `false`.
- [ ] Other route change reasons are observed but do not alter playback state.
- [ ] Notification callback dispatches to `@MainActor` for state mutation.
- [ ] No `DispatchQueue`, `Timer`, or Combine in route change handling.

**Dependencies:** AUDIO_01-S2
**Completion Signal:** Simulating a route change notification with reason `.oldDeviceUnavailable` pauses active BGM playback.

---

### Story 8: Expose CACurrentMediaTime-based timing API for beat synchronization

**Acceptance Criteria:**

- [ ] Public method `func currentPlaybackTimestamp() -> TimeInterval` returns the current BGM playback position synchronized to `CACurrentMediaTime()`.
- [ ] Timestamp is computed as `playbackStartMediaTime + (CACurrentMediaTime() - playbackStartMediaTime)` where `playbackStartMediaTime` is captured at BGM play/resume.
- [ ] `playbackStartMediaTime` is updated on play, resume, and cross-fade completion.
- [ ] Method returns `0` if no BGM is playing.
- [ ] No use of `AVAudioPlayer.currentTime` as the timing source (drifts on seek and interruption recovery per CLAUDE.md §4.5).
- [ ] No `Timer`, `DispatchQueue.asyncAfter`, or `Task.sleep` for timing.

**Dependencies:** AUDIO_01-S3
**Completion Signal:** Calling `currentPlaybackTimestamp()` during active BGM playback returns a monotonically increasing value accurate to within ±10ms of the actual audio position.

---

### Story 9: Implement BGM stop and mute controls

**Acceptance Criteria:**

- [ ] Public method `func stopBGM()` stops the active BGM player, resets to beginning, sets `isPlaying` to `false`.
- [ ] Public method `func pauseBGM()` pauses the active BGM player without resetting position.
- [ ] Public method `func resumeBGM()` resumes from paused position if a BGM player exists and is paused.
- [ ] Public property `var isMuted: Bool` with public setter — when toggled, sets active BGM and all SFX player volumes to 0.0 (muted) or restores to previous volume (unmuted).
- [ ] Mute state persists across cross-fades — new BGM tracks start at volume 0.0 if muted.
- [ ] `isPlaying` accurately reflects actual playback state after each operation.

**Dependencies:** AUDIO_01-S3, AUDIO_01-S4
**Completion Signal:** Calling `stopBGM()` silences audio and resets position. Calling `pauseBGM()` then `resumeBGM()` continues from the paused timestamp. Toggling `isMuted` silences and restores all audio.

---

### Story 10: Implement graceful failure isolation across all public APIs

**Acceptance Criteria:**

- [ ] Every public method on `AudioManager` is non-throwing — no `throws` keyword on any public function signature.
- [ ] All `AVAudioPlayer` creation, preparation, and playback calls wrapped in `do/catch` or use optional chaining.
- [ ] All `AVAudioSession` configuration calls wrapped in `do/catch`.
- [ ] Failures logged via `os.Logger` with `OSLog` subsystem under `#if DEBUG` only. No `print` statements.
- [ ] No audio failure propagates to views, FlowCoordinator, or chapter completion logic.
- [ ] `AudioManager` continues to accept API calls after a failure — subsequent calls may succeed if the underlying issue resolves.
- [ ] Zero force unwraps (`!`) in the entire file.
- [ ] Zero implicitly unwrapped optionals except where Apple API requires.

**Dependencies:** AUDIO_01-S1 through AUDIO_01-S9
**Completion Signal:** Calling `playSFX(named: "nonexistent_file")` does not crash, does not throw, and logs a debug message. Calling `crossFadeToBGM(named: "nonexistent")` degrades gracefully. All subsequent API calls remain functional.

---

### Story 11: Validate governance compliance and build

**Acceptance Criteria:**

- [ ] Zero force unwraps (`!`) in `AudioManager.swift`.
- [ ] Zero `print` statements — all diagnostics use `os.Logger` under `#if DEBUG`.
- [ ] Zero deprecated API usage (`ObservableObject`, `@Published`, `@StateObject`, `DispatchQueue`, `Combine`).
- [ ] Zero Combine imports.
- [ ] Zero AI attribution artifacts (Protocol Zero compliance).
- [ ] Zero magic numbers — all tuning values (fade duration, loop count) as named constants.
- [ ] `import AVFoundation` and `import os` as the only framework imports beyond Foundation.
- [ ] `AudioManager.swift` is the sole file in `Managers/` (`.gitkeep` removed if present).
- [ ] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0.
- [ ] `python3 scripts/audit.py --all` passes with zero violations.
- [ ] File registered in `project.pbxproj` — PBXFileReference, PBXBuildFile, PBXGroup, and PBXSourcesBuildPhase entries present.

**Dependencies:** AUDIO_01-S1 through AUDIO_01-S10
**Completion Signal:** Clean build with zero errors. Audit script passes 7/7 checks. `AudioManager.swift` compiles and is linkable from any chapter view or coordinator.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| AVAudioSession.setCategory fails on simulator (no audio hardware) | 2 | 3 | 6 | Graceful degradation with `sessionConfigured` flag. Build validates on generic simulator destination; runtime audio tested on device in PH-16. | iOS Engineer |
| CADisplayLink-based volume interpolation introduces jitter on cross-fade | 3 | 2 | 6 | Volume steps at 120Hz (8.3ms intervals) are imperceptible. Fallback to linear interpolation with coarser Timer if CADisplayLink proves problematic. | iOS Engineer |
| AVAudioPlayer.prepareToPlay() blocks main thread for large files | 3 | 2 | 6 | BGM files are ~8-12MB AAC (hardware decoded). `prepareToPlay()` decodes PCM buffers synchronously but completes in <200ms per Design-Doc §7.9.2. Acceptable during pre-load phase behind Chapter 1 interaction. | iOS Engineer |
| Cross-fade called rapidly creates orphaned players | 2 | 2 | 4 | Cancel in-progress fade before starting new one. Stop and nil outgoing player explicitly. Player count bounded to 2 BGM + N SFX. | iOS Engineer |
| @MainActor isolation prevents notification callbacks from mutating state | 4 | 2 | 8 | Notification callbacks dispatch to @MainActor via `Task { @MainActor in }`. NotificationCenter observation uses the injected center for testability. | iOS Engineer |

---

## Definition of Done

- [ ] All 11 stories completed and individually verified.
- [ ] `AudioManager` compiles as `@Observable @MainActor final class` with `static let shared`.
- [ ] `AVAudioSession` configured with `.playback` category, no `.mixWithOthers`.
- [ ] Dual-player cross-fade executes in 500ms with no audible gap.
- [ ] SFX playback operates independently of BGM cross-fade.
- [ ] `preloadAssets()` caches prepared players for all provided identifiers.
- [ ] Interruption notification pauses on `.began`, resumes on `.ended` with `.shouldResume`.
- [ ] Route change pauses on headphone disconnect.
- [ ] `CACurrentMediaTime()`-based timing API returns accurate playback timestamps.
- [ ] Zero force unwraps, zero print statements, zero deprecated APIs, zero Combine usage.
- [ ] `xcodebuild build` succeeds with zero errors.
- [ ] `scripts/audit.py --all` passes with zero violations.
- [ ] No AI attribution artifacts (Protocol Zero).
- [ ] File registered in `project.pbxproj` with all required build phase entries.

## Exit Criteria

- [ ] All Definition of Done conditions satisfied.
- [ ] `AudioManager.swift` exists at `StarlightSync/Managers/AudioManager.swift` as a fully compilable singleton.
- [ ] PH-05 (Asset Pre-load Pipeline) is unblocked — `preloadAssets()` API is callable.
- [ ] PH-07 through PH-13 (all chapters) are unblocked — `playSFX()` and `crossFadeToBGM()` APIs are callable.
- [ ] PH-14 (Cross-Chapter Transitions) is unblocked — cross-fade API is callable from FlowCoordinator transition logic.
- [ ] Epic ID `AUDIO_01` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
