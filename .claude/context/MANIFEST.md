---
last_updated: 2026-02-15T23:00:00Z
updated_by: claude-opus-4-6
schema_version: 1
---

# Project Manifest

## Current Phase

**PH-07** — Chapter 1: The Handshake — PHASE COMPLETE
Next: PH-08 (Chapter 2 — Packet Run), PH-12 (WebhookService — parallelizable)
Status: Complete

## Blocking Issues

None.

## Recently Completed

- **PH-07 COMPLETE** — Chapter 1: The Handshake (CH1_01, 7/7 stories)
  - HandshakeView: OLED black + img_bg_intro, screen-relative pulsing touchid overlay, 3s DragGesture hold with TimelineView progress ring
  - capacitor_charge.ahap haptic on press with stop-on-release + transient snap, thud.ahap on completion
  - CRTTransitionView: vertical sweep + Canvas scanlines + brightness ramp (~0.6s), Reduce Motion cross-fade
  - Completion sequence: SFX → CRT → BGM start → coordinator advance
  - "HOLD TO CONNECT" instruction text at bottom with layered neon glow bloom, breathing animation
  - Bundle subdirectory fix: AudioManager/HapticManager resolve Audio/, Audio/SFX/, Haptics/ paths
  - Asset catalog namespace fix: BackgroundAsset rawValues prefixed with "Backgrounds/"
  - pbxproj: CRTTransitionView (FileRef 12, BuildFile 11), Components/.gitkeep removed
  - Build succeeds, audit 7/7
- **PH-06 COMPLETE** — GameConstants & Type-Safe Models (CONST_01 delivered)
  - Caseless enum namespace with 10 nested enums
  - Auto-Assist thresholds: 3 deaths, 3 incorrect, 5 misses, 10s idle
  - Timing: 0.5s cross-fade, 60s runner, 45s firewall, 3s handshake, 0.8 slider exponent
  - Difficulty: 20% speed/gap modifiers, ±150ms/±300ms hit windows
  - Physics: 20 hearts target, 120fps ProMotion
  - Beat map: 32 timestamps at ~85 BPM across 44.5s, track duration 174.66s
  - 5 BackgroundAsset + 5 SpriteAsset + 1 SpriteAtlas + 7 AudioAsset + 3 HapticAsset + 1 Persistence enum cases
  - Build succeeds, audit 7/7, pbxproj registered (FileRef 11, BuildFile 10)
- **PH-05 COMPLETE** — Asset Pre-load Pipeline (all 4 epics delivered)
- **ASSET_04 COMPLETE** — Author AHAP Haptic Patterns (4/4 stories)
  - 3 AHAP files authored: heartbeat.ahap, capacitor_charge.ahap, thud.ahap
  - .gitkeep placeholder removed from Haptics/
  - Folder reference auto-includes files in Copy Bundle Resources
  - Build succeeds, audit 7/7, all files verified in built bundle
- **ASSET_03 COMPLETE** — Integrate Audio Assets into Bundle (4/4 stories)
  - 2 BGM tracks + 7 SFX files placed in Audio/ and Audio/SFX/ via folder references
  - .gitkeep placeholders removed, no pbxproj edits required
  - AssetPreloadCoordinator explicit self fix for Swift 6 Logger interpolation
  - Build succeeds, audit 7/7, source files unmodified
- **ASSET_02 COMPLETE** — Implement Asset Pre-load Coordinator (6/6 stories)
  - @Observable @MainActor singleton with session-lifetime asset retention
  - 5 HEIC backgrounds decoded via withTaskGroup + byPreparingForDisplay()
  - Sprite atlas preloaded via withCheckedContinuation bridge
  - AudioManager + HapticManager orchestration per §7.9.2
  - Launch integration via .task modifier, preloadComplete observable
  - Build succeeds, audit 7/7, pbxproj registered
- **ASSET_01 COMPLETE** — Integrate Visual Assets into Asset Catalog (4/4 stories)
  - 5 backgrounds: PNG→HEIC @3x/@2x, placed in Backgrounds/ with §8.2 Contents.json
  - 4 sprites + img_bubble_shield: PNG placed in Sprites.spriteatlas/ with §8.3 Contents.json
  - img_bubble_shield relocated from Backgrounds/ to Sprites.spriteatlas/
  - Build succeeds, audit 7/7, zero actool warnings
- **HAPTIC_01 COMPLETE** — Implement HapticManager Singleton (9/9 stories)
- **AUDIO_01 COMPLETE** — AudioManager Singleton (11/11 stories)
- **PH-02 COMPLETE** — FlowCoordinator + Walking Skeleton (COORD_01 + COORD_02)
- **PH-01 COMPLETE** — Xcode Project Scaffold (all epics delivered)

