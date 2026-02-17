# Epic: CH5_01 — Implement Chapter 5: The Blueprint

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | CH5_01                         |
| **Epic Name** | implement_blueprint_chapter    |
| **Phase**     | PH-11                          |
| **Domain**    | CH5                            |
| **Owner**     | iOS Engineer                   |
| **Status**    | Draft                          |

---

## Problem Statement

The walking skeleton (PH-02) established `BlueprintView.swift` as a placeholder containing a "Complete Chapter" button, a black background, and static title labels. This placeholder provides no gameplay experience — it lacks the deep blue architectural blueprint background (`img_bg_blueprint`), the 12-node heart silhouette layout with 4 labeled cornerstones ("Paris", "New Apt", "Dog", "Coffee"), the sequential drag-to-connect interaction, chalk-line connection rendering, `sfx_success_chime` audio on valid connections, `sfx_error` with haptic feedback on invalid attempts, snap-back animation on incorrect connections, and the Auto-Assist idle detection system (10s idle triggers pulse glow on the next correct node) defined in Design Doc §3.6. Without replacing this placeholder, the app cannot deliver the narrative's fifth chapter — the metaphor of "building the future" that Carolina constructs through a physically grounded connect-the-dots experience.

Chapter 5 is the third SwiftUI-native chapter in the Starlight Sync arc (alongside Chapters 1 and 3) and carries moderate complexity per `docs/PHASES.md`. Unlike the SpriteKit chapters (2 and 4), Chapter 5 uses SwiftUI `DragGesture` for input, `Canvas` for connection line rendering, and SwiftUI layout primitives for node positioning. The primary technical challenge is implementing a responsive drag-to-connect interaction that tracks the user's finger across a coordinate space, detects proximity to node hit regions, validates sequential ordering, and renders a live chalk-line from the last connected node to the current drag position — all at 120fps on ProMotion hardware without frame drops.

PH-11 is on the critical path (`PHASES.md` §Critical Path). Completion unblocks PH-13 (Chapter 6 — The Event Horizon), PH-14 (Cross-Chapter Transitions & Polish), and ultimately PH-17 (TestFlight Distribution).

---

## Goals

- Replace the `BlueprintView` placeholder with a production-quality SwiftUI connect-the-dots experience implementing Design Doc §3.6 in its entirety: deep royal blue architectural blueprint background (`img_bg_blueprint`), white chalk-line aesthetic, 12 nodes forming a fixed heart silhouette with 4 labeled cornerstones ("Paris" at top-left bump, "New Apt" at top-right bump, "Dog" at center dip, "Coffee" at bottom point) and 8 unlabeled structural nodes, sequential drag-to-connect interaction (A→B→C→...→L), snap-back on incorrect connection with `sfx_error` and error haptic, `sfx_success_chime` on correct connection, win condition (all 12 nodes connected), and Auto-Assist (10s idle triggers pulsing glow on next correct node).
- Create `HeartNodeLayout.swift` at `Chapters/Chapter5_Blueprint/` containing the 12-node coordinate model, cornerstone label definitions, and the parametric heart geometry that positions nodes in a recognizable heart silhouette scaled to the device screen.
- Implement `BlueprintView.swift` with `Canvas`-based connection line rendering for zero-allocation draw calls, `DragGesture` with coordinate space tracking for sequential node connection, and `TimelineView`-based idle detection for the Auto-Assist pulse hint — all using SwiftUI-native APIs with no SpriteKit, UIKit, or Combine dependencies.
- Ensure all tuning values reference `GameConstants` namespace (`AutoAssist.blueprintIdleThreshold`, `Timing.blueprintIdlePulseDuration`) and all asset identifiers reference type-safe enums (`BackgroundAsset.blueprint`, `AudioAsset.sfxChime`, `AudioAsset.sfxError`) — zero magic numbers, zero stringly-typed access.
- Validate that `FlowCoordinator.completeCurrentChapter()` advances to Chapter 6 on puzzle completion, maintaining the linear state machine invariant.
- Respect `UIAccessibility.isReduceMotionEnabled` for all animations: pulse glow, connection line drawing, snap-back, and victory transition.

## Non-Goals

