# Epic: CH3_01 — Implement Chapter 3: The Cipher

## Metadata

| Field         | Value                        |
| ------------- | ---------------------------- |
| **Epic ID**   | CH3_01                       |
| **Epic Name** | implement_cipher_chapter     |
| **Phase**     | PH-09                        |
| **Domain**    | CH3                          |
| **Owner**     | iOS Engineer                 |
| **Status**    | **COMPLETE**                 |

---

## Problem Statement

The walking skeleton (PH-02) established `CipherView.swift` as a placeholder containing a "Complete Chapter" button and static title labels. This placeholder provides no puzzle experience — it lacks the Cryptex scroll wheel interface, brushed metal/glass visual treatment, segment-level scroll interaction with snap-to-position behavior, per-tick haptic click feedback, heavy thud confirmation on correct segment alignment, scrambled phrase validation logic, and the Auto-Assist difficulty adaptation defined in Design Doc §3.4. Without replacing this placeholder, the app cannot deliver the narrative's third chapter — the metaphor of "we have our own language" that Carolina solves through a physically tactile Cryptex interaction.

Chapter 3 is the first SwiftUI-only puzzle chapter in the Starlight Sync arc. Unlike the SpriteKit chapters (2 and 4), the Cipher requires no `SKScene` lifecycle management, no physics engine, and no frame-rate-dependent logic. Instead, it exercises a different architectural pattern: custom gesture-driven SwiftUI components with granular haptic feedback synchronized to user interaction, coordinated across multiple independent scroll wheel instances. The `CipherWheelView` component is the chapter's primary technical artifact — a reusable, haptic-aware scroll drum that delivers the tactile Cryptex sensation through `DragGesture`, spring animations, and dual-channel feedback (audio click + haptic transient) on every segment boundary crossing.

The Cipher's validation logic (correct segment matching, incorrect attempt counting, Auto-Assist activation at threshold) is explicitly called out in the unit test coverage matrix (CLAUDE.md §7.1, Design Doc §13.1). Unlike SpriteKit chapters where game logic is validated via on-device QA only, the Cipher's validation logic is pure Swift state that PH-15 (Unit Test Suite) will exercise via `XCTest`. This means the validation model must be cleanly separated from view code — callable in isolation without SwiftUI dependencies.

---

## Goals

- Replace the `CipherView` placeholder with a production-quality Cryptex puzzle experience implementing Design Doc §3.4 in its entirety: brushed metal/glass visual treatment over `img_bg_cipher` background, three vertically arranged segment scroll wheels for "THIS IS" / "CRIMINAL" / "BEHAVIOUR", haptic click per scroll tick (`sfx_click` + inline `CHHapticEvent`), heavy thud on correct segment alignment (`thud.ahap` + `sfx_haptic_thud`), win condition (all three wheels correctly aligned), and Auto-Assist glow hint after 3 incorrect submissions per Design Doc §3.8.
- Create `CipherWheelView.swift` as a self-contained scroll wheel component at `Chapters/Chapter3_Cipher/CipherWheelView.swift` with custom `DragGesture`-driven vertical scrolling, snap-to-position animation, cyclic wrapping, and per-tick haptic/audio feedback.
- Ensure the Cipher validation model (segment matching, attempt counting, Auto-Assist activation) is cleanly separable from view code for unit test consumption in PH-15 — the validation logic must be callable without SwiftUI imports.
- Render all wheel text in monospaced `SF Mono` font per Design Doc §7.7.
- Ensure all tuning values reference `GameConstants` namespace and all asset identifiers reference type-safe enums — zero magic numbers, zero stringly-typed access.

## Non-Goals

- **No modifications to FlowCoordinator, AudioManager, HapticManager, AssetPreloadCoordinator, or GameConstants.** These components are complete (PH-02 through PH-06). CipherView and CipherWheelView consume their public APIs only. If an API gap is discovered, it is documented as a blocking issue, not resolved within this epic.
- **No cross-chapter transition orchestration.** The `matchedGeometryEffect` spatial transitions and BGM cross-fade between chapters are PH-14 scope.
- **No unit tests within this epic.** Cipher validation logic is covered by PH-15 (Unit Test Suite) per CLAUDE.md §7.1 coverage matrix. This epic ensures the validation model is testable; PH-15 writes the tests.
- **No custom fonts beyond system SF Mono.** Design Doc §7.7 specifies SF Mono for cipher wheel text. The optional Clash Display / Monument Extended display font is not adopted for Chapter 3.
- **No SpriteKit.** Chapter 3 is a SwiftUI-only chapter per Design Doc §4.1 and CLAUDE.md §3.
- **No drag-and-drop or freeform gesture input.** The interaction is strictly vertical scroll-wheel segments with snap-to-position, not a freeform letter arrangement puzzle.
- **No chapter-specific AHAP patterns.** The `thud.ahap` pattern already exists (PH-05 ASSET_04). Per-tick haptic clicks use inline `CHHapticEvent` — no new AHAP file authoring.

---

