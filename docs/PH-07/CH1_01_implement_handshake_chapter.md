# Epic: CH1_01 — Implement Chapter 1: The Handshake

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | CH1_01                         |
| **Epic Name** | implement_handshake_chapter    |
| **Phase**     | PH-07                          |
| **Domain**    | CH1                            |
| **Owner**     | iOS Engineer                   |
| **Status**    | Complete                       |

---

## Problem Statement

The walking skeleton (PH-02) established `HandshakeView.swift` as a placeholder containing a "Complete Chapter" button and static text labels. This placeholder provides no immersive experience — it lacks the OLED-black atmosphere, pulsing fingerprint glyph, 3-second long-press capacitor charge interaction, CoreHaptics feedback, SFX completion thud, and CRT power-on transition defined in Design Doc §3.2. Without replacing this placeholder, the app cannot deliver the opening moment of the Starlight Sync narrative: the first physical connection between Carolina and the device.

Chapter 1 also serves a critical architectural function. The 3-second long-press interaction masks the asset pre-load phase (§7.9.2). `AssetPreloadCoordinator.preloadAllAssets()` runs concurrently during Chapter 1 via the `.task` modifier on `ChapterRouterView` in `StarlightSyncApp.swift`. The pre-load completes in ~1.1 seconds, well within the 3-second hold window. Without a real long-press interaction, the pre-load mask is inactive and the walking skeleton's instant "Complete Chapter" button bypasses the loading window entirely.

Additionally, the `CRTTransitionView` component (§8 structure: `Components/CRTTransitionView.swift`) does not exist. This reusable component implements the CRT turn-on effect — a scanline overlay with vertical sweep and brightness ramp — required as Chapter 1's exit transition. Without it, the transition from Chapter 1 to the game narrative has no visual punctuation.

---

## Goals

- Replace the `HandshakeView` placeholder with a production-quality SwiftUI view implementing Design Doc §3.2 in its entirety: OLED-black background, `img_bg_intro` asset, pulsing `touchid` SFSymbol, 3-second long-press with visual progress feedback, `capacitor_charge.ahap` haptic during hold, `sfx_haptic_thud` on completion snap, CRT turn-on exit transition, and `FlowCoordinator` chapter advancement.
- Create `CRTTransitionView.swift` in `Components/` as a self-contained, parameterized transition component implementing the CRT power-on effect (scanline overlay, center-out vertical sweep, brightness ramp) with chapter-specific animation timing.
- Start `audio_bgm_main` BGM loop on Chapter 1 completion, establishing the continuous music that persists through Chapters 2–5 per Design Doc §7.4 component dependencies.
- Implement Reduce Motion fallback per Design Doc §12.2: replace CRT turn-on with a simple cross-fade when `UIAccessibility.isReduceMotionEnabled` is true.
- Ensure all timing values reference `GameConstants.Timing` and all asset identifiers reference `GameConstants` type-safe enums — zero magic numbers, zero stringly-typed access.

## Non-Goals

- **No modifications to FlowCoordinator, AudioManager, HapticManager, or AssetPreloadCoordinator.** These components are complete (PH-02 through PH-05). HandshakeView consumes their public APIs only. If an API gap is discovered, it is documented as a blocking issue, not resolved within this epic.
- **No modifications to GameConstants.** All required constants (`handshakeHoldDuration`, `capacitorCharge`, `sfxThud`, `BackgroundAsset.intro`) already exist from CONST_01.
- **No cross-chapter transition orchestration.** The `matchedGeometryEffect` spatial transitions and BGM cross-fade on chapter-to-chapter boundaries are PH-14 scope. This epic starts `audio_bgm_main` on completion but does not implement cross-fade to Chapter 2's theme.
- **No unit tests for HandshakeView or CRTTransitionView.** UI-layer views are validated by on-device QA (PH-16), not XCTest unit tests per §13.1 coverage matrix.
- **No custom Metal shaders.** The CRT effect uses pure SwiftUI composition (ZStack layering, geometry transforms, opacity animation). Metal shader-based scanlines are an over-engineering risk for a single transition effect.