- **No modifications to FlowCoordinator, AudioManager, HapticManager, AssetPreloadCoordinator, or GameConstants.** These components are complete (PH-02 through PH-06). BlueprintView and HeartNodeLayout consume their public APIs only. If an API gap is discovered, it is documented as a blocking issue, not resolved within this epic.
- **No SpriteKit usage.** Design Doc §4.1 specifies Chapter 5 as a SwiftUI chapter. No `SKScene`, `SpriteView`, `SKSpriteNode`, or `SKPhysicsBody`. All rendering via SwiftUI `Canvas`, `Path`, and standard view modifiers.
- **No cross-chapter transition orchestration.** The `matchedGeometryEffect` spatial transitions, BGM cross-fade between chapters, and chapter-to-chapter animation sequencing are PH-14 scope. This epic verifies that `FlowCoordinator.completeCurrentChapter()` fires correctly; PH-14 coordinates the full transition sequence.
- **No custom font integration.** Design Doc §7.7 specifies SF Pro Rounded as the primary UI typeface and lists custom fonts (Clash Display / Monument Extended) as optional. This epic uses system fonts exclusively — `Font.system(design: .rounded)` for labels and chapter text. Custom font integration, if adopted, is a separate scope.
- **No unit tests for BlueprintView or HeartNodeLayout.** SwiftUI view interaction logic is validated by on-device QA (PH-16). The `FlowCoordinator` progression tests and `GameConstants` validation tests are PH-15 scope, not this epic.
- **No dynamic node layout or procedural generation.** The heart silhouette is a fixed 12-node layout per Design Doc §3.6. Node positions are determined at build time from the parametric heart curve, not computed dynamically at runtime. Node count, cornerstone labels, and connection order are immutable.
- **No particle effects or confetti.** Chapter 5's visual language is architectural blueprint — clean chalk lines on deep blue. No particle emitters, no shimmer effects, no environmental particles.

---

## Technical Approach

**Node Layout Model.** `HeartNodeLayout` is a `struct` at `StarlightSync/Chapters/Chapter5_Blueprint/HeartNodeLayout.swift`. It defines 12 node positions derived from the parametric heart curve: `x(t) = 16 * sin(t)^3`, `y(t) = 13 * cos(t) - 5 * cos(2t) - 2 * cos(3t) - cos(4t)`. Twelve evenly-spaced parameter values `t` in `[0, 2π)` produce raw coordinates that are normalized to a `[-1, 1]` range and then scaled to the available screen geometry via a `scale(to:)` method that accepts a `CGSize` container. The parametric y-axis is math-convention (up-positive) and is flipped for screen coordinates. The 4 cornerstone nodes are assigned to parameter values nearest the heart's anatomical landmarks: top-left bump (~t = 2π/3), top-right bump (~t = π/3), center dip (t ≈ 0), and bottom point (t = π). Each node carries an `id: Int` (0–11, sequential), an optional `label: String?` (non-nil for the 4 cornerstones), and a `position: CGPoint` computed for the target container size. The struct also exposes `static let connectionOrder: [Int]` — the required sequential connection path from node 0 through node 11 — and a `nodeRadius: CGFloat` computed proportionally to the container size for hit-testing.

**View Architecture.** `BlueprintView` is a SwiftUI `View` at `StarlightSync/Chapters/Chapter5_Blueprint/BlueprintView.swift`, replacing the PH-02 placeholder entirely. The view body is a `ZStack` layered as follows: (1) `img_bg_blueprint` full-bleed background image from `AssetPreloadCoordinator` or the asset catalog; (2) a `Canvas` layer rendering completed connection lines as white chalk-line strokes between connected node pairs, plus a live drag line from the last connected node to the current finger position during active drag; (3) node views — 12 circular indicators positioned via `.position()` modifiers on a `GeometryReader`, with cornerstones displaying their labels below/beside the circle and structural nodes rendering as smaller unlabeled circles; (4) an overlay layer for the chapter introduction card ("Building the Future") shown before interaction begins, and a victory overlay shown on completion. The `GeometryReader` provides the container size to `HeartNodeLayout.scale(to:)`, ensuring the heart shape adapts to the screen. A named coordinate space (`.coordinateSpace(.named("board"))`) enables consistent gesture-to-layout coordinate mapping.

**Drag-to-Connect Interaction.** A `DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))` is attached to the board area. On `.onChanged`, the gesture's current location is stored for live drag-line rendering, and the system checks whether the finger has entered the hit region of the next expected node (determined by `HeartNodeLayout.connectionOrder[nextNodeIndex]`). The hit region is a circle of radius `nodeRadius * 1.5` (generous for touch targets — at least 44pt effective per Apple HIG). When the finger enters the correct next node, the connection is established: `connectedNodes` array appends the node index, `nextNodeIndex` increments, `sfx_success_chime` plays via `AudioManager.shared.playSFX(named:)`, and the Canvas redraws to include the new permanent connection line. If the finger enters any non-next node during drag (a node that is not the immediate next in sequence), the connection is rejected: the drag state resets to the last valid node, `sfx_error` plays via `AudioManager.shared.playSFX(named:)`, and a transient haptic fires via `HapticManager.shared.playTransient(intensity:sharpness:)` with error-appropriate values (high intensity, high sharpness). The snap-back is animated using `withAnimation(.easeOut(duration: 0.2))` to visually return the drag line to the last connected node. On `.onEnded`, the active drag line disappears; if the user lifted their finger without reaching the next node, no penalty is applied — they simply restart the drag from the last connected node.

