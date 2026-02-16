# Epic: CH4_01 — Implement Chapter 4: The Firewall

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | CH4_01                         |
| **Epic Name** | implement_firewall_chapter     |
| **Phase**     | PH-10                          |
| **Domain**    | CH4                            |
| **Owner**     | iOS Engineer                   |
| **Status**    | Complete                       |

---

## Problem Statement

The walking skeleton (PH-02) established `FirewallView.swift` as a placeholder containing a "Complete Chapter" button and static title labels. This placeholder provides no gameplay experience — it lacks the SpriteKit rhythm defense scene, center-screen otter bubble shield, beat-synced noise particle spawning, directional tap detection with hit window scoring, `sfx_shield_impact` audio feedback, and the Auto-Assist adaptive difficulty system defined in Design Doc §3.5. Without replacing this placeholder, the app cannot deliver the narrative's fourth chapter — the metaphor of "protecting the peace" that Carolina defends through a physically grounded rhythm defense experience.

Chapter 4 is the second SpriteKit chapter in the Starlight Sync arc and carries the highest technical risk in the project per `docs/PHASES.md` risk register. Unlike Chapter 2's frame-based runner mechanics, Chapter 4 requires sub-10ms precision audio-beat synchronization using `CACurrentMediaTime()` as the sole timing source — `Timer`, `DispatchQueue.asyncAfter`, and `Task.sleep` are explicitly prohibited (CLAUDE.md §4.3, §4.5, Design Doc §7.5). The pre-authored beat map (`GameConstants.BeatMap.timestamps`, 32 entries at ~85 BPM spanning ~44.5s) drives all particle spawn scheduling and hit window evaluation. A timing drift of >10ms between audio playback and visual particle spawning would produce perceptible desynchronization that breaks the rhythm game illusion.

Chapter 4 reuses the canonical `SKScene` ↔ `SpriteView` ↔ `FlowCoordinator` integration pattern established in PH-08 (Chapter 2): `willMove(from:)` deterministic cleanup, optional scene nil-out in `SpriteView`, weak coordinator reference, and 120fps ProMotion rendering via `preferredFramesPerSecond = 120`. The pattern is validated — this epic applies it to the rhythm defense domain with the additional complexity of `CACurrentMediaTime()`-anchored beat synchronization and directional input evaluation against configurable tolerance windows.

PH-10 is on the critical path (`PHASES.md` §Critical Path). Any delay directly impacts PH-11 (Chapter 5), PH-13 (Chapter 6), PH-14 (Cross-Chapter Transitions), and ultimately PH-17 (TestFlight Distribution).

---

## Goals

- Replace the `FirewallView` placeholder with a production-quality SpriteKit rhythm defense experience implementing Design Doc §3.5 in its entirety: OLED black deep-space background (`#000000`), center-screen otter bubble shield (`img_bubble_shield`), noise particles (`sprite_noise_particle`) spawning from left/right screen edges on beat map timestamps synced to `audio_bgm_main` via `CACurrentMediaTime()`, directional tap detection (left/right screen half), hit window evaluation at ±150ms default tolerance with `sfx_shield_impact` on successful deflection, miss tracking, survival win condition (~45s / all 32 beats processed), and Auto-Assist hit window widening to ±300ms after 5 misses.
- Create `FirewallScene.swift` as an `SKScene` subclass in `Chapters/Chapter4_Firewall/` with deterministic `willMove(from:)` cleanup per CLAUDE.md §4.3: `removeAllActions()`, `removeAllChildren()`, `physicsWorld.contactDelegate = nil`, coordinator reference nil-out.
- Implement `FirewallView.swift` as a `SpriteView` wrapper using the optional scene pattern (`@State var scene: FirewallScene?`) with `.onDisappear` nil-out per CLAUDE.md §4.3, reporting chapter completion to `FlowCoordinator`.
- Achieve ±10ms beat synchronization accuracy by anchoring all timing to `CACurrentMediaTime()` at audio playback start — no `Timer`, `DispatchQueue`, `Task.sleep`, or `AVAudioPlayer.currentTime` as timing source (CLAUDE.md §4.3, §4.5, Design Doc §7.5).
- Target 120fps ProMotion rendering via `preferredFramesPerSecond = 120` in the `SpriteView` initializer and `didMove(to:)`, with all movement bound to delta time from `update(_:)` timestamps — zero frame-count-dependent behavior.
- Validate that the beat map synchronization pattern and directional tap detection architecture are correct for PH-16 (On-Device QA) tuning.
- Ensure all tuning values reference `GameConstants` namespace and all asset identifiers reference type-safe enums — zero magic numbers, zero stringly-typed access.

## Non-Goals

- **No modifications to FlowCoordinator, AudioManager, HapticManager, AssetPreloadCoordinator, or GameConstants.** These components are complete (PH-02 through PH-06). FirewallScene and FirewallView consume their public APIs only. If an API gap is discovered, it is documented as a blocking issue, not resolved within this epic.
- **No runtime FFT or audio analysis.** Design Doc §3.5 explicitly states "No runtime FFT analysis." All beat timing is driven by the pre-authored `GameConstants.BeatMap.timestamps` array. No spectral decomposition, no amplitude envelope detection, no dynamic beat extraction.
- **No cross-chapter transition orchestration.** The `matchedGeometryEffect` spatial transitions, BGM cross-fade between chapters, and SpriteView→SwiftUI memory cleanup sequencing are PH-14 scope. This epic verifies that FirewallScene's `willMove(from:)` cleanup is correct; PH-14 coordinates the full transition sequence.
- **No beat map authoring or modification.** The beat map was authored in PH-06 (`GameConstants.BeatMap.timestamps`, 32 entries). PH-16 (On-Device QA) owns beat map tuning refinement. This epic consumes the beat map as-is.
- **No custom particle emitter effects beyond sprite-based noise nodes.** Design Doc §3.5 specifies noise particles and the bubble shield as visual elements. No `SKEmitterNode` particle systems, no shield shatter effects, no environmental particle layers beyond what the Design Doc enumerates.
- **No unit tests for FirewallScene or FirewallView.** `SKScene` rhythm sync logic is validated by on-device QA (PH-16) per Design Doc §13.2 ("Audio-haptic sync in Chapter 4 — Subjective; beat map hit windows verified by feel"). Beat map data validation (monotonic ordering, within-duration bounds) is covered by PH-15 unit tests, not this epic.
- **No SwiftUI overlay HUD.** Game state display (progress, shield feedback) is rendered using SpriteKit nodes within the scene to avoid additional SwiftUI↔SpriteKit state synchronization complexity, consistent with the CH2_01 architectural precedent.