---

## Technical Approach

**HandshakeView** replaces the placeholder at `StarlightSync/Chapters/Chapter1_Handshake/HandshakeView.swift`. The view reads `FlowCoordinator` from the SwiftUI environment via `@Environment(FlowCoordinator.self)`. The background layers `img_bg_intro` from the asset catalog (a near-black HEIC with faint purple glow) behind a centered `touchid` SFSymbol rendered at 60pt+ with chapter-specific neon purple color and a pulsing opacity/scale animation. The pulsing animation uses a custom `Animation.easeInOut` variant with asymmetric timing to create a breathing rhythm — not `.default` or bare `.linear` per CLAUDE.md §4.2 animation rules.

The long-press interaction uses SwiftUI's `.onLongPressGesture(minimumDuration:maximumDistance:pressing:perform:)` modifier. The `pressing` callback (`onPressingChanged`) drives an `@State` progress variable from 0.0 to 1.0 over `GameConstants.Timing.handshakeHoldDuration` (3 seconds) using a `TimelineView(.animation)` tick source — no `Timer`, no `DispatchQueue`, no `Task.sleep` per CLAUDE.md §4.1. A circular progress ring (`Circle().trim(from:to:)`) surrounding the fingerprint glyph fills proportionally to the progress value, providing continuous visual feedback during the hold. On finger lift before completion, progress resets to zero.

Haptic feedback during the hold uses `HapticManager.shared.play(GameConstants.HapticAsset.capacitorCharge.rawValue)`, which triggers the `capacitor_charge.ahap` pattern — a 2.6-second continuous event with exponential intensity ramp (0.1→0.9) and a terminal transient snap at 2.8 seconds (authored in ASSET_04). The AHAP pattern duration (2.8s) is slightly shorter than the gesture duration (3.0s), providing a natural timing alignment where the "snap" event precedes the visual completion by ~200ms, creating a perceptual cause-and-effect rhythm. If the user lifts their finger before 3 seconds, haptic playback is not explicitly stopped — `CHHapticPatternPlayer` instances are transient and self-terminate when the pattern completes per CLAUDE.md §4.4. On gesture cancel, only the visual progress resets.

On completion, three actions fire in sequence: (1) `AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxThud.rawValue)` for the bass-heavy thud, (2) the CRT transition begins, and (3) after the CRT animation completes, `AudioManager.shared.crossFadeToBGM(named: GameConstants.AudioAsset.bgmMain.rawValue)` starts the main BGM loop, followed by `coordinator.completeCurrentChapter()` to advance to Chapter 2.

**CRTTransitionView** is a self-contained SwiftUI component at `StarlightSync/Components/CRTTransitionView.swift`. It accepts a `Binding<Bool>` trigger and an `onComplete` closure. The effect is composed as a `ZStack` with three layers: (1) a content layer (the revealed view) with animated opacity (0→1 over 0.4s), (2) a vertical sweep mask using `scaleEffect(y:)` animating from 0.003 to 1.0 with a custom `timingCurve` that eases in sharply then decelerates, and (3) a scanline overlay — thin horizontal rectangles at 3pt intervals with 0.08 opacity using `.blendMode(.overlay)` that fades in during the sweep. The total animation duration is ~0.6 seconds. All timing values are defined as named `private` constants within the component — not in `GameConstants`, as CRT timing is view-internal and not a game tuning value. The scanline overlay uses `Canvas` for efficient drawing at 120fps.

Reduce Motion detection reads `@Environment(\.accessibilityReduceMotion)`. When enabled: the pulsing fingerprint animation is replaced with a static glow (fixed opacity, no scale animation), and the CRT transition is replaced with a 0.4-second opacity cross-fade — preserving emotional weight through the brightness reveal without vestibular-triggering motion per Design Doc §12.2.