**Connection Line Rendering.** The `Canvas` view receives the `connectedNodes` array and `currentDragLocation` as bindings. For each consecutive pair in `connectedNodes`, it strokes a `Path` line between the two node positions using a white chalk-line style: `.stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))` with `Color.white.opacity(0.85)`. During an active drag, an additional dashed line renders from the last connected node to `currentDragLocation` to provide visual feedback of the drag path. The Canvas redraws only when `connectedNodes.count` changes or `currentDragLocation` updates — state-driven redraw, not timer-driven. No `Timer`, `DispatchQueue`, or `Task.sleep`.

**Auto-Assist Idle Detection.** Idle detection uses a `@State private var lastInteractionTime: Date = .now` timestamp that resets on every `DragGesture.onChanged` event. A `TimelineView(.periodic(every: 1.0))` evaluates the elapsed time since `lastInteractionTime` on each tick. When `Date.now.timeIntervalSince(lastInteractionTime) >= GameConstants.AutoAssist.blueprintIdleThreshold` (10s), the `isAutoAssistHintActive` flag becomes `true`, triggering a pulsing glow animation on the next correct node. The pulse uses a repeating `scaleEffect` and `opacity` animation. When the user resumes interaction (any drag gesture fires), `lastInteractionTime` resets and `isAutoAssistHintActive` becomes `false`, stopping the pulse. The `TimelineView` pauses when the puzzle is complete (all 12 connected). Auto-Assist activation is silent — no text overlay, no notification — preserving the illusion of discovery per Design Doc §3.8.

**Feedback Channels.** Multi-sensory redundancy per Design Doc §12.3: (1) Visual — connection line appears, node highlights on connection, shake on error, glow on Auto-Assist; (2) Audio — `sfx_success_chime` on valid, `sfx_error` on invalid; (3) Haptic — transient haptic on error via `HapticManager`. Haptic and audio failures are isolated — neither blocks UI, chapter progression, or Auto-Assist logic per CLAUDE.md §4.4, §4.5.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| `FlowCoordinator` with `completeCurrentChapter()` API and `@Environment` injection | COORD_01, COORD_02 (PH-02) | Complete | iOS Engineer |
| `GameConstants.AutoAssist.blueprintIdleThreshold` (10.0s), `GameConstants.Timing.blueprintIdlePulseDuration` (10.0s) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `GameConstants.BackgroundAsset.blueprint` (`"Backgrounds/img_bg_blueprint"`) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `GameConstants.AudioAsset.sfxChime` (`sfx_success_chime`) and `GameConstants.AudioAsset.sfxError` (`sfx_error`) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `AudioManager.shared` with `sfx_success_chime` and `sfx_error` preloaded and SFX playback API | AUDIO_01 (PH-03), ASSET_03 (PH-05) | Complete | iOS Engineer |
| `HapticManager.shared` with transient haptic playback API | HAPTIC_01 (PH-04) | Complete | iOS Engineer |
| `img_bg_blueprint` background in `Assets.xcassets/Backgrounds/` | ASSET_01 (PH-05) | Complete | iOS Engineer |
| `AssetPreloadCoordinator` with `img_bg_blueprint` decoded to `UIImage` and resident in memory | ASSET_02 (PH-05) | Complete | iOS Engineer |
| Chapter 4 (PH-10) complete — runtime prerequisite for sequential navigation to Chapter 5 via FlowCoordinator linear state machine | CH4_01 (PH-10) | Complete | iOS Engineer |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| Chapter 5 complete — sequential chapter progression continues | PH-13 (Chapter 6 Event Horizon) | Chapter 6 is unlocked when Chapter 5 completes via FlowCoordinator |
| All 5 gameplay chapters implemented — cross-chapter transition pass can begin | PH-14 (Cross-Chapter Transitions) | PH-14 requires all 6 chapter views to exist for transition orchestration |
| Chapter 5 playable for on-device validation | PH-16 (On-Device QA) | QA playtest validates drag interaction feel, node hit regions, Auto-Assist activation, connection line rendering |

---

## Stories

### Story 1: Create HeartNodeLayout with 12-node heart coordinates, cornerstone labels, and connection order

Define the geometric model for the heart-shaped connect-the-dots layout. The `HeartNodeLayout` struct provides 12 node definitions derived from the parametric heart curve, with 4 cornerstones carrying labels and 8 unlabeled structural nodes. Positions are normalized and scalable to any container size.

**Acceptance Criteria:**