---

## Technical Approach

**Scene Architecture.** `FirewallScene` is an `SKScene` subclass at `StarlightSync/Chapters/Chapter4_Firewall/FirewallScene.swift`. The scene uses `scaleMode = .resizeFill` to adapt to the device screen. The background is true OLED black (`#000000`) per CLAUDE.md §4.2 ("True OLED black where specified — Chapters 1, 4"). The node hierarchy consists of three depth layers separated by `zPosition`: (1) the center-screen bubble shield (`zPosition: 0`) — a single `SKSpriteNode` textured with `img_bubble_shield` from the preloaded sprite atlas, positioned at the scene center, sized proportionally to the scene dimensions; (2) the game entity layer (`zPosition: 1–5`) hosting noise particle sprites spawned from screen edges and moving toward the shield; and (3) a state display layer (`zPosition: 10`) with `SKLabelNode` elements showing beat progress (e.g., beats survived / total) and optional shield status. The scene's `didMove(to:)` configures `preferredFramesPerSecond`, sets the black background, creates the shield node, and prepares the beat scheduling system. No physics bodies or `physicsWorld.contactDelegate` are required for this chapter — hit detection is time-based (beat window evaluation), not position-based collision. The `physicsWorld.contactDelegate` is still nil-outed in `willMove(from:)` for pattern consistency with CH2_01.

**Beat Synchronization System.** The core timing architecture uses `CACurrentMediaTime()` as the sole clock source, anchored at the moment `audio_bgm_main` begins playback. When `FirewallScene` transitions to the `.playing` state, it calls `AudioManager.shared.playSFX(named:)` or triggers BGM playback (the track is already playing via cross-fade from Chapters 1–3; if not, playback starts explicitly) and records `audioStartTime = CACurrentMediaTime()`. In each `update(_:)` frame, the scene computes `elapsedAudioTime = CACurrentMediaTime() - audioStartTime` and compares against the beat map array. A `nextBeatIndex` pointer tracks which beat to process next. When `elapsedAudioTime >= beatMap[nextBeatIndex] - spawnLeadTime`, a noise particle is spawned from a random screen edge (left or right). The `spawnLeadTime` constant (a tunable in the scene, e.g., ~0.6–0.8s) determines how far in advance of the beat the particle begins its travel, giving the player visual warning. The particle's `SKAction.moveTo` duration equals `spawnLeadTime`, so the particle arrives at the shield zone at precisely `beatMap[nextBeatIndex]` in audio time. Each spawned particle carries metadata: its `beatIndex` and `approachDirection` (`.left` or `.right`), stored as properties on a lightweight `NoiseParticle` wrapper or via `userData` on the `SKSpriteNode`.