## Technical Approach

**Wheel Architecture.** `CipherWheelView` is a self-contained SwiftUI view at `Chapters/Chapter3_Cipher/CipherWheelView.swift`. Each wheel renders a vertical strip of phrase segments with a single "active" segment visible in a central viewport, bordered by partially visible adjacent segments above and below. The visual effect simulates a cylindrical drum: segments away from center have reduced opacity and a subtle 3D rotation via `rotation3DEffect` around the X axis, proportional to their distance from the viewport center. The drum is clipped to a fixed height using `.clipped()`, showing approximately 3 segments — the selected center segment at full opacity with the adjacent segments at reduced opacity and perspective-rotated inward, creating the illusion of a curved metal barrel.

Scroll interaction uses a `DragGesture(minimumDistance: 0)` tracking vertical translation. A `@State private var dragOffset: CGFloat` accumulates the drag distance. During the drag, the segment strip translates vertically by `dragOffset`, providing direct-manipulation feedback with zero perceived latency — the research confirms that immediate visual response on touch-down is the primary driver of perceived responsiveness in gesture-driven interfaces. On drag end, the offset snaps to the nearest segment boundary using `withAnimation(.spring(response: 0.3, dampingFraction: 0.7))` — the spring curve simulates the physical inertia of a metal drum settling into position. The snap target is computed by rounding `dragOffset / segmentHeight` to the nearest integer, then clamping to the valid segment range. The current segment index is derived from the snap position. The wheel wraps cyclically: scrolling past the last segment loops to the first, and vice versa, preventing dead-ends and mimicking infinite drum rotation.

**Haptic Tick Feedback.** During the drag, a haptic click fires each time the scroll offset crosses a segment boundary. The view tracks the `previousSegmentIndex` and compares against the current segment index derived from `dragOffset` — when they differ, a new segment has been entered, and `AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxClick.rawValue)` fires simultaneously with an inline `CHHapticEvent(eventType: .hapticTransient, parameters: [intensity: 0.5, sharpness: 0.8], relativeTime: 0)` via `HapticManager`. This dual-channel feedback (audio click + haptic transient) per tick is the core tactile identity of the Cipher chapter. The input buffering pattern — detect segment transition, fire feedback, update tracking state — ensures exactly one haptic/audio event per crossing with no duplicates on boundary dwelling.

**Puzzle Data Model.** Each wheel receives an array of `String` segments and the index of the correct answer within that array. The segment arrays are defined as private constants within `CipherView` — not in `GameConstants`, as these are chapter-specific content data rather than tuning parameters, and GameConstants is locked (PH-06 complete, Non-Goals prohibit modification). Each wheel presents 5 segments (1 correct + 4 distractors). The correct answers are "THIS IS" (wheel 1), "CRIMINAL" (wheel 2), and "BEHAVIOUR" (wheel 3) per Design Doc §3.4. Distractor segments are stylistically similar phrase fragments that maintain the Cryptex illusion while providing non-trivial selection for a first-time user. The initial wheel positions are randomized on each chapter start to prevent positional memorization.

**Validation Flow.** The Cipher uses an explicit submission model: an "Unlock" action (visually styled as a Cryptex pull/release mechanism consistent with the brushed metal aesthetic) triggers validation of all three wheels simultaneously. This explicit submission model enables clean "incorrect attempt" counting per Design Doc §3.8 — each tap of "Unlock" is a discrete attempt, unambiguously countable. If all three wheels show their correct segment, the win sequence fires. If any wheel is incorrect, the Cryptex frame shakes horizontally (offset animation), and the incorrect attempt counter increments. The validation check itself is a pure function (`func isAllCorrect(selections: [Int], answers: [Int]) -> Bool`) that PH-15 can import and test without SwiftUI dependencies.

**Thud Confirmation.** Independently of the submission flow, each wheel fires `thud.ahap` via `HapticManager` and `sfx_haptic_thud` via `AudioManager` the moment it snaps to its correct segment after drag release. This per-wheel thud serves as a physical hint — the user can feel which segments are correct before submitting, mirroring the "click" in a real combination lock when a tumbler falls into place. The thud fires only on the snap-settle event (drag ended, spring animation targeting), not during mid-drag. The thud is noticeably heavier than the per-tick scroll click — distinct intensity and sharpness differentiate the two feedback types. If the user scrolls away from the correct segment and returns, the thud fires again on each re-settlement.

**Auto-Assist.** After `GameConstants.AutoAssist.cipherIncorrectThreshold` (3) incorrect submissions, Auto-Assist activates silently. Each wheel adds a subtle pulsing glow effect (a radial gradient overlay with low opacity, animated with a repeating ease-in-out) behind the correct segment. The glow is visible only when the correct segment is within the wheel's visible viewport — it does not reveal the answer if the user has scrolled far away, maintaining partial challenge while providing proximity guidance. Auto-Assist activation is silent — no banner, no text overlay, no sound effect — preserving the "illusion of skill and success" per Design Doc §3.8. Once active, Auto-Assist remains active for the session duration regardless of subsequent attempts.

