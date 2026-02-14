# Architecture Rules Reference

Canonical boundary definitions, frozen thresholds, and integration constraints extracted from `Design-Doc.md` and `CLAUDE.md`.

## Component Boundary Matrix

| Component            | Responsibility                          | May Access                                        | MUST NOT Access                           |
| -------------------- | --------------------------------------- | ------------------------------------------------- | ----------------------------------------- |
| `FlowCoordinator`    | Chapter state, transitions, persistence | `UserDefaults`, `AudioManager`, `HapticManager`   | `URLSession`, chapter internals           |
| `AudioManager`       | Playback, cross-fade, session lifecycle | `AVAudioSession`, `AVAudioPlayer`                 | `UserDefaults`, UI layer                  |
| `HapticManager`      | AHAP playback, engine lifecycle         | `CHHapticEngine`, `CHHapticPattern`               | `UserDefaults`, UI layer                  |
| Chapter Views        | UI rendering, user interaction          | `FlowCoordinator` (read state, report completion) | `UserDefaults`, `URLSession`, other chapters |
| `SKScene` subclasses | Game loop, physics, rendering           | `FlowCoordinator` (report completion only)        | `UserDefaults`, `URLSession`, managers    |
| `WebhookService`     | Discord POST, retry logic               | `URLSession` only                                 | `UserDefaults`, UI layer, managers        |

## Win Conditions (Frozen)

| Chapter | Win Condition                                       | GameConstants Key                  |
| ------- | --------------------------------------------------- | ---------------------------------- |
| 1       | 3-second long-press completed                       | `Chapter1.longPressDuration`       |
| 2       | Survive 60s OR collect 20 hearts                    | `Chapter2.survivalDuration`, `Chapter2.heartTarget` |
| 3       | All 3 wheels aligned to correct segments            | `Chapter3.segmentCount`            |
| 4       | Survive song verse (~45s)                           | `Chapter4.verseDuration`           |
| 5       | All 12 nodes connected                              | `Chapter5.totalNodes`              |
| 6       | Friction slider reaches 100%                        | `Chapter6.sliderExponent`          |

## Auto-Assist Thresholds (Frozen)

| Chapter | Trigger Constant                      | Value   | Mechanism                         |
| ------- | ------------------------------------- | ------- | --------------------------------- |
| 2       | `Chapter2.autoAssistDeathThreshold`   | 3       | Speed -20%, Gap +20%              |
| 3       | `Chapter3.autoAssistAttemptThreshold` | 3       | Highlight correct segment         |
| 4       | `Chapter4.autoAssistMissThreshold`    | 5       | Hit window +/-150ms -> +/-300ms   |
| 5       | `Chapter5.autoAssistIdleThreshold`    | 10s     | Pulse next correct node           |

Chapters 1 and 6 have no Auto-Assist system.

## Frozen Numeric Constants

| Constant                    | Value   | Chapter |
| --------------------------- | ------- | ------- |
| Long-press duration         | 3s      | 1       |
| Runner survival duration    | 60s     | 2       |
| Heart collection target     | 20      | 2       |
| Auto-Assist death trigger   | 3       | 2       |
| Speed reduction             | 20%     | 2       |
| Gap width increase          | 20%     | 2       |
| Auto-Assist attempt trigger | 3       | 3       |
| Default hit window          | +/-150ms | 4      |
| God Mode hit window         | +/-300ms | 4      |
| Auto-Assist miss trigger    | 5       | 4       |
| Verse duration              | ~45s    | 4       |
| Total blueprint nodes       | 12      | 5       |
| Labeled cornerstone nodes   | 4       | 5       |
| Unlabeled structural nodes  | 8       | 5       |
| Auto-Assist idle trigger    | 10s     | 5       |
| Slider decay exponent       | 0.8     | 6       |
| Webhook retry attempts      | 3       | 6       |
| Webhook retry backoff       | 1s, 2s, 4s | 6   |
| Audio cross-fade duration   | 500ms   | All     |
| ProMotion frame rate target | 120fps  | All     |

## Architectural Prohibitions (Enforced)

- No third-party dependencies (SPM, CocoaPods, Carthage)
- No UIKit (`UIViewController`, `UIView`, `UIHostingController`)
- No Combine (`ObservableObject`, `@Published`, `Publisher`, `sink`)
- No GCD (`DispatchQueue`, `DispatchGroup`)
- No Core Data, SwiftData, or Realm
- No backend services beyond the single Discord webhook
- No new singletons beyond `AudioManager` and `HapticManager`
- No cross-chapter imports between chapter directories

## Chapter File Placement

```
StarlightSync/Chapters/
├── Chapter1_Handshake/
│   └── HandshakeView.swift
├── Chapter2_PacketRun/
│   ├── PacketRunScene.swift
│   └── PacketRunView.swift
├── Chapter3_Cipher/
│   ├── CipherView.swift
│   └── CipherWheelView.swift
├── Chapter4_Firewall/
│   ├── FirewallScene.swift
│   └── FirewallView.swift
├── Chapter5_Blueprint/
│   ├── BlueprintView.swift
│   └── HeartNodeLayout.swift
└── Chapter6_EventHorizon/
    ├── EventHorizonView.swift
    └── FrictionSlider.swift
```

## Naming Conventions

| Element              | Convention     | Example                              |
| -------------------- | -------------- | ------------------------------------ |
| View struct          | UpperCamelCase | `HandshakeView`, `CipherWheelView`   |
| Scene class          | UpperCamelCase | `PacketRunScene`, `FirewallScene`    |
| File name            | Match type     | `HandshakeView.swift`                |
| State properties     | lowerCamelCase | `currentChapter`, `failureCount`     |
| Constants namespace  | UpperCamelCase | `GameConstants.Chapter2`             |
| Asset identifiers    | snake_case     | `img_bg_runner`, `sfx_haptic_thud`   |