- [ ] File created at `StarlightSync/Chapters/Chapter5_Blueprint/HeartNodeLayout.swift`.
- [ ] `HeartNodeLayout` is a `struct` (not a class — pure data model with no identity semantics).
- [ ] A nested `Node` struct is defined with properties: `id: Int` (0–11), `label: String?` (non-nil for 4 cornerstones, nil for 8 structural nodes), and a normalized position `normalizedPosition: CGPoint` in the `[-1, 1]` coordinate range.
- [ ] 12 nodes are derived from the parametric heart curve: `x(t) = 16 * sin³(t)`, `y(t) = 13 * cos(t) - 5 * cos(2t) - 2 * cos(3t) - cos(4t)`. Parameter values `t` are sampled at 12 evenly-spaced intervals across `[0, 2π)`.
- [ ] Parametric y-axis is flipped for screen coordinates (math up-positive → screen down-positive): `screenY = -normalizedY`.
- [ ] 4 cornerstone nodes are assigned labels at the anatomically correct positions: `"Paris"` at the top-left bump, `"New Apt"` at the top-right bump, `"Dog"` at the center dip (top center of heart), `"Coffee"` at the bottom point.
- [ ] `static let connectionOrder: [Int]` defines the sequential path from node 0 through node 11 — the order in which the user must connect nodes. The path traces the heart outline continuously.
- [ ] A `func scaledPositions(in size: CGSize, padding: CGFloat) -> [CGPoint]` method maps normalized positions to screen coordinates within the given container size, applying the specified padding to keep nodes away from screen edges.
- [ ] A `static let nodeRadius: CGFloat` or `func nodeRadius(for size: CGSize) -> CGFloat` provides the hit-test radius, computed proportionally to the container size (minimum 22pt for a 44pt effective touch target diameter per Apple HIG).
- [ ] All numeric values used in the parametric equation and node assignment are named constants within the struct — zero magic numbers in the computation logic.
- [ ] No `import UIKit` or `import SpriteKit`. Only `import Foundation` and/or `import CoreGraphics` as needed for `CGPoint`/`CGSize`.

**Dependencies:** None
**Completion Signal:** `HeartNodeLayout` compiles and provides 12 node positions that, when plotted, form a recognizable heart silhouette with 4 labeled cornerstones at the correct anatomical landmarks. The `connectionOrder` array defines a continuous path around the heart outline. The `scaledPositions(in:padding:)` method maps positions to screen coordinates for any `CGSize`.

---

### Story 2: Implement BlueprintView with blueprint background, node rendering, and chapter introduction card

Replace the `BlueprintView` placeholder with the deep blue architectural blueprint background, render 12 node indicators in a heart layout using `HeartNodeLayout`, display cornerstone labels, and show an introduction card ("Building the Future") before interaction begins.

**Acceptance Criteria:**

- [ ] `BlueprintView.swift` body is replaced entirely — the placeholder `ZStack` with `Color.black`, `Text` labels, and `Button` are removed.
- [ ] `@Environment(FlowCoordinator.self) private var coordinator` reads the coordinator from the SwiftUI environment.
- [ ] Background: `img_bg_blueprint` rendered as a full-bleed `Image` from the asset catalog using `GameConstants.BackgroundAsset.blueprint.rawValue`, with `.resizable()`, `.aspectRatio(contentMode: .fill)`, and `.ignoresSafeArea()`.
- [ ] `GeometryReader` provides the container size to `HeartNodeLayout.scaledPositions(in:padding:)`.
- [ ] A named coordinate space `.coordinateSpace(.named("board"))` is applied to the `GeometryReader` container for gesture-to-layout coordinate consistency.
- [ ] 12 node indicators render at scaled positions via `.position()` modifier — NOT `.offset()`.
- [ ] Cornerstone nodes (4): larger circles (diameter ≥ 20pt) with white fill/stroke, label text rendered below or beside the circle using `Font.system(size:design: .rounded)` in white with `opacity(0.9)`. Label placement avoids overlap with adjacent nodes.
- [ ] Structural nodes (8): smaller circles (diameter ≥ 12pt) with white stroke, semi-transparent fill, no label.
- [ ] Node styling uses chapter-specific colors — white chalk on deep blue. No default system colors (`Color.blue`, `Color.accentColor`, `Color.primary`). No `Color.black` fill on nodes (the background is deep blue, not black).
- [ ] Introduction card overlay: dimmed background, chapter title "THE BLUEPRINT", context text "Building the Future", and a `[ BEGIN ]` button. On `[ BEGIN ]` tap, the overlay dismisses with animation and interaction is enabled.
- [ ] Introduction card styling uses chapter-appropriate typography and colors — white/light text on translucent deep blue overlay. Not default system modal styling.
- [ ] `private enum ViewState { case intro, playing, won }` gates interaction and overlay visibility.
- [ ] View body ≤ 80 lines. Extract subviews as needed.
- [ ] `#Preview` macro present with functioning preview providing `FlowCoordinator` environment.