**Visual Composition.** `CipherView` renders the full puzzle interface in a `ZStack` composition for atmospheric depth per CLAUDE.md §4.2: (1) `img_bg_cipher` as a full-bleed background image loaded from the asset catalog via `GameConstants.BackgroundAsset.cipher` — the asset is described as "extreme close-up of a high-tech bank vault door mechanism, brushed steel texture, glowing blue tumbler numbers" in Design Doc §7.2, providing the atmospheric context; (2) a central Cryptex container with simulated brushed metal framing using layered rectangles with linear gradients, subtle inner shadow depth, and rounded corners — no system material modifiers (`.regularMaterial`, `.ultraThinMaterial`) per CLAUDE.md §4.2; (3) three `CipherWheelView` instances arranged vertically within the frame with metallic divider lines between them; (4) the "Unlock" action element below the Cryptex; and (5) chapter context text ("We have our own language") as an ambient label with intentional asymmetric positioning. All colors are chapter-specific — no `Color.blue`, `Color.gray`, or system default colors as primary elements per CLAUDE.md §4.2. Spacing is intentional and asymmetric — no uniform `padding(16)` or `padding()`.

**Explicit Assumptions.** (1) The Cipher uses an explicit "Unlock" submission action rather than auto-detecting all-correct state. This interpretation derives from "3 incorrect attempts" (Design Doc §3.8) requiring a discrete, countable validation event. (2) Each wheel presents 5 segments (1 correct + 4 distractors); the Design Doc does not specify distractor count, and 5 provides sufficient variety without overwhelming the user. (3) Wheels wrap cyclically for physical Cryptex feel. (4) Puzzle segment data lives in chapter code as private constants, not in GameConstants. (5) FileRef/BuildFile IDs assume PH-08 has consumed FileRef 13 / BuildFile 12; adjust if PH-08 allocation differs.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| `FlowCoordinator` with `completeCurrentChapter()` API and `@Environment` injection | COORD_01, COORD_02 (PH-02) | Complete | iOS Engineer |
| `GameConstants.AutoAssist.cipherIncorrectThreshold` (3) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `GameConstants.AudioAsset.sfxClick` (`sfx_click`), `.sfxThud` (`sfx_haptic_thud`), `.sfxChime` (`sfx_success_chime`) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `GameConstants.HapticAsset.thud` (`thud.ahap`) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `GameConstants.BackgroundAsset.cipher` (`img_bg_cipher`) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `AudioManager.shared.playSFX(named:)` API with preloaded `sfx_click`, `sfx_haptic_thud`, `sfx_success_chime` assets | AUDIO_01 (PH-03), ASSET_03 (PH-05) | Complete | iOS Engineer |
| `HapticManager.shared.playPattern(named:)` API with cached `thud.ahap` pattern, and inline `CHHapticEvent` transient playback API | HAPTIC_01 (PH-04), ASSET_04 (PH-05) | Complete | iOS Engineer |
| `img_bg_cipher` HEIC background in `Assets.xcassets/Backgrounds/`, decoded and cached by `AssetPreloadCoordinator` | ASSET_01, ASSET_02 (PH-05) | Complete | iOS Engineer |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| Cipher validation logic (segment matching, attempt counting, Auto-Assist threshold) available as pure Swift for unit testing | PH-15 (Unit Test Suite) | Unit tests cover correct segment matching, incorrect attempt counting, and Auto-Assist activation at threshold per CLAUDE.md §7.1 and Design Doc §13.1 |
| Chapter 3 complete — sequential chapter progression via FlowCoordinator linear state machine | PH-10 (Chapter 4 Firewall) | Runtime: user must complete Chapter 3 to reach Chapter 4. No build dependency — PH-10 can be developed in parallel |
| Chapter 3 playable for on-device validation | PH-16 (On-Device QA) | QA playtest validates wheel feel, haptic click timing, thud confirmation, Auto-Assist activation, visual polish, and Reduce Motion fallback |
| Chapter 3 ready for cross-chapter transition polish | PH-14 (Cross-Chapter Transitions) | Transition animations, BGM cross-fade on chapter entry/exit, and multi-sensory redundancy verification |

---

## Stories

### Story 1: Create CipherWheelView with vertical segment scroll, snap-to-position, and haptic tick feedback

Create `CipherWheelView.swift` as a reusable SwiftUI component that renders a single Cryptex scroll wheel. The wheel displays phrase segments in a vertical drum layout with 3D perspective rotation. A `DragGesture` drives vertical scrolling, and the wheel snaps to the nearest segment on release. Each segment boundary crossing triggers an audio click and haptic transient.

**Acceptance Criteria:**