Both `HandshakeView` and `CRTTransitionView` include `#Preview` macros. View body complexity is managed to stay within the 80-line limit per CLAUDE.md §4.2 by extracting the fingerprint glyph, progress ring, and transition trigger logic into computed properties or private helper methods within the view file.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| `FlowCoordinator` with `completeCurrentChapter()` API and `@Environment` injection | COORD_01, COORD_02 (PH-02) | Complete | iOS Engineer |
| `GameConstants.Timing.handshakeHoldDuration` (3.0s), `GameConstants.AudioAsset.sfxThud`, `GameConstants.AudioAsset.bgmMain`, `GameConstants.HapticAsset.capacitorCharge`, `GameConstants.BackgroundAsset.intro` | CONST_01 (PH-06) | Complete | iOS Engineer |
| `HapticManager.shared.play(_:)` API with `capacitor_charge.ahap` cached | HAPTIC_01 (PH-04), ASSET_04 (PH-05) | Complete | iOS Engineer |
| `AudioManager.shared.playSFX(named:)` and `crossFadeToBGM(named:)` APIs with preloaded assets | AUDIO_01 (PH-03), ASSET_03 (PH-05) | Complete | iOS Engineer |
| `img_bg_intro` HEIC background in `Assets.xcassets/Backgrounds/` | ASSET_01 (PH-05) | Complete | iOS Engineer |
| `AssetPreloadCoordinator` launch integration masking load behind Chapter 1 interaction | ASSET_02 (PH-05) | Complete | iOS Engineer |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| Chapter 1 complete — validates CRT transition pattern | PH-08 (Chapter 2 Packet Run) | CRT effect establishes the visual transition language; Chapter 2 is the next sequential chapter |
| `CRTTransitionView` reusable component available | PH-14 (Cross-Chapter Transitions) | Shared component in `Components/` available for potential reuse in cross-chapter transition polish |
| BGM playback initiated from Chapter 1 completion | PH-08 through PH-11 | `audio_bgm_main` loop begins on Chapter 1 completion and persists through Chapters 2–5 |
| Chapter 1 placeholder replaced — full narrative entry point functional | PH-16 (On-Device QA) | QA playtest can begin from a real Chapter 1 experience instead of a skeleton button |

---

## Stories

### Story 1: Implement OLED background with pulsing fingerprint glyph

Replace the `HandshakeView` placeholder body with the atmospheric Chapter 1 visual composition: `img_bg_intro` HEIC background stretched edge-to-edge, a centered `touchid` SFSymbol at 60pt+ with chapter-specific neon purple color (`ch1_` namespace convention), and a breathing pulse animation using a custom asymmetric timing curve.

**Acceptance Criteria:**

- [x] `HandshakeView.swift` body renders `Image(GameConstants.BackgroundAsset.intro.rawValue)` as a full-bleed background, ignoring safe area.
- [x] A `touchid` SFSymbol is centered on screen at ≥60pt size with a chapter-specific color (not `Color.blue`, `Color.purple`, or any default system color — a custom neon purple defined inline or via `GameConstants`).
- [x] The glyph pulses with a repeating, auto-reversing animation using a custom timing curve (not bare `.easeInOut`, `.linear`, or `.default` as the sole curve).
- [x] Pulse animation modulates opacity (e.g., 0.4→1.0) and/or scale (e.g., 0.95→1.05) to create a breathing rhythm.
- [x] Background color behind the image is true OLED black (`Color(red: 0, green: 0, blue: 0)` or `Color.black`) — no near-black approximations.
- [x] No default system colors used as primary visual elements.
- [x] `@Environment(\.accessibilityReduceMotion)` is read. When `true`, the pulse animation is replaced with a static glow (fixed elevated opacity, no scale modulation).
- [x] `#Preview` macro is present and renders correctly.

**Dependencies:** None
**Completion Signal:** HandshakeView renders a pulsing fingerprint glyph on OLED black with the `img_bg_intro` background. The placeholder "Complete Chapter" button and text labels are removed.