**Dependencies:** CH5_01-S1 (HeartNodeLayout must exist for node positions)
**Completion Signal:** BlueprintView renders the deep blue blueprint background with 12 node indicators in a heart shape. 4 cornerstones display labels ("Paris", "New Apt", "Dog", "Coffee") at correct positions. An introduction card displays on entry and dismisses to reveal the interactive board. No connections, no drag interaction, no audio yet.

---

### Story 3: Implement sequential drag-to-connect gesture with Canvas connection line rendering

Add `DragGesture` tracking for sequential node-to-node connection. The user drags from the current active node toward the next expected node in sequence. When the finger enters the next node's hit region, the connection is established. A `Canvas` view renders completed connection lines as white chalk-line strokes and a live drag line from the last connected node to the current finger position.

**Acceptance Criteria:**

- [ ] `DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))` is attached to the board area.
- [ ] `@State private var connectedNodeIndices: [Int]` tracks the sequence of connected node indices, initialized with `[connectionOrder[0]]` (the starting node is pre-connected).
- [ ] `@State private var nextConnectionIndex: Int = 1` tracks the index into `HeartNodeLayout.connectionOrder` for the next expected node.
- [ ] `@State private var currentDragLocation: CGPoint?` stores the current finger position during active drag, set to `nil` when drag ends.
- [ ] On `.onChanged`: `currentDragLocation` updates to `value.location`. If the finger is within `nodeRadius * 1.5` of the next expected node (Euclidean distance), the connection is established: the node index is appended to `connectedNodeIndices`, `nextConnectionIndex` increments, and `currentDragLocation` continues tracking.
- [ ] On `.onEnded`: `currentDragLocation` is set to `nil`. No penalty for lifting the finger without reaching the next node — the user resumes from the last connected node on the next drag.
- [ ] `Canvas` view renders below the node layer but above the background. For each consecutive pair in `connectedNodeIndices`, a `Path` line is stroked between the two node positions using white chalk-line style: `lineWidth: 3`, `lineCap: .round`, `Color.white.opacity(0.85)`.
- [ ] During active drag (`currentDragLocation != nil`), an additional dashed line renders from the last connected node position to `currentDragLocation` — `StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])` with `Color.white.opacity(0.5)`.
- [ ] Canvas redraws are state-driven — triggered only by `connectedNodeIndices` or `currentDragLocation` changes. No `Timer`, `DispatchQueue`, or `Task.sleep`.
- [ ] Connected nodes receive a visual state change: filled circle (full white opacity) replacing the initial hollow/semi-transparent circle. The starting node begins in the connected visual state.
- [ ] Drag gesture is gated on `viewState == .playing`.
- [ ] Hit-test radius is computed from `HeartNodeLayout.nodeRadius(for:)` — no hardcoded pixel values.
- [ ] All `withAnimation` blocks use chapter-specific timing curves — no `.default`, `.linear`, or `.easeInOut` as the sole animation curve.

**Dependencies:** CH5_01-S1 (node positions for hit-testing), CH5_01-S2 (view structure with GeometryReader and coordinate space)
**Completion Signal:** Dragging from the starting node toward the next expected node in sequence creates a visible white chalk-line connection when the finger enters the target node's hit region. A live dashed line follows the finger during drag. Lifting the finger without reaching a node resets the drag line. Connected nodes visually fill in. Multiple connections can be established in sequence by dragging continuously from node to node.

---

### Story 4: Add audio and haptic feedback for correct and incorrect connections

Wire `sfx_success_chime` via `AudioManager` on each valid node connection. Wire `sfx_error` via `AudioManager` and a transient haptic via `HapticManager` on invalid connection attempts (finger enters a non-next node during drag). Implement snap-back animation on incorrect connections.

**Acceptance Criteria:**

- [ ] On valid connection (finger enters next expected node): `AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxChime.rawValue)` fires immediately. Audio failure does not block the connection logic — failure isolation per CLAUDE.md §4.5.
- [ ] On invalid connection attempt (finger enters any node that is NOT the next expected node and is NOT already connected): `AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxError.rawValue)` fires. `HapticManager.shared.playTransient(intensity: 0.8, sharpness: 0.6)` fires. Both are fire-and-forget — failures do not propagate.
- [ ] On invalid attempt: the `currentDragLocation` snaps back to the last connected node's position with an animated transition: `withAnimation(.easeOut(duration: 0.2))`. The drag line visually retracts to the last valid node.
- [ ] Invalid attempts do NOT disconnect any previously established connections. The `connectedNodeIndices` array is not modified on error — only the active drag state resets.
- [ ] Entering an already-connected node during drag is a no-op — no error, no SFX, no haptic. Only entering an unconnected non-next node triggers the error feedback.
- [ ] The starting node (index 0) does not trigger connection SFX — it is pre-connected during initialization.
- [ ] Audio asset identifiers use `GameConstants.AudioAsset` type-safe enum — zero string literals.
- [ ] Haptic feedback uses `HapticManager.shared` exclusively — no direct `CHHapticEngine` access from the view per CLAUDE.md §4.4.
- [ ] SFX playback is called on the main actor — no background thread dispatch.
- [ ] No `Timer`, `DispatchQueue`, or `Task.sleep` for feedback timing.