**Directional Tap Detection and Hit Window Evaluation.** The screen is logically divided into left and right halves at `size.width / 2`. On `touchesBegan(_:with:)`, the scene determines the tap direction based on the touch location's x-coordinate relative to the screen center. The tap timestamp is captured as `tapTime = CACurrentMediaTime() - audioStartTime` (audio-relative time). The scene then evaluates the tap against pending beats: for each unresolved beat within the active window (beats where `|tapTime - beatTimestamp| <= hitWindow`), if the tap direction matches the noise particle's approach direction, the beat is marked as a "hit." The hit window is `GameConstants.Difficulty.firewallDefaultHitWindow` (±150ms) by default, widening to `GameConstants.Difficulty.firewallAssistedHitWindow` (±300ms) when Auto-Assist activates. On a successful hit, `sfx_shield_impact` plays via `SKAction.playSoundFileNamed` (consistent with CH2_01's SFX pattern), the noise particle executes a destruction animation (`SKAction.group` of scale-down + fade-out + `removeFromParent()`), and the shield node pulses briefly (scale bounce via `SKAction.sequence`). If no matching beat is found within the window, the tap is ignored (no penalty for extraneous taps — only beats that pass the window undefended count as misses).

**Miss Detection.** A beat is classified as "missed" when `elapsedAudioTime > beatTimestamp + hitWindow` and no successful tap was registered for that beat. Miss detection runs in `update(_:)` by advancing a `missCheckIndex` pointer through the beat map. When a miss is detected, the miss counter increments, the noise particle that reached the shield executes an impact animation (shield flash + particle fade), and no SFX plays (silence signals failure). The missed noise particle is removed from the scene after the impact animation completes.

**Auto-Assist.** When `missCount >= GameConstants.AutoAssist.firewallMissThreshold` (5), the active hit window switches from `firewallDefaultHitWindow` to `firewallAssistedHitWindow`. Activation is silent — no UI notification, no visual indicator, no text overlay — preserving the "illusion of skill and success" per Design Doc §3.8. The widened window (±300ms) makes it "effectively impossible to fail" per Design Doc §3.5. Auto-Assist applies to all subsequent beats immediately upon activation. It does not reset if the player continues to miss after activation.

**Win Condition and Game State.** The game uses a `private enum GameState { case ready, playing, won }` to gate `update(_:)` logic. The win condition is survival: when all 32 beats in the beat map have been processed (either hit or missed) AND `elapsedAudioTime >= GameConstants.Timing.firewallDuration`, the game transitions to `.won`. A victory overlay displays, followed by `coordinator?.completeCurrentChapter()` guarded by the `.won` state to prevent double-fire. There is no "death" state in Chapter 4 — misses degrade the shield visually but do not end the game. The player always survives to win (Auto-Assist ensures this). The welcome overlay (consistent with CH2_01 pattern) introduces the chapter context ("Protecting the Peace") and instructions before gameplay begins.

**SpriteView Integration.** `FirewallView` replaces the PH-02 placeholder. The view holds the scene as `@State private var scene: FirewallScene?` — the optional pattern per CLAUDE.md §4.3, identical to the `PacketRunView` implementation. On `.onAppear`, the scene is created, configured with `scaleMode = .resizeFill`, and assigned a `weak var coordinator: FlowCoordinator?` reference. `SpriteView` is initialized with `preferredFramesPerSecond: GameConstants.Physics.targetFrameRate` and `options: [.ignoresSiblingOrder]`. On `.onDisappear`, the scene reference is set to `nil`, triggering scene deallocation and `willMove(from:)` cleanup. The `CADisableMinimumFrameDurationOnPhone` Info.plist flag (added in PH-08) enables 120fps on ProMotion hardware.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| `FlowCoordinator` with `completeCurrentChapter()` API and `@Environment` injection | COORD_01, COORD_02 (PH-02) | Complete | iOS Engineer |
| `GameConstants.Timing.firewallDuration` (45.0s), `GameConstants.AutoAssist.firewallMissThreshold` (5), `GameConstants.Difficulty.firewallDefaultHitWindow` (0.150), `GameConstants.Difficulty.firewallAssistedHitWindow` (0.300), `GameConstants.Physics.targetFrameRate` (120) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `GameConstants.BeatMap.timestamps` (32 entries, 0.706–44.471s) and `GameConstants.BeatMap.trackDuration` (174.66s) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `GameConstants.SpriteAsset.noiseParticle`, `.bubbleShield`, `GameConstants.SpriteAtlas.sprites` | CONST_01 (PH-06) | Complete | iOS Engineer |
| `GameConstants.AudioAsset.sfxShieldImpact` (`sfx_shield_impact`) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `AudioManager.shared` with `audio_bgm_main` already playing (cross-faded from Chapters 1–3) and `sfx_shield_impact` preloaded | AUDIO_01 (PH-03), ASSET_03 (PH-05) | Complete | iOS Engineer |
| `img_bubble_shield` sprite in `Assets.xcassets/Sprites.spriteatlas/`, `sprite_noise_particle` sprite in `Assets.xcassets/Sprites.spriteatlas/` | ASSET_01 (PH-05) | Complete | iOS Engineer |
| `AssetPreloadCoordinator` with sprite atlas preloaded via `SKTextureAtlas.preload()` — textures resident in GPU cache before Chapter 4 begins | ASSET_02 (PH-05) | Complete | iOS Engineer |
| SpriteKit lifecycle pattern validated — `willMove(from:)` cleanup, optional scene nil-out, weak coordinator reference, 120fps configuration, `CADisableMinimumFrameDurationOnPhone` Info.plist flag | CH2_01 (PH-08) | Complete | iOS Engineer |
| Chapter 3 (PH-09) complete — runtime prerequisite for sequential navigation to Chapter 4 via FlowCoordinator linear state machine | CH3_01 (PH-09) | Complete | iOS Engineer |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| Chapter 4 complete — sequential chapter progression continues | PH-11 (Chapter 5 Blueprint) | Chapter 5 is unlocked when Chapter 4 completes via FlowCoordinator |
| Beat synchronization pattern validated — `CACurrentMediaTime()` anchor, beat map consumption, hit window evaluation | PH-16 (On-Device QA) | QA playtest validates audio-beat sync perceptibility, hit window feel, Auto-Assist activation |
| SpriteView memory cleanup verified for second SpriteKit chapter | PH-14 (Cross-Chapter Transitions) | Cross-chapter transition polish depends on confirmed clean SpriteKit deallocation across both SpriteKit chapters |
| Chapter 4 playable for on-device validation | PH-16 (On-Device QA) | QA playtest validates rhythm feel, directional tap responsiveness, shield feedback, and beat map timing |

---

## Stories

### Story 1: Create FirewallScene with OLED black background, bubble shield, and beat timing system

Create `FirewallScene.swift` as an `SKScene` subclass with OLED black background, center-screen bubble shield sprite, and the `CACurrentMediaTime()`-anchored timing infrastructure. The scene configures 120fps rendering, creates the shield node from the preloaded sprite atlas, and establishes the `audioStartTime` anchor point and `nextBeatIndex` pointer that subsequent stories consume.

**Acceptance Criteria:**

- [ ] File created at `StarlightSync/Chapters/Chapter4_Firewall/FirewallScene.swift`.
- [ ] `FirewallScene` is a `final class` subclass of `SKScene`.
- [ ] `didMove(to:)` sets `self.view?.preferredFramesPerSecond = GameConstants.Physics.targetFrameRate`.
- [ ] `backgroundColor` is set to `SKColor.black` (`#000000` — true OLED black per CLAUDE.md §4.2).
- [ ] Center-screen bubble shield: `SKSpriteNode` textured with `GameConstants.SpriteAsset.bubbleShield.rawValue` from the preloaded `SKTextureAtlas` (`GameConstants.SpriteAtlas.sprites.rawValue`), positioned at scene center (`CGPoint(x: size.width / 2, y: size.height / 2)`), sized proportionally to the scene (e.g., ~30–40% of the smaller scene dimension).
- [ ] Shield node has `zPosition: 0`. Game entity layer at `zPosition: 1–5`. HUD at `zPosition: 10`. Overlay at `zPosition: 50`.
- [ ] `audioStartTime: CFTimeInterval` property initialized to `0`, set when gameplay begins.
- [ ] `nextBeatIndex: Int` property initialized to `0`, tracking the next beat map entry to process.
- [ ] `update(_:)` method computes delta time: `let deltaTime = currentTime - lastUpdateTime; lastUpdateTime = currentTime`, guarding against the first-frame zero-delta case.
- [ ] `private enum GameState { case ready, playing, won }` defined. `update(_:)` logic gated on `.playing` state.
- [ ] `weak var coordinator: FlowCoordinator?` property for chapter completion signaling.
- [ ] Shield size and position are named constants (not magic numbers).
- [ ] No `Timer`, `DispatchQueue`, or `Task.sleep` for any timing.

**Dependencies:** None
**Completion Signal:** FirewallScene renders an OLED black background with the centered bubble shield sprite at 120fps. No noise particles, no tap detection, no audio sync yet. The timing infrastructure (`audioStartTime`, `nextBeatIndex`, delta time) is in place for subsequent stories.

---

### Story 2: Implement beat-synced noise particle spawning from screen edges

Wire the beat map scheduling system into `update(_:)`. At each frame, compare `elapsedAudioTime` against `GameConstants.BeatMap.timestamps[nextBeatIndex]` minus a configurable `spawnLeadTime`. When the spawn threshold is reached, create a noise particle (`sprite_noise_particle`) at a random screen edge (left or right) and animate it toward the center shield zone over `spawnLeadTime` duration so it arrives at the shield precisely at the beat timestamp.

**Acceptance Criteria:**

- [ ] `elapsedAudioTime` computed in `update(_:)` as `CACurrentMediaTime() - audioStartTime` while `gameState == .playing`.
- [ ] `spawnLeadTime: TimeInterval` is a named scene-internal constant (e.g., 0.7s — tunable in PH-16) representing how far in advance of the beat the particle spawns.
- [ ] When `elapsedAudioTime >= GameConstants.BeatMap.timestamps[nextBeatIndex] - spawnLeadTime`, a noise particle spawns and `nextBeatIndex` increments.
- [ ] Noise particles are `SKSpriteNode` instances textured with `GameConstants.SpriteAsset.noiseParticle.rawValue` from the preloaded sprite atlas.
- [ ] Each particle spawns at a random screen edge: left (`x = -particle.size.width/2`) or right (`x = size.width + particle.size.width/2`), at a `y` position of the shield's center (or randomized within a range around the shield center for visual variety).
- [ ] Each particle stores its `beatIndex: Int` and `approachDirection` (left or right) — either via a subclass, `userData`, or a lightweight tracking dictionary keyed by the `SKSpriteNode` reference.
- [ ] Particle moves toward the shield center via `SKAction.moveTo(x: shieldCenterX, duration: spawnLeadTime)`. The particle arrives at the shield zone at precisely `beatTimestamp` in audio-relative time.
- [ ] Particle `zPosition` is above the shield (e.g., `zPosition: 2`).
- [ ] Particles that are neither hit nor missed are cleaned up by the miss detection system (Story 4) or scene teardown.
- [ ] Beat index bounds checking: spawning stops when `nextBeatIndex >= GameConstants.BeatMap.timestamps.count`.
- [ ] All `SKAction.run` closures use `[weak self]`.
- [ ] No `SKAction.perform(_:onTarget:)`.
- [ ] All timing derived from `CACurrentMediaTime()`. No `Timer`, `DispatchQueue`, `Task.sleep`, or `AVAudioPlayer.currentTime`.

**Dependencies:** CH4_01-S1 (scene with shield and timing infrastructure must exist)
**Completion Signal:** Noise particles spawn from alternating left/right screen edges at beat map intervals, travel toward the center shield, and arrive at the shield zone synchronized with the audio beats. No tap interaction or scoring yet — particles accumulate at the shield or pass through it.

---

### Story 3: Implement directional tap detection with hit window scoring and sfx_shield_impact feedback

Add left/right tap detection. On `touchesBegan`, determine tap direction based on touch x-coordinate relative to screen center. Evaluate the tap against pending beats within the active hit window. If tap direction matches the approaching noise particle's direction and timing is within tolerance, register a hit: play `sfx_shield_impact`, destroy the noise particle with a visual effect, and pulse the shield.

**Acceptance Criteria:**

- [ ] Screen logically divided at `size.width / 2`. Tap with `touch.location(in: self).x < size.width / 2` is a left tap; otherwise right tap.
- [ ] On `touchesBegan(_:with:)`: tap timestamp captured as `tapTime = CACurrentMediaTime() - audioStartTime`.
- [ ] Hit evaluation iterates pending beats (those with spawned particles not yet resolved) and checks: `abs(tapTime - beatTimestamp) <= activeHitWindow` AND `tapDirection == particle.approachDirection`.
- [ ] `activeHitWindow` defaults to `GameConstants.Difficulty.firewallDefaultHitWindow` (0.150s). Updated by Auto-Assist (Story 5).
- [ ] On successful hit: beat marked as resolved (hit), noise particle runs destruction animation (`SKAction.group([.scale(to: 0.1, duration: 0.15), .fadeOut(withDuration: 0.15)])` followed by `.removeFromParent()`).
- [ ] On successful hit: `sfx_shield_impact` plays via `SKAction.playSoundFileNamed` using the bundle-relative path to `sfx_shield_impact.m4a`, consistent with CH2_01's SFX pattern.
- [ ] On successful hit: shield node pulses — a brief scale bounce (`SKAction.sequence([.scale(to: 1.08, duration: 0.08), .scale(to: 1.0, duration: 0.08)])`).
- [ ] If no matching beat is found within the window, the tap is ignored. No penalty for extraneous taps — only undefended beats that pass the window count as misses (Story 4).
- [ ] If multiple beats fall within the window simultaneously (unlikely at ~85 BPM but defensively handled), the closest beat by `abs(tapTime - beatTimestamp)` is selected.
- [ ] Hit counter increments on each successful hit.
- [ ] `touchesBegan` is gated on `gameState == .playing`.
- [ ] SFX failure does not block gameplay — audio failure isolation per CLAUDE.md §4.5.
- [ ] No direct `AVAudioPlayer` access from FirewallScene — SFX via `SKAction.playSoundFileNamed` for zero-latency in-scene playback.

**Dependencies:** CH4_01-S2 (noise particles must be spawning with beat metadata for hit evaluation)
**Completion Signal:** Tapping the correct side of the screen within ±150ms of a beat timestamp destroys the approaching noise particle with a visual effect, plays `sfx_shield_impact`, and pulses the shield. Tapping the wrong side or outside the window has no effect. Hits are counted.

---

### Story 4: Implement miss detection, shield impact feedback, and survival progress HUD

Add miss detection in `update(_:)`: when a beat's timestamp passes beyond `beatTimestamp + hitWindow` without a successful hit, classify it as a miss. Increment the miss counter, execute a shield impact animation for the undefended noise particle, and update the HUD. Display a progress indicator showing beats survived (hit + missed) out of total.

**Acceptance Criteria:**

- [ ] `missCheckIndex: Int` pointer tracks the next beat to evaluate for misses, advancing through the beat map independently of `nextBeatIndex` (spawn pointer).
- [ ] In `update(_:)`, when `elapsedAudioTime > GameConstants.BeatMap.timestamps[missCheckIndex] + activeHitWindow` and the beat at `missCheckIndex` is not marked as hit, the beat is classified as missed.
- [ ] On miss: `missCount` increments. The noise particle (if still in scene) runs an impact animation — shield flashes red briefly (`SKAction.sequence([.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.1), .colorize(withColorBlendFactor: 0, duration: 0.2)])` on the shield node), and the noise particle fades out (`SKAction.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()])`).
- [ ] `missCheckIndex` advances after processing each beat (whether hit or missed).
- [ ] A progress HUD `SKLabelNode` displays the current beat progress (e.g., `"12 / 32"` showing beats processed out of total), positioned in the upper region of the scene at `zPosition: 10`.
- [ ] HUD label uses chapter-appropriate styling — not default white `SKLabelNode` styling, not system colors. A muted sci-fi tone consistent with the deep-space aesthetic (e.g., dim cyan or translucent white).
- [ ] HUD updates each time a beat is resolved (hit or miss).
- [ ] All timing comparisons use `CACurrentMediaTime() - audioStartTime` — no frame-count-based miss detection.
- [ ] All HUD positioning values are named constants (not magic numbers).

**Dependencies:** CH4_01-S3 (hit detection establishes the resolved-beat tracking that miss detection reads)
**Completion Signal:** Beats that pass the hit window without a successful tap are classified as misses. The shield flashes on miss, the noise particle fades away, and the miss counter increments. A progress HUD shows beats processed out of total, updating in real time.

---

### Story 5: Implement Auto-Assist hit window widening after 5 misses

Track cumulative miss count. After `GameConstants.AutoAssist.firewallMissThreshold` (5) misses, widen the active hit window from `GameConstants.Difficulty.firewallDefaultHitWindow` (±150ms) to `GameConstants.Difficulty.firewallAssistedHitWindow` (±300ms). Activation is silent and persistent for the remainder of the chapter session.

**Acceptance Criteria:**

- [ ] `missCount: Int` is a scene property that increments on each missed beat and persists across the gameplay session (NOT reset during gameplay).
- [ ] `isAutoAssistActive: Bool` computed as `missCount >= GameConstants.AutoAssist.firewallMissThreshold`.
- [ ] `activeHitWindow: TimeInterval` computed as `isAutoAssistActive ? GameConstants.Difficulty.firewallAssistedHitWindow : GameConstants.Difficulty.firewallDefaultHitWindow`.
- [ ] Auto-Assist activates on the beat immediately following the 5th miss — the widened window applies to all subsequent beat evaluations.
- [ ] Auto-Assist activation is silent — no UI notification, no visual indicator, no text overlay. The hit window widens transparently, preserving the "illusion of skill and success" per Design Doc §3.8.
- [ ] Auto-Assist does not reset if the player continues to miss after activation. Once active, it remains active for the session.
- [ ] The widened ±300ms window makes it "effectively impossible to fail" per Design Doc §3.5 — at ~85 BPM (~706ms between beats), a ±300ms window covers ~85% of the inter-beat interval.
- [ ] All threshold and window values are sourced from `GameConstants` — zero hardcoded numbers for Auto-Assist logic.
- [ ] Hit detection (Story 3) and miss detection (Story 4) both reference `activeHitWindow` for their tolerance comparisons.

**Dependencies:** CH4_01-S3 (hit detection uses `activeHitWindow`), CH4_01-S4 (miss detection increments `missCount`)
**Completion Signal:** After accumulating 5 misses, subsequent beat evaluations use the ±300ms window instead of ±150ms. The widened window is visibly easier to hit (taps that previously failed now succeed) without any on-screen notification of the change.

---

### Story 6: Implement welcome overlay, audio start, win condition, and chapter completion

Add a welcome overlay introducing Chapter 4 with context ("Protecting the Peace") and instructions. On dismissal, start audio playback timing (anchor `audioStartTime`), transition to `.playing` state. Implement win condition: when all 32 beats are processed and `elapsedAudioTime >= GameConstants.Timing.firewallDuration`, transition to `.won`, display a victory overlay, and report completion to `FlowCoordinator`.

**Acceptance Criteria:**

- [ ] Welcome overlay renders on scene setup (consistent with CH2_01 pattern): dimmed background, chapter title "THE FIREWALL", context text "Protecting the Peace", instruction text "Tap the side where threats approach", and a pulsing `[ PLAY ]` button.
- [ ] Welcome overlay styling uses chapter-appropriate colors — sci-fi tones on OLED black, not default system colors. Consistent with the deep-space shield aesthetic.
- [ ] On `[ PLAY ]` tap: welcome overlay fades out, `audioStartTime = CACurrentMediaTime()` is recorded, `gameState` transitions to `.playing`, and the HUD becomes visible.
- [ ] `audio_bgm_main` is assumed to already be playing (continuous loop from Chapters 1–3 via `AudioManager` cross-fade). If for any reason it is not playing, this story does NOT start the BGM — that is AudioManager's responsibility. The `audioStartTime` anchor is the critical synchronization point.
- [ ] **Assumption:** The beat map timestamps in `GameConstants.BeatMap.timestamps` are authored relative to the start of the `audio_bgm_main` track. If BGM is already mid-playback (looping from earlier chapters), the scene must either: (a) re-trigger BGM playback from the beginning and anchor to that start, or (b) use `AudioManager`'s current playback position as the offset. **The chosen approach is (a):** request `AudioManager` to restart `audio_bgm_main` from the beginning when the `[ PLAY ]` button is tapped, then anchor `audioStartTime = CACurrentMediaTime()`. This guarantees beat map alignment regardless of prior playback state.
- [ ] Win condition check in `update(_:)`: when `nextBeatIndex >= GameConstants.BeatMap.timestamps.count` (all beats spawned) AND `missCheckIndex >= GameConstants.BeatMap.timestamps.count` (all beats resolved) AND `elapsedAudioTime >= GameConstants.Timing.firewallDuration`, transition `gameState` to `.won`.
- [ ] On win: a victory overlay displays after a brief pause (`SKAction.wait(forDuration:)`) — consistent with CH2_01 pattern. Overlay includes chapter completion message (e.g., "NOISE NEUTRALIZED"), beat stats (hits/total), and a pulsing `[ CONTINUE ]` button.
- [ ] On `[ CONTINUE ]` tap: `coordinator?.completeCurrentChapter()` fires exactly once. The `.won` state guard prevents double-fire on subsequent taps.
- [ ] No death/restart flow. Chapter 4 has no fail state — misses degrade the experience but the player always survives to win (Design Doc §3.5, §3.8).
- [ ] All `SKAction.run` closures use `[weak self]`.
- [ ] No `Timer`, `DispatchQueue`, or `Task.sleep` for any timing.

**Dependencies:** CH4_01-S2 (beat spawning provides `nextBeatIndex`), CH4_01-S4 (miss tracking provides `missCheckIndex`), CH4_01-S5 (Auto-Assist may be active during gameplay)
**Completion Signal:** Welcome overlay introduces Chapter 4. Tapping PLAY starts beat-synced gameplay. Surviving all 32 beats shows a victory overlay with stats. Tapping CONTINUE advances to Chapter 5 via FlowCoordinator. No fail state exists.

---

### Story 7: Implement FirewallView SpriteView wrapper with lifecycle management

Replace the `FirewallView` placeholder with a `SpriteView` wrapper that creates and manages the `FirewallScene` lifecycle. Use the optional scene pattern (`@State var scene: FirewallScene?`) with `.onDisappear` nil-out. Wire `FlowCoordinator` communication via weak reference injection. Configure `SpriteView` for 120fps ProMotion rendering with draw call optimization. This implementation mirrors `PacketRunView` (CH2_01-S7) exactly.

**Acceptance Criteria:**

- [ ] `FirewallView.swift` body is replaced entirely — the placeholder `ZStack` with `Color.black`, `Text` labels, and `Button` are removed.
- [ ] `@State private var scene: FirewallScene?` holds the scene as an optional.
- [ ] `@Environment(FlowCoordinator.self) private var coordinator` reads the coordinator from the SwiftUI environment.
- [ ] On `.onAppear`: a new `FirewallScene` is created with `size` derived from the screen bounds, `scaleMode` set to `.resizeFill`, and the coordinator assigned via the `weak var coordinator: FlowCoordinator?` property on the scene.
- [ ] `SpriteView` is initialized with `preferredFramesPerSecond: GameConstants.Physics.targetFrameRate` and `options: [.ignoresSiblingOrder]`.
- [ ] The view body uses `Group` or `if let scene` to conditionally render `SpriteView` only when the scene is non-nil. No force unwraps on the optional scene.
- [ ] On `.onDisappear`: `scene = nil`. Scene deallocation triggers `willMove(from:)` cleanup.
- [ ] `#Preview` macro is present with a functioning preview that provides a `FlowCoordinator` environment object.
- [ ] View body does not exceed 80 lines.
- [ ] No `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject`, or Combine usage.
- [ ] No UIKit imports (`UIViewController`, `UIView`, `UIHostingController`).
- [ ] Reduce Motion: if `UIAccessibility.isReduceMotionEnabled` is true, noise particle movement uses instant position placement instead of animated travel, and shield pulse effects are replaced with opacity changes. This check is communicated to the scene via a property set during scene creation.

**Dependencies:** CH4_01-S1 through CH4_01-S6 (complete scene implementation)
**Completion Signal:** FirewallView renders a playable SpriteKit rhythm defense scene via SpriteView at 120fps. The scene is created on appear, plays the full rhythm game loop, and is set to nil on disappear. FlowCoordinator advances to Chapter 5 on win. No SpriteView memory retention after transition.

---

### Story 8: Register source files in pbxproj, implement willMove(from:) cleanup, and validate governance compliance

Register the new `FirewallScene.swift` in `project.pbxproj`. Implement deterministic `willMove(from:)` cleanup in `FirewallScene` per CLAUDE.md §4.3. Validate that the full Chapter 4 implementation passes all build and governance checks.

**Acceptance Criteria:**

- [ ] `FirewallScene.swift` has a `PBXFileReference` entry in `project.pbxproj` (FileRef: next available UUID per memory conventions — FileRef 16+: `B7D1E38A2D5F6A0100000016` or higher).
- [ ] A `PBXBuildFile` entry references the `FirewallScene.swift` file reference (BuildFile 14+: `B7D1E38A2D5F6A0100000114` or higher).
- [ ] The file reference is listed in the `Chapter4_Firewall` `PBXGroup` children array.
- [ ] The build file is listed in the `PBXSourcesBuildPhase` files array.
- [ ] `FirewallView.swift` already has pbxproj registration from COORD_02 — no new registration needed for the modified file.
- [ ] `FirewallScene.willMove(from:)` implements deterministic cleanup in strict order per CLAUDE.md §4.3:
  1. `removeAllActions()`
  2. `removeAllChildren()`
  3. `physicsWorld.contactDelegate = nil` (nil-out for pattern consistency even though no contact delegate is set)
  4. `coordinator = nil` (nil-out external weak reference)
- [ ] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0, zero errors, zero warnings (excluding benign `appintentsmetadataprocessor` warning).
- [ ] `python3 scripts/audit.py --all` passes with zero violations (7/7 checks: PZ-001, FU-001, DA-001, DP-001, SL-001, CC-001, CB-001).
- [ ] No Protocol Zero violations in either file — no AI attribution in headers, comments, or identifiers.
- [ ] No force unwraps (`!`) in either file.
- [ ] No `print` statements. Diagnostics use `os.Logger` gated behind `#if DEBUG` if needed.
- [ ] No Combine imports or `ObservableObject` / `@Published` / `@StateObject` / `@EnvironmentObject` usage.
- [ ] No deprecated APIs.
- [ ] No `SKAction.perform(_:onTarget:)` calls anywhere in `FirewallScene`.
- [ ] All `SKAction.run` closures use `[weak self]`.
- [ ] All timing uses `CACurrentMediaTime()`, `SKAction.wait(forDuration:)`, or delta time — no `Timer`, `DispatchQueue`, `Task.sleep`, or `AVAudioPlayer.currentTime`.
- [ ] All asset references use `GameConstants` type-safe enums — zero string literals for asset identifiers.
- [ ] All tuning values are named constants — zero magic numbers.
- [ ] `#Preview` macro present on `FirewallView`.
- [ ] `FirewallView` body ≤80 lines.

**Dependencies:** CH4_01-S1 through CH4_01-S7 (all implementation stories complete)
**Completion Signal:** Clean build with zero errors. Audit passes 7/7. FirewallScene registered in all 4 pbxproj sections. `willMove(from:)` cleanup implements the deterministic 4-step teardown. All governance rules satisfied. PH-10 is ready for on-device validation.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| Audio-beat synchronization jitter causes perceptible desync between noise particle arrival and audio beat (>10ms drift) | 5 | 3 | 15 | Mandate `CACurrentMediaTime()` as the sole timing source. Record `audioStartTime` at the exact frame BGM playback restarts. Never use `AVAudioPlayer.currentTime` (drifts on seek and interruption recovery per CLAUDE.md §4.5). Never use `Timer`, `DispatchQueue.asyncAfter`, or `Task.sleep` (scheduling jitter per Design Doc §7.5). Validate sync perceptually during PH-16 on-device QA. If drift is detected, investigate `AVAudioPlayer.prepareToPlay()` latency and adjust `audioStartTime` by the measured playback onset delay. | iOS Engineer |
| `SpriteView` retains `SKScene` reference after `.onDisappear`, causing memory leak on chapter transition (Design Doc §11.5) | 5 | 2 | 10 | Use optional scene pattern: `@State var scene: FirewallScene?` set to `nil` in `.onDisappear`. Implement `willMove(from:)` deterministic cleanup as secondary defense. Pattern validated in PH-08 (PacketRunView). If leak persists, force recreation via `.id()` modifier on the `SpriteView`. Verify deallocation with Instruments Allocations trace during PH-16. | iOS Engineer |
| Hit window ±150ms feels too tight or too loose at ~85 BPM, leading to frustrating or trivial gameplay | 3 | 3 | 9 | `firewallDefaultHitWindow` and `firewallAssistedHitWindow` are named constants in `GameConstants`, trivially tunable during PH-16 QA. `spawnLeadTime` is a scene-internal tunable controlling visual warning duration. Auto-Assist at ±300ms provides a safety net that makes failure effectively impossible. Initial values match Design Doc §3.5 specification. | iOS Engineer |
| `audio_bgm_main` is mid-loop when Chapter 4 starts, causing beat map misalignment if BGM is not restarted | 4 | 3 | 12 | Explicitly restart `audio_bgm_main` from the beginning when the `[ PLAY ]` button is tapped. Anchor `audioStartTime = CACurrentMediaTime()` at the restart moment. Beat map timestamps are authored relative to track start (offset 0). This guarantees alignment regardless of prior playback state. The AudioManager's cross-fade mechanism handles the restart transition. | iOS Engineer |
| Noise particle visual travel does not feel synchronized with audio despite correct `CACurrentMediaTime()` timing | 3 | 2 | 6 | `spawnLeadTime` controls the visual anticipation window. If particles arrive visually early or late relative to the audio beat, adjust `spawnLeadTime` to compensate for perceived latency. This is a PH-16 tuning parameter, not a code defect. | iOS Engineer |
| `SKTextureAtlas` texture lookup returns nil for `sprite_noise_particle` or `img_bubble_shield` if atlas was not preloaded | 4 | 1 | 4 | ASSET_02 (PH-05) preloads all sprite atlas textures during the launch sequence. Atlas textures are retained for the session per Design Doc §7.9.4. Texture lookup uses `SKTextureAtlas(named:).textureNamed(:)` which returns a placeholder texture rather than crashing if the atlas is missing. | iOS Engineer |

---

## Definition of Done

- [ ] All 8 stories completed and individually verified.
- [ ] `FirewallScene.swift` created at `Chapters/Chapter4_Firewall/FirewallScene.swift` with full rhythm defense implementation per Design Doc §3.5.
- [ ] `FirewallView.swift` replaces the PH-02 placeholder with `SpriteView` wrapper and optional scene pattern.
- [ ] OLED black background (`#000000`) per CLAUDE.md §4.2 specification for Chapter 4.
- [ ] Center-screen bubble shield (`img_bubble_shield`) renders from preloaded sprite atlas.
- [ ] Noise particles (`sprite_noise_particle`) spawn from left/right screen edges at beat map timestamps, synchronized to `audio_bgm_main` via `CACurrentMediaTime()`.
- [ ] `spawnLeadTime` controls visual anticipation — particles arrive at the shield zone at the beat timestamp.
- [ ] Directional tap detection evaluates left/right screen half with hit window ±150ms (`GameConstants.Difficulty.firewallDefaultHitWindow`).
- [ ] Successful hit plays `sfx_shield_impact`, destroys noise particle with visual effect, and pulses the shield.
- [ ] Missed beats (undefended past `beatTimestamp + hitWindow`) trigger shield flash and miss counter increment.
- [ ] Auto-Assist: after 5 misses (`GameConstants.AutoAssist.firewallMissThreshold`), hit window widens to ±300ms (`GameConstants.Difficulty.firewallAssistedHitWindow`).
- [ ] Auto-Assist activation is silent — no player notification, preserving the illusion of skill.
- [ ] Win condition: all 32 beats processed AND `elapsedAudioTime >= GameConstants.Timing.firewallDuration`. No fail state.
- [ ] `FlowCoordinator.completeCurrentChapter()` advances to Chapter 5 on win, called exactly once.
- [ ] Welcome overlay introduces chapter context. Victory overlay shows beat stats with CONTINUE button.
- [ ] `willMove(from:)` implements deterministic cleanup: `removeAllActions()`, `removeAllChildren()`, `physicsWorld.contactDelegate = nil`, coordinator nil-out.
- [ ] `SpriteView` uses optional scene pattern with `.onDisappear` nil-out.
- [ ] `preferredFramesPerSecond = 120` configured in both `SpriteView` initializer and `didMove(to:)`.
- [ ] All beat timing uses `CACurrentMediaTime()` — no `Timer`, `DispatchQueue`, `Task.sleep`, or `AVAudioPlayer.currentTime`.
- [ ] All movement uses delta time from `update(_:)` or `SKAction` durations — no frame-count-dependent logic.
- [ ] All `SKAction.run` closures use `[weak self]`. No `SKAction.perform(_:onTarget:)`.
- [ ] All asset references use `GameConstants` type-safe enums — zero string literals for asset identifiers.
- [ ] All tuning values are named constants — zero magic numbers.
- [ ] Reduce Motion respected: particle movement and shield effects use simplified alternatives when `isReduceMotionEnabled`.
- [ ] `xcodebuild build` succeeds with zero errors and zero warnings.
- [ ] `scripts/audit.py --all` passes with zero violations (7/7 checks).
- [ ] No Protocol Zero violations.
- [ ] No force unwraps, no `print` statements, no Combine, no deprecated APIs.
- [ ] `#Preview` macro present on `FirewallView`.
- [ ] `FirewallView` body ≤80 lines.
- [ ] `FirewallScene.swift` registered in all 4 required `project.pbxproj` sections.

## Exit Criteria

- [ ] All Definition of Done conditions satisfied.
- [ ] PH-11 (Chapter 5) is unblocked — Chapter 4 completes and FlowCoordinator advances to Chapter 5.
- [ ] PH-14 (Cross-Chapter Transitions) is unblocked — second SpriteKit scene (`FirewallScene`) validates `SpriteView` memory cleanup pattern alongside `PacketRunScene`, confirming the cleanup approach works for both SpriteKit chapters.
- [ ] PH-16 (On-Device QA) can begin Chapter 4 testing — audio-beat sync perceptibility, hit window feel, directional tap responsiveness, Auto-Assist activation, shield feedback, and beat map timing validation.
- [ ] Beat synchronization architecture documented in code: `CACurrentMediaTime()` anchor, beat map consumption via index pointer, hit window evaluation against audio-relative timestamps. Pattern is reviewable for correctness before PH-16 tuning.
- [ ] Epic ID `CH4_01` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