- [x] File created at `StarlightSync/Chapters/Chapter3_Cipher/CipherWheelView.swift`.
- [x]`CipherWheelView` accepts parameters: `segments: [String]` (the phrase segments to display), `correctIndex: Int` (index of the correct segment), and a `@Binding var selectedIndex: Int` (the currently snapped segment index).
- [x]Vertical drum layout: segments are arranged in a vertical strip. The center segment is fully visible at full opacity. Adjacent segments above and below are partially visible with reduced opacity and subtle `rotation3DEffect` around the X axis proportional to distance from center.
- [x]The wheel viewport is clipped to a fixed height showing approximately 3 segments (1 center + 2 partial) using `.clipped()`.
- [x]`DragGesture(minimumDistance: 0)` tracks vertical translation. A `@State private var dragOffset: CGFloat` accumulates the drag distance. The segment strip translates vertically during the drag, providing direct-manipulation feedback.
- [x]On drag end, the wheel snaps to the nearest segment boundary with a spring animation (`.spring(response: 0.3, dampingFraction: 0.7)` or equivalent named constant). The snap target is computed by rounding the accumulated offset to the nearest segment height multiple, clamped to valid segment range.
- [x]`selectedIndex` binding updates to the snapped segment index after the snap animation targets.
- [x]All segment text uses `SF Mono` font via `.font(.system(.title2, design: .monospaced))` or equivalent monospaced styling per Design Doc §7.7.
- [x]Each segment boundary crossing during drag fires `AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxClick.rawValue)` for the audio click.
- [x]Each segment boundary crossing during drag fires an inline haptic transient via `HapticManager` — a short, crisp click at moderate intensity (approximately `intensity: 0.5, sharpness: 0.8`).
- [x]Haptic and audio fire at most once per segment crossing — no repeated triggers while dwelling on the same boundary. Tracking uses a `previousSegmentIndex` comparison.
- [x]The wheel wraps cyclically: scrolling past the last segment loops to the first, and vice versa, preventing dead-ends and mimicking infinite drum rotation.
- [x]Segment height, animation spring parameters, opacity multipliers, and rotation angle multipliers are named constants (not magic numbers).
- [x]No `Timer`, `DispatchQueue`, `Task.sleep` for any timing.
- [x]No Combine, no `@Published`, no `ObservableObject`.
- [x]`#Preview` macro present on `CipherWheelView` with sample segment data.

**Dependencies:** None
**Completion Signal:** CipherWheelView renders a scrollable drum of phrase segments. Dragging vertically scrolls through segments with visible 3D rotation and opacity falloff. Releasing snaps to the nearest segment with spring animation. Each boundary crossing produces an audible click and haptic tick. The wheel wraps cyclically.

---

### Story 2: Create CipherView container with three-wheel Cryptex layout over cipher background

Replace the `CipherView` PH-02 placeholder with the full puzzle interface. Render `img_bg_cipher` as the full-bleed background. Position three `CipherWheelView` instances vertically within a brushed metal/glass Cryptex frame. Define the puzzle segment arrays and wire the wheel bindings.

**Acceptance Criteria:**

- [x]`CipherView.swift` body is replaced entirely — the placeholder `ZStack` with `Color.black`, `Text` labels, and `Button` are removed.
- [x]`@Environment(FlowCoordinator.self) private var coordinator` reads the coordinator from the SwiftUI environment.
- [x]`img_bg_cipher` renders as a full-bleed background using `Image(GameConstants.BackgroundAsset.cipher.rawValue)` with `.resizable()`, `.scaledToFill()`, and `.ignoresSafeArea()`.
- [x]Three `CipherWheelView` instances are arranged vertically within a central Cryptex container.
- [x]Each wheel receives its own segment array: 5 segments per wheel (1 correct + 4 distractors). Correct segments: "THIS IS" (wheel 1), "CRIMINAL" (wheel 2), "BEHAVIOUR" (wheel 3) per Design Doc §3.4.
- [x]Distractor segments are stylistically consistent phrase fragments that maintain the Cryptex illusion. Segment arrays and correct indices are defined as private constants within `CipherView`.
- [x]Initial `selectedIndex` for each wheel is randomized on chapter start (not always starting at index 0) to prevent positional memorization.
- [x]Metallic divider elements between wheels provide visual separation within the Cryptex frame.
- [x]The Cryptex frame uses layered SwiftUI composition — rectangles with linear gradients simulating brushed metal, subtle inner shadow overlays, and rounded corners — creating a convincing vault/lock aesthetic. No system material modifiers (`.regularMaterial`, `.ultraThinMaterial`) per CLAUDE.md §4.2.
- [x]`ZStack` composition provides atmospheric depth: background image → ambient overlay → Cryptex frame → wheels → highlight accents.
- [x]All colors are chapter-specific — no `Color.blue`, `Color.gray`, `Color.accentColor`, `Color.primary`, or system default colors as primary elements per CLAUDE.md §4.2.
- [x]Chapter context text ("We have our own language") renders as an ambient element — not a primary label, positioned with intentional asymmetric spacing per CLAUDE.md §4.2.
- [x]Pre-filled spaces between wheel segments are visually communicated through the vertical arrangement and inter-wheel spacing.
- [x]View body does not exceed 80 lines — extract subviews as private computed properties or separate `@ViewBuilder` methods as needed.
- [x]No UIKit imports, no `NavigationStack`, no `ScrollView` wrapping chapter content, no generic `VStack { Image; Text; Button }` layouts per CLAUDE.md §4.2.