**Dependencies:** CH5_01-S3 (drag gesture and connection logic must exist for feedback wiring)
**Completion Signal:** Valid connections play `sfx_success_chime`. Invalid connection attempts play `sfx_error` with a haptic pulse and visually snap the drag line back to the last valid node. Audio/haptic failures are silently absorbed.

---

### Story 5: Implement Auto-Assist idle detection with pulsing glow on next correct node

After 10 seconds of no interaction, the next correct node in the connection sequence pulses with a glow animation, guiding the user without breaking immersion. The hint deactivates when the user resumes interaction.

**Acceptance Criteria:**

- [ ] `@State private var lastInteractionTime: Date = .now` resets on every `DragGesture.onChanged` event and on introduction card dismissal.
- [ ] `TimelineView(.periodic(every: 1.0))` evaluates idle time as `Date.now.timeIntervalSince(lastInteractionTime)`.
- [ ] When idle time `>= GameConstants.AutoAssist.blueprintIdleThreshold` (10.0s), `isAutoAssistHintActive` becomes `true`.
- [ ] When `isAutoAssistHintActive` is `true`, the next expected node (at `HeartNodeLayout.connectionOrder[nextConnectionIndex]`) renders with a pulsing glow: repeating `scaleEffect` oscillation between 1.0 and 1.3, combined with an `opacity` oscillation between 0.6 and 1.0, using a chapter-specific timing curve (e.g., `.easeInOut(duration: 0.8).repeatForever(autoreverses: true)`).
- [ ] Glow color is a warm white or soft gold — distinct from the standard node styling but consistent with the chalk-on-blueprint aesthetic. Not default system colors.
- [ ] When the user resumes interaction (any `DragGesture.onChanged` fires), `lastInteractionTime` resets to `.now` and `isAutoAssistHintActive` becomes `false`. The pulse animation stops and the node returns to its standard styling.
- [ ] Auto-Assist activation is silent — no text overlay, no notification, no sound effect. Only the visual pulse hint. Preserving the "illusion of skill and success" per Design Doc §3.8.
- [ ] Auto-Assist does NOT auto-connect the node. It only highlights the target. The user must still drag to the node to establish the connection.
- [ ] `TimelineView` pauses evaluation when `viewState != .playing` (stops during intro and after win).
- [ ] All threshold values sourced from `GameConstants` — zero hardcoded durations.
- [ ] No `Timer`, `DispatchQueue`, `Task.sleep`, or Combine for idle tracking.

**Dependencies:** CH5_01-S3 (gesture and connection tracking provide `nextConnectionIndex` and `lastInteractionTime` reset points)
**Completion Signal:** After 10 seconds of inactivity, the next correct node visibly pulses. Resuming interaction stops the pulse. The hint does not auto-solve — the user must still drag to connect. The pulse is visually subtle and consistent with the blueprint aesthetic.

---

### Story 6: Implement win condition, victory transition, and FlowCoordinator chapter completion

When all 12 nodes are connected, transition to a victory state with a completion animation and advance to Chapter 6 via `FlowCoordinator.completeCurrentChapter()`.

**Acceptance Criteria:**

- [ ] Win condition: `nextConnectionIndex >= HeartNodeLayout.connectionOrder.count` (all 12 nodes connected). Evaluated immediately after each successful connection in the drag handler.
- [ ] On win: `viewState` transitions to `.won`. Drag gesture is disabled. `TimelineView` idle detection pauses.
- [ ] Victory animation sequence: (1) a brief pause (~0.5s) to let the final connection line render; (2) the completed heart silhouette pulses with a soft glow (unified glow on all connection lines and nodes); (3) a victory overlay fades in with chapter completion text (e.g., "BLUEPRINT COMPLETE") and a `[ CONTINUE ]` button.
- [ ] Victory overlay styling: translucent deep blue background over the completed heart, white text, chapter-appropriate typography. Not default system modal styling.
- [ ] On `[ CONTINUE ]` tap: `coordinator.completeCurrentChapter()` fires exactly once. A guard prevents double-fire on subsequent taps (e.g., `didComplete` flag checked before calling coordinator).
- [ ] `sfx_success_chime` plays on the final connection (same as any other valid connection — no special SFX for the win).
- [ ] No `Timer`, `DispatchQueue`, or `Task.sleep` for the victory delay. Use `withAnimation(.easeIn(duration: 0.5).delay(0.5))` or similar declarative approach for the pause-then-reveal sequence.
- [ ] No additional SFX or haptic on the victory overlay appearance — the chime from the final connection provides the audio signal.