---

### Story 2: Implement long-press gesture with visual progress ring

Add a 3-second long-press gesture to the fingerprint glyph with a continuous visual progress indicator. The progress ring fills proportionally during the hold and resets on early release.

**Acceptance Criteria:**

- [x] `.onLongPressGesture(minimumDuration:maximumDistance:pressing:perform:)` is applied with `minimumDuration` set to `GameConstants.Timing.handshakeHoldDuration`.
- [x] `pressing` callback (`onPressingChanged`) updates an `@State var isPressing: Bool` to drive progress tracking.
- [x] An `@State var holdProgress: CGFloat` tracks 0.0→1.0 fill driven by a `TimelineView(.animation)` tick source — not `Timer`, `DispatchQueue.asyncAfter`, or `Task.sleep`.
- [x] A circular progress ring (`Circle().trim(from: 0, to: holdProgress)`) surrounds the fingerprint glyph, filling clockwise during the hold.
- [x] Progress ring uses a chapter-specific color (matching or complementing the glyph color) with a `.stroke(lineWidth:)` appropriate for the glyph size.
- [x] On finger lift before 3 seconds (`isPressing` becomes `false` before completion): `holdProgress` resets to 0.0 with a brief ease-out animation.
- [x] On successful completion (3s reached): `holdProgress` equals 1.0, triggering the completion sequence (Story 5).
- [x] `maximumDistance` parameter allows reasonable finger drift (~50pt) without canceling the gesture.
- [x] When Reduce Motion is enabled, progress ring still fills (opacity animation is acceptable under Reduce Motion — it is the pulse and CRT that are motion-sensitive).

**Dependencies:** CH1_01-S1 (glyph and background must exist)
**Completion Signal:** Long-pressing the fingerprint for 3 seconds fills a progress ring from empty to full. Releasing early resets the ring. No haptic or audio feedback yet.

---

### Story 3: Wire capacitor_charge haptic pattern to long-press hold lifecycle

Trigger the `capacitor_charge.ahap` pattern on gesture start via `HapticManager`, providing tactile feedback that ramps in intensity during the 3-second hold. The AHAP pattern's 2.8-second duration aligns naturally with the 3.0-second gesture, with the terminal "snap" transient preceding visual completion.

**Acceptance Criteria:**

- [x] When `isPressing` becomes `true`, `HapticManager.shared.play(GameConstants.HapticAsset.capacitorCharge.rawValue)` is called.
- [x] The haptic pattern begins immediately on finger contact and ramps in intensity per the `capacitor_charge.ahap` pattern (continuous event 0.1→0.9 intensity over 2.6s, terminal transient snap at 2.8s).
- [x] On finger lift before 3 seconds, no explicit haptic stop is needed — `CHHapticPatternPlayer` is transient and self-terminates at pattern end per CLAUDE.md §4.4.
- [x] If `HapticManager.shared.engineAvailable` is `false`, the call is a silent no-op — no crash, no error propagation to the UI.
- [x] No direct `CHHapticEngine` access from `HandshakeView` — all haptic playback routes through `HapticManager` exclusively per CLAUDE.md §4.4.
- [x] No `Timer`, `DispatchQueue`, or `Task.sleep` for haptic timing. The AHAP file defines its own internal timeline.

**Dependencies:** CH1_01-S2 (long-press gesture must exist to provide `isPressing` state)
**Completion Signal:** Holding the fingerprint for 3 seconds produces a ramping capacitor charge haptic pattern culminating in a transient snap. Releasing early stops the visual but the haptic pattern continues to its natural end (acceptable — AHAP is fire-and-forget).

---

### Story 4: Implement CRT turn-on transition component

Create `CRTTransitionView.swift` in `Components/` as a self-contained SwiftUI component that simulates a CRT monitor powering on. The effect layers a vertical sweep, brightness ramp, and scanline overlay into a cohesive ~0.6-second transition.

**Acceptance Criteria:**

