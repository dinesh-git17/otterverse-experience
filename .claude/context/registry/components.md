---
last_updated: 2026-02-15T23:30:00Z
schema_version: 1
---

# Component Registry

| Component | File Path | Status | Phase | Tests | Notes |
|-----------|-----------|--------|-------|-------|-------|
| StarlightSyncApp | StarlightSync/StarlightSyncApp.swift | implemented | PH-02 | no | @main entry with FlowCoordinator injection and chapter routing |
| ChapterRouterView | StarlightSync/StarlightSyncApp.swift | implemented | PH-02 | no | Exhaustive switch on Chapter enum, no default case |
| FlowCoordinator | StarlightSync/Coordinators/FlowCoordinator.swift | implemented | PH-02 | no | @Observable @MainActor, 6-chapter state machine, fresh-start on launch |
| HandshakeView | StarlightSync/Chapters/Chapter1_Handshake/HandshakeView.swift | implemented | PH-07 | no | OLED black + pulsing glyph, 3s long-press, CRT transition, BGM start |
| PacketRunView | StarlightSync/Chapters/Chapter2_PacketRun/PacketRunView.swift | implemented | PH-08 | no | SpriteView wrapper, optional scene pattern, 120fps, fade-from-black |
| PacketRunScene | StarlightSync/Chapters/Chapter2_PacketRun/PacketRunScene.swift | implemented | PH-08 | no | SKScene: vertical runner, two-layer parallax, frame collision, overlays, Auto-Assist |
| CipherView | StarlightSync/Chapters/Chapter3_Cipher/CipherView.swift | placeholder | PH-02 | no | Walking skeleton, replaced in PH-09 |
| FirewallView | StarlightSync/Chapters/Chapter4_Firewall/FirewallView.swift | implemented | PH-10 | no | SpriteView wrapper, optional scene pattern, 120fps ProMotion |
| FirewallScene | StarlightSync/Chapters/Chapter4_Firewall/FirewallScene.swift | implemented | PH-10 | no | SKScene: 3-dir rhythm defense, plasma arc shields, beat sync, Auto-Assist |
| BlueprintView | StarlightSync/Chapters/Chapter5_Blueprint/BlueprintView.swift | placeholder | PH-02 | no | Walking skeleton, replaced in PH-11 |
| EventHorizonView | StarlightSync/Chapters/Chapter6_EventHorizon/EventHorizonView.swift | placeholder | PH-02 | no | Walking skeleton, replaced in PH-13 |
| AudioManager | StarlightSync/Managers/AudioManager.swift | implemented | PH-03 | no | @Observable @MainActor singleton, dual-player cross-fade, SFX pool with pre-seeding, interruption handling |
| HapticManager | StarlightSync/Managers/HapticManager.swift | implemented | PH-04 | no | @Observable @MainActor singleton, CHHapticEngine lifecycle, AHAP caching, crash recovery, graceful degradation |
| AssetPreloadCoordinator | StarlightSync/Coordinators/AssetPreloadCoordinator.swift | implemented | PH-05 | no | @Observable @MainActor singleton, HEIC decode, sprite atlas preload, manager orchestration |
| WebhookService | StarlightSync/Services/WebhookService.swift | not_started | PH-12 | no | Discord webhook, retry logic |
| GameConstants | StarlightSync/Models/GameConstants.swift | implemented | PH-06 | no | Tuning values, thresholds, beat maps, type-safe asset enums |
| CRTTransitionView | StarlightSync/Components/CRTTransitionView.swift | implemented | PH-07 | no | Vertical sweep + scanline Canvas + Reduce Motion cross-fade |
| CipherWheelView | StarlightSync/Chapters/Chapter3_Cipher/CipherWheelView.swift | not_started | PH-09 | no | Scroll wheel interaction |

| HeartNodeLayout | StarlightSync/Chapters/Chapter5_Blueprint/HeartNodeLayout.swift | not_started | PH-11 | no | Node coordinates |
| FrictionSlider | StarlightSync/Chapters/Chapter6_EventHorizon/FrictionSlider.swift | not_started | PH-13 | no | Progressive resistance |
| ConfettiView | StarlightSync/Components/ConfettiView.swift | not_started | PH-13 | no | Particle system |