**Dependencies:** CH5_01-S3 (connection tracking for win condition evaluation), CH5_01-S4 (SFX on final connection)
**Completion Signal:** Connecting all 12 nodes triggers a victory overlay. Tapping CONTINUE advances to Chapter 6 via FlowCoordinator. No double-fire. The completed heart shape remains visible under the victory overlay.

---

### Story 7: Add Reduce Motion fallback, register HeartNodeLayout.swift in pbxproj, and validate governance compliance

Implement Reduce Motion alternatives for all animations, register the new source file in `project.pbxproj`, and validate the full Chapter 5 implementation against build and governance standards.

**Acceptance Criteria:**

- [ ] `@Environment(\.accessibilityReduceMotion) private var reduceMotion` is read in `BlueprintView`.
- [ ] When `reduceMotion` is `true`: Auto-Assist pulse glow is replaced with a static highlight (solid border or brighter fill, no animation). Connection line drawing is immediate (no animated stroke). Snap-back on error uses instant position reset (no animated retract). Victory overlay appears with a simple cross-fade (no pulse or glow on the completed heart). Introduction card dismissal uses cross-fade instead of any slide or scale animation.
- [ ] When `reduceMotion` is `false`: all animations play as designed in Stories 2–6.
- [ ] Every `withAnimation` call and `.animation()` modifier is gated behind `!reduceMotion` or uses a conditional animation value.
- [ ] `HeartNodeLayout.swift` has a `PBXFileReference` entry in `project.pbxproj` (FileRef 18: `B7D1E38A2D5F6A0100000018`).
- [ ] A `PBXBuildFile` entry references the `HeartNodeLayout.swift` file reference (BuildFile 16: `B7D1E38A2D5F6A0100000116`).
- [ ] The file reference is listed in the `Chapter5_Blueprint` `PBXGroup` children array.
- [ ] The build file is listed in the `PBXSourcesBuildPhase` files array.
- [ ] `BlueprintView.swift` already has pbxproj registration from COORD_02 — no new registration needed for the modified file.
- [ ] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0, zero errors, zero warnings (excluding benign `appintentsmetadataprocessor` warning).
- [ ] `python3 scripts/audit.py --all` passes with zero violations (7/7 checks: PZ-001, FU-001, DA-001, DP-001, SL-001, CC-001, CB-001).
- [ ] No Protocol Zero violations in either file — no AI attribution in headers, comments, or identifiers.
- [ ] No force unwraps (`!`) in either file.
- [ ] No `print` statements. Diagnostics use `os.Logger` gated behind `#if DEBUG` if needed.
- [ ] No Combine imports or `ObservableObject` / `@Published` / `@StateObject` / `@EnvironmentObject` usage.
- [ ] No deprecated APIs. No `DispatchQueue`, `Timer`, or GCD.
- [ ] No UIKit imports (`UIViewController`, `UIView`, `UIHostingController`).
- [ ] No SpriteKit imports in either file.
- [ ] All asset references use `GameConstants` type-safe enums — zero string literals for asset identifiers.
- [ ] All tuning values are named constants — zero magic numbers.
- [ ] `BlueprintView` body ≤ 80 lines with subview extraction.
- [ ] `#Preview` macro present on `BlueprintView`.

**Dependencies:** CH5_01-S1 through CH5_01-S6 (all implementation stories complete)
**Completion Signal:** Clean build with zero errors. Audit passes 7/7. HeartNodeLayout registered in all 4 pbxproj sections. Reduce Motion fallback covers all animated elements. All governance rules satisfied. PH-11 is ready for on-device validation.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| Heart shape rendered from parametric curve does not read as a recognizable heart at device screen size — nodes too close or unevenly distributed | 3 | 3 | 9 | Sample parameter values `t` at 12 points optimized for visual distribution, not mathematically even spacing. Validate heart shape visually in SwiftUI preview before wiring interaction. Adjust individual node positions manually within `HeartNodeLayout` if the parametric curve produces an unsatisfying shape at small screen scale. Reserve PH-16 tuning time for on-device position refinement. | iOS Engineer |
| Drag gesture hit-test region for nodes is too small, causing missed connections and user frustration — especially for structural nodes (12pt diameter) | 3 | 2 | 6 | Hit-test radius is `nodeRadius * 1.5` (minimum 22pt radius → 44pt effective diameter), exceeding Apple HIG minimum touch target. The visual node size is decoupled from the hit-test radius — a 12pt visual circle has a 44pt+ touch target. Test on-device during PH-16 and increase the multiplier if needed. | iOS Engineer |
| `DragGesture` coordinate space mismatch between `GeometryReader` and `Canvas` causes node positions to disagree with gesture locations | 4 | 2 | 8 | Both `Canvas` and `DragGesture` use the same `.named("board")` coordinate space applied to the shared `GeometryReader` parent. All position calculations route through `HeartNodeLayout.scaledPositions(in:padding:)` using the same `CGSize`. No mixed coordinate systems. | iOS Engineer |
| `Canvas` redraw during active drag causes frame drops on ProMotion 120fps — excessive redraw frequency | 2 | 2 | 4 | `Canvas` redraws are minimal: straight line segments between node positions (12 max) plus one drag line. No bezier curves, no gradients, no texture sampling. This is trivially within the frame budget for SwiftUI `Canvas` on A19 Pro. If profiling reveals issues during PH-16, reduce drag line update frequency by rounding `currentDragLocation` to integer coordinates to reduce state change frequency. | iOS Engineer |
| Auto-Assist `TimelineView(.periodic(every: 1.0))` causes unnecessary view rebuilds even when the puzzle is complete or during intro | 2 | 3 | 6 | `TimelineView` evaluation is gated on `viewState == .playing`. When not in playing state, the timeline body returns early without triggering any state changes. If baseline overhead is measurable, switch to `TimelineView(.animation(.default, paused: viewState != .playing))` to fully pause the schedule. | iOS Engineer |