- [x] File created at `StarlightSync/Components/CRTTransitionView.swift`.
- [x] `CRTTransitionView` is a `struct` conforming to `View`.
- [x] Accepts parameters: `isActive: Binding<Bool>` (triggers the transition) and `onComplete: @escaping () -> Void` (fires after the animation finishes).
- [x] When `isActive` becomes `true`, the transition sequence begins:
  - A thin horizontal line at the vertical center expands to full height via `scaleEffect(y:)` animating from a near-zero value to 1.0 with a custom `timingCurve` (not bare `.easeInOut` or `.linear`).
  - Content opacity animates from 0.0 to 1.0, slightly delayed behind the vertical sweep.
  - A scanline overlay (thin horizontal lines at ~3pt intervals, ~0.08 opacity) fades in during the sweep using `Canvas` for 120fps-efficient rendering.
- [x] Total animation duration is between 0.4s and 0.8s. All timing values are `private` named constants within the file (not `GameConstants` — CRT timing is view-internal).
- [x] `onComplete` closure fires after the animation finishes, not during. Timing uses `withAnimation` completion or a `.onAnimationCompleted` equivalent (e.g., `DispatchQueue.main.asyncAfter` is prohibited — use SwiftUI animation timing or `Task` with `try await Task.sleep` is also prohibited — use `.onChange` with state tracking).
- [x] No `.blur()` modifier in the overlay (expensive at 120fps).
- [x] `#Preview` macro present with a triggerable preview.
- [x] View body ≤80 lines.
- [x] No force unwraps. No `print` statements.

**Dependencies:** None (self-contained component)
**Completion Signal:** `CRTTransitionView` renders a CRT power-on effect when triggered: vertical sweep from center, brightness ramp, and scanline overlay. `onComplete` fires after the animation.

---

### Story 5: Wire completion sequence — SFX, BGM start, CRT transition, and FlowCoordinator advancement

Connect the long-press completion event to the full Chapter 1 exit sequence: thud SFX, CRT transition, BGM start, and coordinator advancement. The sequence is ordered to create a deliberate cause-and-effect rhythm.

**Acceptance Criteria:**

- [x] On long-press completion (3s reached), the following sequence executes:
  1. `AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxThud.rawValue)` fires immediately — the bass-heavy thud punctuates the capacitor snap.
  2. `@State var showCRTTransition` is set to `true`, triggering `CRTTransitionView`.
  3. In `CRTTransitionView`'s `onComplete` callback:
     - `AudioManager.shared.crossFadeToBGM(named: GameConstants.AudioAsset.bgmMain.rawValue)` starts the main BGM loop.
     - `coordinator.completeCurrentChapter()` advances to Chapter 2.
- [x] The thud SFX and CRT transition fire in the same frame — no artificial delay between them.
- [x] `audio_bgm_main` begins after the CRT transition completes, not during. The BGM start coincides with the next chapter becoming visible.
- [x] `completeCurrentChapter()` is called exactly once. No double-fire on rapid interaction.
- [x] If `AudioManager` fails to play the SFX (e.g., session not configured), the CRT transition and coordinator advancement still proceed — audio failure does not block progression per CLAUDE.md §4.5.
- [x] If `HapticManager` engine is unavailable, the completion sequence still fires — haptic failure does not block progression per CLAUDE.md §4.4.
- [x] The long-press gesture is disabled after completion (prevent re-triggering during the CRT transition).

**Dependencies:** CH1_01-S2 (gesture completion event), CH1_01-S3 (haptic feedback during hold), CH1_01-S4 (CRT transition component)
**Completion Signal:** Completing the 3-second hold produces: thud SFX → CRT power-on effect → BGM starts → FlowCoordinator advances to Chapter 2. The full sequence plays end-to-end without interruption.

---

### Story 6: Implement Reduce Motion accessibility fallback

When `UIAccessibility.isReduceMotionEnabled` is `true`, replace all motion-heavy effects with accessible alternatives that preserve emotional weight through opacity and color rather than spatial movement.