## Active Decisions

No ADRs recorded.

## Component Status

| Component | File Path | Status | Phase | Tests | Notes |
|-----------|-----------|--------|-------|-------|-------|
| StarlightSyncApp | StarlightSync/StarlightSyncApp.swift | implemented | PH-02 | no | @main entry with FlowCoordinator injection, chapter routing, preload .task |
| ChapterRouterView | StarlightSync/StarlightSyncApp.swift | implemented | PH-02 | no | Exhaustive switch on Chapter enum |
| FlowCoordinator | StarlightSync/Coordinators/FlowCoordinator.swift | implemented | PH-02 | no | @Observable @MainActor, 6-chapter state machine |
| AssetPreloadCoordinator | StarlightSync/Coordinators/AssetPreloadCoordinator.swift | implemented | PH-05 | no | @Observable @MainActor singleton, HEIC decode, sprite atlas preload, manager orchestration |
| AudioManager | StarlightSync/Managers/AudioManager.swift | implemented | PH-03 | no | @Observable @MainActor singleton, dual-player cross-fade, SFX pool, interruption handling |
| HapticManager | StarlightSync/Managers/HapticManager.swift | implemented | PH-04 | no | @Observable @MainActor singleton, CHHapticEngine lifecycle, AHAP caching, crash recovery |
| HandshakeView | StarlightSync/Chapters/Chapter1_Handshake/HandshakeView.swift | implemented | PH-07 | no | OLED black, pulsing glyph, 3s long-press, CRT transition, BGM start |
| CRTTransitionView | StarlightSync/Components/CRTTransitionView.swift | implemented | PH-07 | no | Vertical sweep + Canvas scanlines + Reduce Motion cross-fade |
| PacketRunView | StarlightSync/Chapters/Chapter2_PacketRun/PacketRunView.swift | placeholder | PH-02 | no | Walking skeleton placeholder (no SpriteKit) |
| CipherView | StarlightSync/Chapters/Chapter3_Cipher/CipherView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| FirewallView | StarlightSync/Chapters/Chapter4_Firewall/FirewallView.swift | placeholder | PH-02 | no | Walking skeleton placeholder (no SpriteKit) |
| BlueprintView | StarlightSync/Chapters/Chapter5_Blueprint/BlueprintView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| EventHorizonView | StarlightSync/Chapters/Chapter6_EventHorizon/EventHorizonView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| WebhookService | StarlightSync/Services/WebhookService.swift | not_started | PH-12 | no | — |
| GameConstants | StarlightSync/Models/GameConstants.swift | implemented | PH-06 | no | Caseless enum namespace, 10 nested enums, type-safe asset identifiers, beat map |

## Coordination Notes

INFRA_01 merged via PR #6.
INFRA_02 merged via PR #8.
PH-01 phase gate: PASSED.
COORD_01 complete: FlowCoordinator state machine delivered (6/6 stories).
COORD_02 complete: Walking skeleton wired (4/4 stories).
PH-02 phase gate: PASSED.
AUDIO_01 complete: AudioManager singleton delivered (11/11 stories).
PH-03 phase gate: PASSED.
HAPTIC_01 complete: HapticManager singleton delivered (9/9 stories).
PH-04 phase gate: PASSED.
All source files registered in pbxproj Sources build phase.
ASSET_01 complete: Visual assets integrated into catalog (4/4 stories).
ASSET_02 complete: Pre-load coordinator delivered (6/6 stories).
ASSET_03 complete: Audio assets integrated into bundle (4/4 stories).
ASSET_04 complete: AHAP haptic patterns authored (4/4 stories).
PH-05 phase gate: PASSED. All 4 epics delivered.
Unblocked: PH-06 (GameConstants), PH-07–PH-13 (chapters), PH-12 (WebhookService), PH-14 (Cross-Chapter Transitions).
CONST_01 complete: GameConstants namespace delivered (7/7 stories).
PH-06 phase gate: PASSED.
Unblocked: PH-07–PH-13 (chapters with type-safe constants), PH-10 (beat map for FirewallScene), PH-15 (beat map validation tests).
CH1_01 complete: Chapter 1 Handshake delivered (7/7 stories).
PH-07 CH1_01: COMPLETE.
Unblocked: PH-08 (Chapter 2), PH-14 (CRTTransitionView reusable component), PH-16 (Chapter 1 on-device QA).