---

## Definition of Done

- [ ] All 7 stories completed and individually verified.
- [ ] `HeartNodeLayout.swift` created at `Chapters/Chapter5_Blueprint/HeartNodeLayout.swift` with 12-node parametric heart layout, 4 labeled cornerstones, and connection order.
- [ ] `BlueprintView.swift` replaces the PH-02 placeholder with full connect-the-dots implementation per Design Doc §3.6.
- [ ] Deep blue architectural blueprint background (`img_bg_blueprint`) renders full-bleed.
- [ ] 12 nodes render in a recognizable heart silhouette: 4 labeled cornerstones at correct anatomical positions ("Paris" top-left, "New Apt" top-right, "Dog" center dip, "Coffee" bottom point), 8 unlabeled structural nodes.
- [ ] Sequential drag-to-connect interaction: finger drags from node A to node B to node C in order. Only the next expected node in sequence accepts a connection.
- [ ] Invalid connection (finger enters non-next node): `sfx_error` plays, transient haptic fires, drag line snaps back to last valid node. No connections are broken.
- [ ] Valid connection: `sfx_success_chime` plays, connection line renders permanently, node fills in visually.
- [ ] `Canvas` renders chalk-white connection lines between connected nodes and a live dashed drag line during active drag.
- [ ] Auto-Assist: after 10 seconds idle (`GameConstants.AutoAssist.blueprintIdleThreshold`), the next correct node pulses with a glow animation. Interaction resumes → pulse stops. No auto-solve.
- [ ] Auto-Assist activation is silent — no player notification, preserving the illusion of discovery.
- [ ] Win condition: all 12 nodes connected. Victory overlay with `[ CONTINUE ]` button. `FlowCoordinator.completeCurrentChapter()` advances to Chapter 6, called exactly once.
- [ ] Introduction card ("Building the Future") displays before interaction. Dismisses to reveal the interactive board.
- [ ] Reduce Motion respected: pulse glow replaced with static highlight, snap-back instant, connection drawing immediate, victory cross-fade instead of pulse. Every animation gated on `!reduceMotion`.
- [ ] `xcodebuild build` succeeds with zero errors and zero warnings.
- [ ] `scripts/audit.py --all` passes with zero violations (7/7 checks).
- [ ] No Protocol Zero violations.
- [ ] No force unwraps, no `print` statements, no Combine, no deprecated APIs.
- [ ] No SpriteKit imports, no UIKit imports, no `Timer`, no `DispatchQueue`.
- [ ] All asset references use `GameConstants` type-safe enums — zero string literals.
- [ ] All tuning values are named constants — zero magic numbers.
- [ ] `#Preview` macro present on `BlueprintView`.
- [ ] `BlueprintView` body ≤ 80 lines.
- [ ] `HeartNodeLayout.swift` registered in all 4 required `project.pbxproj` sections (FileRef 18, BuildFile 16).

## Exit Criteria

- [ ] All Definition of Done conditions satisfied.
- [ ] PH-13 (Chapter 6) is unblocked — Chapter 5 completes and FlowCoordinator advances to Chapter 6.
- [ ] PH-14 (Cross-Chapter Transitions) is unblocked — all 5 gameplay chapters (1–5) are implemented, enabling the full cross-chapter transition pass.
- [ ] PH-16 (On-Device QA) can begin Chapter 5 testing — drag interaction feel, node hit region sizing, connection line rendering, Auto-Assist activation after 10s idle, cornerstone label positioning, and heart shape recognition validation.
- [ ] Connect-the-dots interaction architecture documented in code: `DragGesture` with named coordinate space, `Canvas` connection lines, `TimelineView` idle detection. Pattern is reviewable for correctness before PH-16 tuning.
- [ ] Epic ID `CH5_01` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