**Acceptance Criteria:**

- [x] `@Environment(\.accessibilityReduceMotion) private var reduceMotion` is declared in `HandshakeView`.
- [x] When `reduceMotion` is `true`:
  - Fingerprint glyph pulse animation is replaced with a static elevated opacity (no scale modulation, no repeating animation) per Design Doc §12.2.
  - Progress ring still fills during hold (opacity-based progress is not motion-sensitive).
  - CRT turn-on effect is replaced with a simple opacity cross-fade (0.4s duration) per Design Doc §12.2: "The CRT turn-on effect in Chapter 1 is replaced with a simple fade-in."
- [x] `CRTTransitionView` accepts the Reduce Motion state (either via environment or parameter) and internally switches between CRT sweep and cross-fade.
- [x] The completion sequence (SFX, BGM, coordinator advancement) is identical regardless of Reduce Motion state — only the visual transition changes.
- [x] Both code paths (CRT and cross-fade) fire `onComplete` after the transition finishes.
- [x] `#Preview` macro tests both Reduce Motion on and off states (two preview variants or a toggle).

**Dependencies:** CH1_01-S1 (glyph pulse), CH1_01-S4 (CRT component), CH1_01-S5 (completion sequence)
**Completion Signal:** With Reduce Motion enabled in system settings: fingerprint does not pulse (static glow), and the CRT effect is replaced with a cross-fade. With Reduce Motion disabled: full CRT effect plays. Both paths complete the chapter identically.

---

### Story 7: Register CRTTransitionView in pbxproj and validate full governance compliance

Register the new `CRTTransitionView.swift` source file in `project.pbxproj` and validate that the complete Chapter 1 implementation passes all governance checks.

**Acceptance Criteria:**

- [x] `CRTTransitionView.swift` has a `PBXFileReference` entry in `project.pbxproj` (new file — requires new UUID).
- [x] A `PBXBuildFile` entry references the `CRTTransitionView.swift` file reference.
- [x] The file reference is listed in the Components `PBXGroup` children array.
- [x] The build file is listed in the `PBXSourcesBuildPhase` files array.
- [x] `HandshakeView.swift` already has pbxproj registration from COORD_02 — no new registration needed for the modified file.
- [x] Components directory `.gitkeep` removed if present (replaced by real source file).
- [x] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0, zero errors, zero warnings.
- [x] `python3 scripts/audit.py --all` passes with zero violations (7/7 checks: PZ-001, FU-001, DA-001, DP-001, SL-001, CC-001, CB-001).
- [x] No Protocol Zero violations in either file — no AI attribution in headers, comments, or identifiers.
- [x] No force unwraps (`!`) in either file.
- [x] No `print` statements in either file. Diagnostics use `os.Logger` gated behind `#if DEBUG`.
- [x] No Combine imports or `ObservableObject`/`@Published`/`@StateObject`/`@EnvironmentObject` usage.
- [x] No deprecated APIs.
- [x] `HandshakeView` body ≤80 lines. `CRTTransitionView` body ≤80 lines.
- [x] `#Preview` macros present on both `HandshakeView` and `CRTTransitionView`.
- [x] All animation timing values are named constants (no magic numbers).
- [x] All asset references use `GameConstants` type-safe enums (no string literals for asset identifiers).