**Dependencies:** CH3_01-S1 (CipherWheelView must exist)
**Completion Signal:** CipherView renders a visually polished Cryptex interface with three functional scroll wheels over the img_bg_cipher background. All wheels scroll independently with correct haptic/audio tick feedback. The Cryptex frame has depth, brushed metal texture, and layered composition. No validation logic yet — wheels spin freely.

---

### Story 3: Implement per-wheel correct alignment detection with thud haptic and SFX confirmation

Add thud feedback that fires when a wheel snaps to its correct segment after drag release. The thud uses `thud.ahap` via `HapticManager` and `sfx_haptic_thud` via `AudioManager`, providing a physical "tumbler falling into place" sensation distinct from the lighter per-tick scroll clicks.

**Acceptance Criteria:**

- [x]When `CipherWheelView` snaps to its `correctIndex` segment (after drag release, spring animation targeting), it fires `HapticManager.shared.playPattern(named: GameConstants.HapticAsset.thud.rawValue)` for the heavy thud haptic.
- [x]Simultaneously, `AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxThud.rawValue)` fires for the thud SFX.
- [x]The thud fires only on the snap-settle event — not during mid-drag scroll, and not when the user drags through the correct segment without stopping on it.
- [x]The thud fires every time the wheel settles on the correct segment — if the user scrolls away and returns, the thud fires again on each re-settlement.
- [x]If `HapticManager` fails to play the pattern (engine stalled or unsupported hardware), the SFX still plays — haptic failure does not block audio feedback per CLAUDE.md §4.4.
- [x]If `AudioManager` fails to play the SFX, the haptic still fires — audio failure does not block haptic feedback per CLAUDE.md §4.5.
- [x]The thud is noticeably heavier than the per-tick scroll click — distinct intensity and sharpness differentiate the two feedback types perceptually.
- [x]No direct `CHHapticEngine` or `AVAudioPlayer` access — all feedback routes through `HapticManager` and `AudioManager` per CLAUDE.md §4.4 and §4.5.

**Dependencies:** CH3_01-S1 (CipherWheelView with snap behavior), CH3_01-S2 (CipherView wiring wheels to segment data)
**Completion Signal:** Scrolling a wheel to the correct segment and releasing produces a distinct heavy thud (haptic + audio) clearly distinguishable from the lighter scroll clicks. Scrolling to an incorrect segment and releasing produces no thud — only the per-tick clicks fire during the scroll itself.

---

### Story 4: Implement submission validation, incorrect attempt tracking, and win condition with chapter completion

Add an "Unlock" action that validates all three wheels simultaneously. Track incorrect submission count. On all three wheels correct, fire the win sequence — `sfx_success_chime` plays and `FlowCoordinator.completeCurrentChapter()` advances to Chapter 4. On incorrect, provide error feedback and increment the attempt counter. Ensure validation logic is a pure function testable by PH-15.

**Acceptance Criteria:**

- [x]An "Unlock" action element renders below the Cryptex frame — visually styled as a lock mechanism or pull handle consistent with the brushed metal chapter aesthetic, with chapter-specific colors and intentional sizing. Not a default SwiftUI `Button` with system styling.
- [x]Tapping the Unlock action triggers simultaneous validation of all three wheel `selectedIndex` values against their respective `correctIndex` values.
- [x]The core validation check is implemented as a pure function or computed property (e.g., `func isAllCorrect(selections: [Int], answers: [Int]) -> Bool` or equivalent) that can be called from `XCTest` in PH-15 without SwiftUI imports. The view calls this function; the function does not depend on SwiftUI types.
- [x]**Win condition — all three wheels show their correct segment:**
  - `AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxChime.rawValue)` fires for the success chime.
  - A brief victory animation plays (Cryptex "opens" — scale, opacity, or reveal transition using chapter-specific timing curves).
  - After a brief UI pacing delay (via `withAnimation` completion or `.task` with short `Task.sleep` — acceptable for SwiftUI UI pacing, distinct from the SpriteKit game-timing prohibition in CLAUDE.md §4.3), `coordinator.completeCurrentChapter()` fires exactly once.
  - A `hasCompleted: Bool` state guard prevents double-fire on subsequent interactions.
- [x]**Incorrect submission — one or more wheels are wrong:**
  - The Cryptex frame shakes horizontally via an offset animation (e.g., `withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) { shakeOffset = 10 }` then reset) as visual error feedback.
  - `incorrectAttempts: Int` state property increments by 1.
  - The Unlock action provides a brief "locked" visual indicator (color flash or icon change).
