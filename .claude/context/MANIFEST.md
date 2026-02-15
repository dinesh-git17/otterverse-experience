---
last_updated: 2026-02-15T20:00:00Z
updated_by: claude-opus-4-6
schema_version: 1
---

# Project Manifest

## Current Phase

**PH-05** — Asset Pre-load Pipeline
Completion: ASSET_01 + ASSET_02 delivered (visuals integrated, preload coordinator implemented)
Status: In Progress (ASSET_03 audio integration pending, ASSET_04 AHAP authoring pending)

## Blocking Issues

None.

## Recently Completed

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
| HandshakeView | StarlightSync/Chapters/Chapter1_Handshake/HandshakeView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| PacketRunView | StarlightSync/Chapters/Chapter2_PacketRun/PacketRunView.swift | placeholder | PH-02 | no | Walking skeleton placeholder (no SpriteKit) |
| CipherView | StarlightSync/Chapters/Chapter3_Cipher/CipherView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| FirewallView | StarlightSync/Chapters/Chapter4_Firewall/FirewallView.swift | placeholder | PH-02 | no | Walking skeleton placeholder (no SpriteKit) |
| BlueprintView | StarlightSync/Chapters/Chapter5_Blueprint/BlueprintView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| EventHorizonView | StarlightSync/Chapters/Chapter6_EventHorizon/EventHorizonView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| WebhookService | StarlightSync/Services/WebhookService.swift | not_started | PH-12 | no | — |
| GameConstants | StarlightSync/Models/GameConstants.swift | not_started | PH-06 | no | — |

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
Unblocked: ASSET_03 (audio), ASSET_04 (AHAP), PH-06 (GameConstants), PH-07–PH-13 (chapters), PH-12 (WebhookService), PH-14 (Cross-Chapter Transitions).
