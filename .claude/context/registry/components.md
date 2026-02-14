---
last_updated: 2026-02-14T11:00:00Z
schema_version: 1
---

# Component Registry

| Component | File Path | Status | Phase | Tests | Notes |
|-----------|-----------|--------|-------|-------|-------|
| StarlightSyncApp | StarlightSync/StarlightSyncApp.swift | not_started | PH-02 | no | App entry point |
| FlowCoordinator | StarlightSync/Coordinators/FlowCoordinator.swift | implemented | PH-02 | no | @Observable @MainActor, 6-chapter state machine, UserDefaults persistence |
| AudioManager | StarlightSync/Managers/AudioManager.swift | not_started | PH-03 | no | AVFoundation singleton |
| HapticManager | StarlightSync/Managers/HapticManager.swift | not_started | PH-04 | no | CoreHaptics singleton |
| WebhookService | StarlightSync/Services/WebhookService.swift | not_started | PH-12 | no | Discord webhook, retry logic |
| GameConstants | StarlightSync/Models/GameConstants.swift | not_started | PH-06 | no | Tuning values, thresholds, beat maps |
| HandshakeView | StarlightSync/Chapters/Chapter1_Handshake/HandshakeView.swift | not_started | PH-07 | no | Chapter 1 SwiftUI |
| CRTTransitionView | StarlightSync/Components/CRTTransitionView.swift | not_started | PH-07 | no | CRT turn-on effect |
| PacketRunScene | StarlightSync/Chapters/Chapter2_PacketRun/PacketRunScene.swift | not_started | PH-08 | no | SKScene subclass |
| PacketRunView | StarlightSync/Chapters/Chapter2_PacketRun/PacketRunView.swift | not_started | PH-08 | no | SpriteView wrapper |
| CipherView | StarlightSync/Chapters/Chapter3_Cipher/CipherView.swift | not_started | PH-09 | no | Chapter 3 container |
| CipherWheelView | StarlightSync/Chapters/Chapter3_Cipher/CipherWheelView.swift | not_started | PH-09 | no | Scroll wheel interaction |
| FirewallScene | StarlightSync/Chapters/Chapter4_Firewall/FirewallScene.swift | not_started | PH-10 | no | SKScene subclass |
| FirewallView | StarlightSync/Chapters/Chapter4_Firewall/FirewallView.swift | not_started | PH-10 | no | SpriteView wrapper |
| BlueprintView | StarlightSync/Chapters/Chapter5_Blueprint/BlueprintView.swift | not_started | PH-11 | no | Chapter 5 drag interaction |
| HeartNodeLayout | StarlightSync/Chapters/Chapter5_Blueprint/HeartNodeLayout.swift | not_started | PH-11 | no | Node coordinates |
| EventHorizonView | StarlightSync/Chapters/Chapter6_EventHorizon/EventHorizonView.swift | not_started | PH-13 | no | Finale orchestration |
| FrictionSlider | StarlightSync/Chapters/Chapter6_EventHorizon/FrictionSlider.swift | not_started | PH-13 | no | Progressive resistance |
| ConfettiView | StarlightSync/Components/ConfettiView.swift | not_started | PH-13 | no | Particle system |