- [x]`incorrectAttempts` persists across submissions within the same chapter session (not reset when the user changes wheel positions).
- [x]`incorrectAttempts` resets to 0 when the chapter restarts from a checkpoint (FlowCoordinator re-navigates to Chapter 3 on app relaunch).
- [x]`completeCurrentChapter()` is called exactly once per win. The `hasCompleted` guard prevents re-fire from any subsequent interaction.
- [x]No `Timer`, `DispatchQueue.asyncAfter` for the victory delay or shake animation. SwiftUI animation modifiers and brief `Task.sleep` are acceptable for UI pacing.

**Dependencies:** CH3_01-S2 (CipherView with wheel bindings and Unlock element), CH3_01-S3 (thud feedback provides per-wheel correctness awareness to the user)
**Completion Signal:** Tapping Unlock with all 3 wheels correct triggers the chime SFX, victory animation, and FlowCoordinator advance to Chapter 4. Tapping Unlock with any wheel incorrect triggers a horizontal shake and increments the attempt counter. Validation logic is a pure function callable without SwiftUI.

---

### Story 5: Implement Auto-Assist subtle glow hint after 3 incorrect submissions

After `GameConstants.AutoAssist.cipherIncorrectThreshold` (3) incorrect submissions, activate a subtle pulsing glow on each wheel's correct segment position. The glow is visible only when the correct segment is near the viewport center, providing proximity guidance without revealing the answer outright.

**Acceptance Criteria:**

- [x]`isAutoAssistActive: Bool` is computed as `incorrectAttempts >= GameConstants.AutoAssist.cipherIncorrectThreshold`.
- [x]When `isAutoAssistActive` is `true`, each `CipherWheelView` receives a flag (e.g., `showHint: Bool`) enabling the glow overlay on its correct segment.
- [x]The glow effect is a pulsing radial gradient or soft shadow overlay behind the correct segment text, animated with a repeating ease-in-out animation using a chapter-specific timing curve.
- [x]The glow is visible only when the correct segment is within the visible viewport of the wheel (within ~1 segment distance of the center position). If the user has scrolled far from the correct segment, no glow is visible — the user must scroll near the correct segment to perceive the hint.
- [x]The glow is subtle — low opacity (≤0.3 alpha), soft edges. It does not overpower the segment text or the brushed metal aesthetic. The effect suggests "warmth" near the correct answer, not a blinking neon indicator.
- [x]Auto-Assist activates on the interaction immediately following the 3rd incorrect submission — the glow becomes visible after the 3rd failed Unlock attempt, perceivable on subsequent wheel scrolling.
- [x]Auto-Assist activation is silent — no banner, no text overlay, no sound effect, no notification. The glow appears naturally as part of the Cryptex aesthetic, preserving the "illusion of skill and success" per Design Doc §3.8.
- [x]Auto-Assist does not reset if the user continues to submit incorrectly. Once active, it remains active for the session duration.
- [x]The glow animation respects `UIAccessibility.isReduceMotionEnabled` — if Reduce Motion is enabled, the glow renders as a static highlight (no pulse animation) at the same opacity.
- [x]All threshold values sourced from `GameConstants.AutoAssist.cipherIncorrectThreshold` — zero hardcoded numbers for Auto-Assist logic.

**Dependencies:** CH3_01-S4 (incorrect attempt tracking must exist)
**Completion Signal:** After 3 incorrect Unlock attempts, scrolling a wheel near its correct segment reveals a subtle pulsing glow that visually distinguishes the correct segment from distractors. The glow is not visible when scrolled far from the correct position. No on-screen notification of the Auto-Assist activation.

---

### Story 6: Implement Reduce Motion compliance, accessibility, and visual polish

Verify and implement `UIAccessibility.isReduceMotionEnabled` compliance across all CipherView and CipherWheelView animations. Add `#Preview` macros to both views. Ensure view body line-count constraints, chapter-specific visual identity rules, and touch target sizing are satisfied.

**Acceptance Criteria:**

- [x]`@Environment(\.accessibilityReduceMotion) private var reduceMotion` is read in both `CipherView` and `CipherWheelView`.
- [x]When Reduce Motion is enabled:
  - Wheel snap animation uses a short `.easeOut(duration: 0.15)` instead of `.spring` oscillation.
  - The 3D `rotation3DEffect` on non-center segments is reduced to zero (flat layout — no perspective tilt).
  - Auto-Assist glow pulse is replaced with a static glow at the same opacity (no repeating animation).
  - Victory animation uses a simple cross-fade instead of scale/reveal.
  - Cryptex shake on incorrect submission is replaced with a brief color flash on the Unlock element.
