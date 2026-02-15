---
last_updated: 2026-02-15T01:10:00Z
updated_by: claude-opus-4-6
schema_version: 1
---

# Project Manifest

## Current Phase

**PH-03** — AudioManager Singleton
Completion: 100% (AUDIO_01 delivered)
Status: Complete

## Blocking Issues

None.

## Recently Completed

- **AUDIO_01 COMPLETE** — Implement AudioManager Singleton (11/11 stories)
  - S1: AVAudioSession .playback category configuration
  - S2: @Observable @MainActor singleton with injectable dependencies
  - S3: Dual-player BGM cross-fade with setVolume(_:fadeDuration:) and CACurrentMediaTime
  - S4: SFX one-shot playback with reuse pool
  - S5: preloadAssets() cache API
  - S6: Interruption notification handling (.began/.ended with .shouldResume)
  - S7: Route change notification handling (headphone disconnect)
  - S8: CACurrentMediaTime-based timing API
  - S9: BGM stop/pause/resume and mute controls
  - S10: Graceful failure isolation across all public APIs
  - S11: Governance compliance and build validation
- **PH-02 COMPLETE** — FlowCoordinator + Walking Skeleton (COORD_01 + COORD_02)
- **PH-01 COMPLETE** — Xcode Project Scaffold (all epics delivered)

## Active Decisions

No ADRs recorded.

## Component Status

| Component | File Path | Status | Phase | Tests | Notes |
|-----------|-----------|--------|-------|-------|-------|
| StarlightSyncApp | StarlightSync/StarlightSyncApp.swift | implemented | PH-02 | no | @main entry with FlowCoordinator injection and chapter routing |
| ChapterRouterView | StarlightSync/StarlightSyncApp.swift | implemented | PH-02 | no | Exhaustive switch on Chapter enum |
| FlowCoordinator | StarlightSync/Coordinators/FlowCoordinator.swift | implemented | PH-02 | no | @Observable @MainActor, 6-chapter state machine |
| AudioManager | StarlightSync/Managers/AudioManager.swift | implemented | PH-03 | no | @Observable @MainActor singleton, dual-player cross-fade, SFX pool, interruption handling |
| HandshakeView | StarlightSync/Chapters/Chapter1_Handshake/HandshakeView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| PacketRunView | StarlightSync/Chapters/Chapter2_PacketRun/PacketRunView.swift | placeholder | PH-02 | no | Walking skeleton placeholder (no SpriteKit) |
| CipherView | StarlightSync/Chapters/Chapter3_Cipher/CipherView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| FirewallView | StarlightSync/Chapters/Chapter4_Firewall/FirewallView.swift | placeholder | PH-02 | no | Walking skeleton placeholder (no SpriteKit) |
| BlueprintView | StarlightSync/Chapters/Chapter5_Blueprint/BlueprintView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| EventHorizonView | StarlightSync/Chapters/Chapter6_EventHorizon/EventHorizonView.swift | placeholder | PH-02 | no | Walking skeleton placeholder |
| HapticManager | StarlightSync/Managers/HapticManager.swift | not_started | PH-04 | no | — |
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
All source files registered in pbxproj Sources build phase.
Unblocked: PH-04 (HapticManager), PH-05 (Asset Pre-load Pipeline), PH-06 (GameConstants), PH-07–PH-13 (chapters), PH-12 (WebhookService), PH-14 (Cross-Chapter Transitions).
