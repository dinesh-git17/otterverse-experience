---
last_updated: 2026-02-14T21:00:00Z
schema_version: 1
---

# Component Registry

| Component | File Path | Status | Phase | Tests | Notes |
|-----------|-----------|--------|-------|-------|-------|
| StarlightSyncApp | StarlightSync/StarlightSyncApp.swift | implemented | PH-02 | no | @main entry with FlowCoordinator injection and chapter routing |
| ChapterRouterView | StarlightSync/StarlightSyncApp.swift | implemented | PH-02 | no | Exhaustive switch on Chapter enum, no default case |
| FlowCoordinator | StarlightSync/Coordinators/FlowCoordinator.swift | implemented | PH-02 | no | @Observable @MainActor, 6-chapter state machine, UserDefaults persistence |
| HandshakeView | StarlightSync/Chapters/Chapter1_Handshake/HandshakeView.swift | placeholder | PH-02 | no | Walking skeleton, replaced in PH-07 |
| PacketRunView | StarlightSync/Chapters/Chapter2_PacketRun/PacketRunView.swift | placeholder | PH-02 | no | Walking skeleton, replaced in PH-08 (plain SwiftUI, no SpriteKit) |
| CipherView | StarlightSync/Chapters/Chapter3_Cipher/CipherView.swift | placeholder | PH-02 | no | Walking skeleton, replaced in PH-09 |
| FirewallView | StarlightSync/Chapters/Chapter4_Firewall/FirewallView.swift | placeholder | PH-02 | no | Walking skeleton, replaced in PH-10 (plain SwiftUI, no SpriteKit) |
| BlueprintView | StarlightSync/Chapters/Chapter5_Blueprint/BlueprintView.swift | placeholder | PH-02 | no | Walking skeleton, replaced in PH-11 |
| EventHorizonView | StarlightSync/Chapters/Chapter6_EventHorizon/EventHorizonView.swift | placeholder | PH-02 | no | Walking skeleton, replaced in PH-13 |
| AudioManager | StarlightSync/Managers/AudioManager.swift | not_started | PH-03 | no | AVFoundation singleton |
| HapticManager | StarlightSync/Managers/HapticManager.swift | not_started | PH-04 | no | CoreHaptics singleton |
| WebhookService | StarlightSync/Services/WebhookService.swift | not_started | PH-12 | no | Discord webhook, retry logic |
| GameConstants | StarlightSync/Models/GameConstants.swift | not_started | PH-06 | no | Tuning values, thresholds, beat maps |
| CRTTransitionView | StarlightSync/Components/CRTTransitionView.swift | not_started | PH-07 | no | CRT turn-on effect |
| CipherWheelView | StarlightSync/Chapters/Chapter3_Cipher/CipherWheelView.swift | not_started | PH-09 | no | Scroll wheel interaction |
| PacketRunScene | StarlightSync/Chapters/Chapter2_PacketRun/PacketRunScene.swift | not_started | PH-08 | no | SKScene subclass |
| FirewallScene | StarlightSync/Chapters/Chapter4_Firewall/FirewallScene.swift | not_started | PH-10 | no | SKScene subclass |
| HeartNodeLayout | StarlightSync/Chapters/Chapter5_Blueprint/HeartNodeLayout.swift | not_started | PH-11 | no | Node coordinates |
| FrictionSlider | StarlightSync/Chapters/Chapter6_EventHorizon/FrictionSlider.swift | not_started | PH-13 | no | Progressive resistance |
| ConfettiView | StarlightSync/Components/ConfettiView.swift | not_started | PH-13 | no | Particle system |