- [x]When Reduce Motion is disabled, all animations play at full fidelity with the spring curves, 3D rotation, and pulse effects described in prior stories.
- [x]`#Preview` macro present on `CipherView` with a `FlowCoordinator` environment injection.
- [x]`#Preview` macro present on `CipherWheelView` with sample segment data (e.g., `["ALPHA", "BETA", "GAMMA", "DELTA", "EPSILON"]`, correctIndex: 2).
- [x]`CipherView` body ≤80 lines. Subviews extracted as private computed properties, `@ViewBuilder` methods, or separate sub-structs as needed.
- [x]`CipherWheelView` body ≤80 lines.
- [x]All animation timing curves are chapter-specific named constants — no raw `.easeInOut`, `.linear`, or `.default` as the sole animation curve for primary motion per CLAUDE.md §4.2.
- [x]Interactive elements (Unlock action, wheel scroll areas) have minimum touch targets of 44×44 points per Apple HIG.
- [x]No `Color.blue`, `Color.red`, `Color.accentColor`, `Color.primary` as primary chapter elements. All colors are chapter-specific.
- [x]No `.regularMaterial`, `.ultraThinMaterial` system material modifiers per CLAUDE.md §4.2.
- [x]If the Unlock element uses an SF Symbol (e.g., `lock.fill`), it receives custom sizing (60pt+), chapter-specific color, and animation treatment per CLAUDE.md §4.2.
- [x]No `NavigationStack`, no `ScrollView` wrapping chapter content, no generic `VStack { Image; Text; Button }` layouts per CLAUDE.md §4.2.

**Dependencies:** CH3_01-S1 through CH3_01-S5 (all interaction and visual elements must exist for accessibility verification and polish pass)
**Completion Signal:** CipherView and CipherWheelView render correctly in both standard and Reduce Motion modes. All animations have appropriate fallbacks. Previews build and render in Xcode canvas. View body sizes are within 80-line limits. Touch targets meet minimum sizing.

---

### Story 7: Register CipherWheelView.swift in pbxproj and validate governance compliance

Register the new `CipherWheelView.swift` in `project.pbxproj`. Validate that the full Chapter 3 implementation passes all build and governance checks.

**Acceptance Criteria:**

- [x]`CipherWheelView.swift` has a `PBXFileReference` entry in `project.pbxproj` (FileRef 14: `B7D1E38A2D5F6A0100000014`, adjusting if PH-08 allocated a different ID than the anticipated FileRef 13).
- [x]A `PBXBuildFile` entry references the `CipherWheelView.swift` file reference (BuildFile 13: `B7D1E38A2D5F6A0100000113`, adjusting if PH-08 allocated a different ID than the anticipated BuildFile 12).
- [x]The file reference is listed in the `Chapter3_Cipher` `PBXGroup` children array.
- [x]The build file is listed in the `PBXSourcesBuildPhase` files array.
- [x]`CipherView.swift` already has pbxproj registration from COORD_02 (PH-02) — no new registration needed for the modified file.
- [x]`xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0, zero errors, zero warnings (excluding benign `appintentsmetadataprocessor` warning).
- [x]`python3 scripts/audit.py --all` passes with zero violations (7/7 checks: PZ-001, FU-001, DA-001, DP-001, SL-001, CC-001, CB-001).
- [x]No Protocol Zero violations in either file — no AI attribution in headers, comments, or identifiers.
- [x]No force unwraps (`!`).
- [x]No `print` statements. Diagnostics use `os.Logger` gated behind `#if DEBUG` if needed.
- [x]No Combine imports or `ObservableObject` / `@Published` / `@StateObject` / `@EnvironmentObject` usage.
- [x]No deprecated APIs.
- [x]No UIKit imports (`UIViewController`, `UIView`, `UIHostingController`).
- [x]No `Timer`, `DispatchQueue` for any timing. Brief `Task.sleep` for UI pacing in the victory sequence is the sole exception per Story 4.
- [x]All asset references use `GameConstants` type-safe enums — zero string literals for asset identifiers.
- [x]All tuning values are named constants — zero magic numbers.
- [x]`#Preview` macros present on both `CipherView` and `CipherWheelView`.
- [x]Both view bodies ≤80 lines.