**Dependencies:** CH1_01-S1 through CH1_01-S6 (all implementation stories complete)
**Completion Signal:** Clean build with zero errors and zero warnings. Audit passes 7/7. Both files registered in pbxproj. All governance rules satisfied. PH-07 is ready for on-device validation.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| `onLongPressGesture` `pressing` callback does not fire frequently enough for smooth progress ring updates | 3 | 2 | 6 | `pressing` fires only on state transitions (true/false), not continuously. Progress is driven by `TimelineView(.animation)` which ticks at display refresh rate (120fps on ProMotion). The gesture callback starts/stops the progress accumulation; the timeline drives the animation. | iOS Engineer |
| `capacitor_charge.ahap` pattern duration (2.8s) misaligns perceptually with 3.0s gesture duration | 2 | 2 | 4 | The 200ms gap between haptic snap (2.8s) and visual completion (3.0s) is intentional — the snap precedes the visual, creating anticipation. If perceptually wrong, the AHAP timing is tunable in PH-16 QA. | iOS Engineer |
| CRT scanline overlay `Canvas` drawing causes frame drops on 120fps ProMotion | 3 | 2 | 6 | Scanlines are static geometry (horizontal rectangles at fixed intervals) drawn once and composited via blend mode. No per-frame path recomputation. If frame drops occur, reduce scanline count or switch to a pre-rendered `Image` overlay. Validate in PH-16 Instruments trace. | iOS Engineer |
| `CRTTransitionView` `onComplete` fires at wrong time due to SwiftUI animation completion detection limitations | 3 | 3 | 9 | SwiftUI does not have a native `onAnimationCompleted` modifier. Use a `withAnimation` block with explicit duration, then set a delayed state change via `.onChange` monitoring the animated property reaching its target value. Alternatively, use `Transaction` inspection. Test both Reduce Motion paths for correct firing. | iOS Engineer |
| View body exceeds 80-line limit due to gesture + animation + transition composition complexity | 2 | 3 | 6 | Extract fingerprint glyph, progress ring, and completion logic into `private` computed properties or `@ViewBuilder` methods within the same file. The 80-line limit applies to the `body` computed property, not the entire file. | iOS Engineer |

---

## Definition of Done

- [x] All 7 stories completed and individually verified.
- [x] `HandshakeView.swift` replaces the PH-02 placeholder with full Chapter 1 implementation per Design Doc §3.2.
- [x] `CRTTransitionView.swift` exists at `Components/CRTTransitionView.swift` with `#Preview` macro.
- [x] Long-press gesture requires exactly `GameConstants.Timing.handshakeHoldDuration` (3.0s) to complete.
- [x] `capacitor_charge.ahap` haptic plays during hold via `HapticManager.shared.play(_:)`.
- [x] `sfx_haptic_thud` SFX plays on completion via `AudioManager.shared.playSFX(named:)`.
- [x] `audio_bgm_main` BGM starts after CRT transition via `AudioManager.shared.crossFadeToBGM(named:)`.
- [x] `FlowCoordinator.completeCurrentChapter()` advances to Chapter 2 after transition completes.
- [x] CRT turn-on effect animates on completion with scanline overlay, vertical sweep, and brightness ramp.
- [x] Reduce Motion enabled: pulse replaced with static glow, CRT replaced with cross-fade (Design Doc §12.2).
- [x] All asset references use `GameConstants` type-safe enums — zero string literals for asset identifiers.
- [x] All timing values are named constants — zero magic numbers.
- [x] `xcodebuild build` succeeds with zero errors and zero warnings.
- [x] `scripts/audit.py --all` passes with zero violations (7/7 checks).
- [x] No Protocol Zero violations.
- [x] No force unwraps, no `print` statements, no Combine, no deprecated APIs.
- [x] Both view files have `#Preview` macros. Both view bodies ≤80 lines.
- [x] `CRTTransitionView.swift` registered in all 4 required `project.pbxproj` sections.

## Exit Criteria

- [x] All Definition of Done conditions satisfied.
- [x] PH-08 (Chapter 2) is unblocked — Chapter 1 completes and advances to Chapter 2, BGM is playing.
- [x] PH-14 (Cross-Chapter Transitions) is unblocked — `CRTTransitionView` component exists in `Components/`.
- [x] PH-16 (On-Device QA) can begin Chapter 1 testing — haptic pattern feel, CRT timing, long-press duration.
- [x] Asset pre-load masking validated — 3-second hold provides sufficient time for `AssetPreloadCoordinator` to complete.
- [x] Epic ID `CH1_01` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