**Dependencies:** CH3_01-S1 through CH3_01-S6 (all implementation stories complete)
**Completion Signal:** Clean build with zero errors. Audit passes 7/7. CipherWheelView registered in all 4 pbxproj sections. All governance rules satisfied. PH-09 is ready for on-device validation.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| Custom `DragGesture` scroll wheel feels sluggish or imprecise compared to native `UIPickerView`, degrading the Cryptex immersion | 4 | 3 | 12 | Spring animation response (0.3s) and damping (0.7) are named constants, trivially tunable during PH-16 QA. Drag sensitivity is a function of segment height — adjustable without code restructuring. If custom gesture is unsatisfactory after tuning, wrapping `UIPickerView` is a fallback requiring a CLAUDE.md §3.1 governance exception for UIKit usage. | iOS Engineer |
| Haptic click timing drifts relative to scroll speed — clicks fire too early or too late relative to visual segment transitions, breaking the tactile illusion | 3 | 2 | 6 | Haptic fires on segment index change (computed from offset position), which is mathematically synchronized with the visual position. No timing-based approximation or scheduled delay involved. Validate perceptually on-device during PH-16. | iOS Engineer |
| Auto-Assist glow is either too subtle (user does not notice) or too obvious (removes all challenge), missing the Design Doc §3.8 "illusion of skill" target | 3 | 3 | 9 | Glow opacity, radius, and animation parameters are named constants, tunable during PH-16 QA. The "proximity-only visibility" constraint (glow hidden when scrolled far from correct segment) provides inherent calibration — the user must be close to see it. | iOS Engineer |
| Cyclic wrapping scroll produces disorienting UX when the segment list loops — user loses track of position | 2 | 2 | 4 | With only 5 segments per wheel, the loop is short and positions are easily trackable. If UX testing reveals confusion, add a subtle lap-marker visual or switch to bounded (non-wrapping) scroll with elasticity at edges. Either change is localized to `CipherWheelView`. | iOS Engineer |
| Cipher validation logic tightly coupled to SwiftUI `@State`, preventing PH-15 unit testing without SwiftUI imports | 4 | 2 | 8 | Story 4 explicitly requires validation as a pure function callable without SwiftUI. Code review gate: if the validation function requires SwiftUI types, reject and refactor before merge. The function signature `isAllCorrect(selections: [Int], answers: [Int]) -> Bool` is trivially testable. | iOS Engineer |
| Brushed metal/glass visual treatment looks flat or unconvincing without real material textures or system `.material` modifiers | 2 | 3 | 6 | Use layered gradient rectangles with multiple stops, subtle inner shadow overlays, and specular highlight lines to simulate depth and reflectivity. The `img_bg_cipher` asset (described as "high-tech bank vault door mechanism, brushed steel texture" in Design Doc §7.2) provides atmospheric context — the background carries the material illusion; the Cryptex frame reinforces it with gradient layering. | iOS Engineer |

---

## Definition of Done

- [x]All 7 stories completed and individually verified.
- [x]`CipherWheelView.swift` created at `Chapters/Chapter3_Cipher/CipherWheelView.swift` with full scroll wheel implementation per Design Doc §3.4.
- [x]`CipherView.swift` replaces the PH-02 placeholder with the Cryptex puzzle interface.
- [x]Brushed metal/glass Cryptex frame renders over `img_bg_cipher` background with layered `ZStack` depth composition.
- [x]Three scroll wheels display scrambled phrase segments with `SF Mono` font, snap-to-position spring behavior, and cyclic wrapping.
- [x]Haptic click (`sfx_click` + inline `CHHapticEvent` transient) fires on every segment boundary crossing during scroll.
- [x]Heavy thud (`thud.ahap` + `sfx_haptic_thud`) fires when a wheel snaps to its correct segment after drag release.
- [x]"Unlock" action validates all three wheels simultaneously.
- [x]Win condition: all three wheels correct. `sfx_success_chime` plays and `FlowCoordinator.completeCurrentChapter()` advances to Chapter 4, called exactly once.
- [x]Incorrect submission: Cryptex shakes horizontally, attempt counter increments.
- [x]Auto-Assist: after 3 incorrect submissions (`GameConstants.AutoAssist.cipherIncorrectThreshold`), correct segments glow with a subtle pulse when near the viewport center.
- [x]Auto-Assist activation is silent — no notification, preserving the illusion of skill per Design Doc §3.8.
- [x]Validation logic (segment matching, attempt counting) is a pure Swift function testable in isolation without SwiftUI dependencies for PH-15 consumption.
- [x]Reduce Motion compliance: snap uses ease-out instead of spring, 3D rotation removed, glow pulse is static, victory uses cross-fade, shake replaced with color flash.
- [x]All asset references use `GameConstants` type-safe enums — zero string literals for asset identifiers.
- [x]All tuning values are named constants — zero magic numbers.
- [x]`xcodebuild build` succeeds with zero errors and zero warnings.
- [x]`scripts/audit.py --all` passes with zero violations (7/7 checks).
- [x]No Protocol Zero violations.
- [x]No force unwraps, no `print` statements, no Combine, no deprecated APIs, no UIKit imports.
- [x]`#Preview` macros present on both `CipherView` and `CipherWheelView`.
- [x]Both view bodies ≤80 lines.
- [x]`CipherWheelView.swift` registered in all 4 required `project.pbxproj` sections.

## Exit Criteria

- [x]All Definition of Done conditions satisfied.
- [x]PH-15 (Unit Test Suite) is unblocked — cipher validation logic is pure Swift, callable from `XCTest` without SwiftUI dependencies, covering correct segment matching, incorrect attempt counting, and Auto-Assist activation at threshold.
- [x]PH-10 (Chapter 4) runtime path is unblocked — Chapter 3 completes and FlowCoordinator advances to Chapter 4 via linear state machine.
- [x]PH-14 (Cross-Chapter Transitions) can include Chapter 3 in the transition polish pass — CipherView is a stable SwiftUI view with no SpriteKit lifecycle concerns.
- [x]PH-16 (On-Device QA) can begin Chapter 3 testing — wheel scroll feel, haptic click timing, thud confirmation on correct alignment, Auto-Assist glow activation after 3 failures, brushed metal visual polish, and Reduce Motion fallback behavior.
- [x]Epic ID `CH3_01` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
