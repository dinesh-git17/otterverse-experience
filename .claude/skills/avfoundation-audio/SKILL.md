---
name: avfoundation-audio
description: Enforce AVFoundation audio lifecycle management, dual-player cross-fade architecture, beat synchronization via CACurrentMediaTime(), AVAudioSession interruption recovery, and preload guarantees for AudioManager implementation. Use when AudioManager is implemented or modified, background music or SFX integration is requested, rhythm synchronization logic is implemented, or audio session lifecycle handling is added. Triggers on audio integration, cross-fade implementation, beat map synchronization, interruption handling, or AudioManager modification.
---

# AVFoundation Audio

Deterministic enforcement of AVFoundation integration patterns covering `AVAudioSession` configuration, interruption handling, dual-player cross-fade architecture, beat map synchronization, preload guarantees, and playback safety as defined in `Design-Doc.md` §7.4, §7.5, §8.1, §8.2, and §8.4.

## Pre-Implementation Verification

Before generating or modifying audio code, verify:

1. The target component is `AudioManager` at `Managers/AudioManager.swift`.
2. No direct `AVAudioPlayer` usage exists outside `AudioManager`.
3. All audio assets referenced exist in the `Audio/` or `Audio/SFX/` bundle directories.
4. `AVAudioSession` category is `.playback` (not `.ambient` or `.soloAmbient`).

If any verification fails, **HALT** and cite the conflict.

## Workflow

### Step 1: Determine Task Type

Identify the scope of work:

**Implementing AudioManager?** → Follow Full Lifecycle Workflow
**Adding background music or SFX?** → Follow Asset Integration Workflow
**Implementing cross-fade transitions?** → Follow Cross-Fade Workflow
**Implementing rhythm sync (Ch. 4)?** → Follow Beat Synchronization Workflow
**Fixing interruption handling?** → Follow Interruption Recovery Workflow

---

### Full Lifecycle Workflow

#### Phase 1: Audio Session Configuration

`AudioManager` MUST configure `AVAudioSession` at app launch. This is the first operation in the pre-load sequence (`Design-Doc.md` §7.9.2, step 1).

```
1. AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
2. AVAudioSession.sharedInstance().setActive(true)
3. Register for AVAudioSession.interruptionNotification
4. Register for AVAudioSession.routeChangeNotification
```

**Category MUST be `.playback`.** This ensures audio persists when the Silent Switch (mute) is on. Using `.ambient` or `.soloAmbient` causes audio to respect the mute switch, breaking the experience.

**No `.mixWithOthers` option.** The app's audio is the sole output. Other app audio is ducked or interrupted.

**Session activation occurs once at launch.** Do not deactivate and reactivate between chapters.

#### Phase 2: Singleton Structure

`AudioManager` MUST be a `@MainActor` singleton using `@Observable`:

```swift
@MainActor
@Observable
final class AudioManager {
    static let shared = AudioManager()
    private init() { /* session config + player init */ }
}
```

- `@MainActor` isolation for thread safety
- `@Observable` for SwiftUI state reactivity (playback state driving UI)
- `private init` prevents additional instances
- No `ObservableObject`, no `@Published`, no Combine

#### Phase 3: Player Architecture

`AudioManager` maintains the following player instances:

```
BGM Players (dual, for cross-fade):
  - bgmPlayerA: AVAudioPlayer?  (active track)
  - bgmPlayerB: AVAudioPlayer?  (standby track)

SFX Players (independent pool):
  - sfxPlayers: [String: AVAudioPlayer]  (keyed by asset ID)
```

BGM players operate in pairs for gapless cross-fade transitions. SFX players are independent and do not participate in cross-fade logic.

#### Phase 4: Teardown

`AudioManager` holds player references for the full session. No per-chapter teardown. Players are released only at app termination.

---

### Asset Integration Workflow

#### Audio Asset Registry

Seven audio assets are defined in `Design-Doc.md` §7.4:

| Asset ID            | Type | File Path    | Chapter Usage |
| ------------------- | ---- | ------------ | ------------- |
| `audio_bgm_main`    | BGM  | `Audio/`     | Ch. 1–5       |
| `audio_bgm_finale`  | BGM  | `Audio/`     | Ch. 6         |
| `sfx_haptic_thud`   | SFX  | `Audio/SFX/` | Ch. 1, 3      |
| `sfx_success_chime` | SFX  | `Audio/SFX/` | Ch. 2, 3, 5   |
| `sfx_shield_impact` | SFX  | `Audio/SFX/` | Ch. 4         |
| `sfx_click`         | SFX  | `Audio/SFX/` | Ch. 3         |
| `sfx_error`         | SFX  | `Audio/SFX/` | Ch. 5         |

#### Preload Rules

1. Create all `AVAudioPlayer` instances during the launch pre-load sequence (§7.9.2, step 4, ~200ms budget).
2. Call `prepareToPlay()` on every player immediately after creation.
3. `prepareToPlay()` decodes AAC to PCM buffers in memory (~24MB total).
4. Never call `prepareToPlay()` at playback time — it introduces latency.
5. Handle `Bundle.main.url(forResource:withExtension:)` returning `nil` gracefully: log under `#if DEBUG`, skip the asset.

```
For each audio asset:
  1. Bundle.main.url(forResource: assetID, withExtension: "m4a")
     → nil? Log under #if DEBUG, skip
  2. try AVAudioPlayer(contentsOf: url)
     → throws? Log under #if DEBUG, skip
  3. player.prepareToPlay()
  4. Store in player dictionary
```

#### Playback Rules

- BGM tracks: `numberOfLoops = -1` for infinite loop (except `audio_bgm_finale` which plays once).
- SFX: `numberOfLoops = 0` (single play).
- Volume defaults: BGM at `0.7`, SFX at `1.0`. Values stored in `GameConstants`.
- All playback calls are fire-and-forget. No return value, no throws to callers.

---

### Cross-Fade Workflow

#### Architecture: Dual-Player Strategy

Cross-fading MUST use two independent `AVAudioPlayer` instances. A single-player volume-ramp-then-swap approach creates audible gaps.

```
Chapter transition triggers cross-fade:
  1. bgmPlayerB.currentTime = 0
  2. bgmPlayerB.volume = 0
  3. bgmPlayerB.play()
  4. Animate over 500ms:
     - bgmPlayerA.volume: current → 0 (fade out)
     - bgmPlayerB.volume: 0 → target (fade in)
  5. On completion:
     - bgmPlayerA.stop()
     - Swap references: bgmPlayerA = bgmPlayerB
     - bgmPlayerB = nil (or assign next track)
```

#### Cross-Fade Parameters

| Parameter     | Value  | Source                    |
| ------------- | ------ | ------------------------- |
| Fade duration | 500ms  | `Design-Doc.md` §7.4      |
| Fade curve    | Linear | Default (0→1 / 1→0)       |
| Overlap       | Full   | Both players active 500ms |

#### Cross-Fade Timing

Use `CACurrentMediaTime()` as the time reference for fade interpolation. Implement the fade using a `CADisplayLink` or frame-driven callback:

```
let fadeStart = CACurrentMediaTime()
let fadeDuration: TimeInterval = 0.5

// Per-frame update (via CADisplayLink or SwiftUI TimelineView):
let elapsed = CACurrentMediaTime() - fadeStart
let progress = min(elapsed / fadeDuration, 1.0)
bgmPlayerA.volume = Float(1.0 - progress) * targetVolume
bgmPlayerB.volume = Float(progress) * targetVolume

if progress >= 1.0 {
    bgmPlayerA.stop()
    // swap references
}
```

Do not use `Timer`, `DispatchQueue.asyncAfter`, or `Task.sleep` for fade interpolation. These introduce scheduling jitter audible as volume stepping artifacts.

---

### Beat Synchronization Workflow

#### Timing Source

Beat synchronization MUST use `CACurrentMediaTime()` exclusively (`Design-Doc.md` §7.5).

`CACurrentMediaTime()` returns Mach absolute time — a monotonically increasing, high-resolution clock unaffected by system sleep, NTP adjustments, or wall-clock drift. `AVAudioPlayer.currentTime` is relative to the player's timeline and may drift from the system clock on seek or interruption recovery.

#### Synchronization Architecture

```
1. Record playback start time:
   let playbackStartTime = CACurrentMediaTime()
   bgmPlayer.play()

2. In SpriteKit update(_:) loop:
   let elapsed = CACurrentMediaTime() - playbackStartTime
   let nextBeat = beatMap.first(where: { $0 > elapsed - tolerance })

3. Compare elapsed time against beat map timestamps:
   if abs(elapsed - beatTimestamp) <= hitWindowTolerance {
       // Beat is within hit window
   }
```

#### Hit Window Parameters

| Parameter              | Value  | Source               |
| ---------------------- | ------ | -------------------- |
| Default hit tolerance  | ±150ms | `Design-Doc.md` §3.5 |
| Auto-Assist tolerance  | ±300ms | `Design-Doc.md` §3.8 |
| Sync tolerance (spawn) | ±150ms | `Design-Doc.md` §7.5 |

#### Beat Map Format

Beat timestamps are stored as a `[TimeInterval]` array in `GameConstants` (`Design-Doc.md` §7.5):

```swift
static let beatMap: [TimeInterval] = [0.5, 1.0, 1.5, 2.0, 2.5, ...]
```

**Invariants:**

- Timestamps are monotonically increasing
- All timestamps fall within the track duration
- Spacing is consistent with the track BPM

#### SpriteKit Integration

`FirewallScene.update(_:)` consumes elapsed time from `CACurrentMediaTime()` to drive spawn timing. The scene does NOT call `AVAudioPlayer` directly — it reads playback state from `AudioManager` via a timing interface:

```
func elapsedPlaybackTime() -> TimeInterval {
    CACurrentMediaTime() - playbackStartTime
}
```

---

### Interruption Recovery Workflow

#### Notification Registration

`AudioManager` registers for `AVAudioSession.interruptionNotification` during initialization:

```swift
NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: AVAudioSession.sharedInstance(),
    queue: .main
) { [weak self] notification in
    self?.handleInterruption(notification)
}
```

#### Interruption Handling Sequence

```
interruptionNotification fires
  │
  ├─ Extract AVAudioSession.InterruptionType from userInfo
  │
  ├─ .began:
  │   ├─ Pause all active AVAudioPlayer instances
  │   ├─ Record current playback positions (currentTime)
  │   ├─ Notify FlowCoordinator to freeze game state
  │   ├─ Pause CHHapticEngine (if running)
  │   └─ Set isInterrupted = true
  │
  └─ .ended:
      ├─ Extract AVAudioSession.InterruptionOptions from userInfo
      ├─ Check for .shouldResume flag
      │   ├─ .shouldResume present:
      │   │   ├─ Reactivate audio session:
      │   │   │   try AVAudioSession.sharedInstance().setActive(true)
      │   │   ├─ Resume all paused AVAudioPlayer instances
      │   │   ├─ Recalculate playbackStartTime for beat sync:
      │   │   │   playbackStartTime = CACurrentMediaTime() - savedPosition
      │   │   ├─ Notify FlowCoordinator to resume game state
      │   │   └─ Set isInterrupted = false
      │   │
      │   └─ .shouldResume absent:
      │       ├─ Reactivate audio session
      │       ├─ Do NOT auto-resume playback
      │       ├─ Display "Welcome Back" overlay (§8.2)
      │       └─ Wait for user interaction to resume
      │
      └─ On setActive failure:
          ├─ Log error under #if DEBUG
          ├─ Retry once after 0.5s delay
          └─ On second failure: continue without audio
```

#### Route Change Handling

Register for `AVAudioSession.routeChangeNotification` to detect headphone disconnection:

```
routeChangeNotification fires
  │
  ├─ Extract AVAudioSession.RouteChangeReason from userInfo
  │
  ├─ .oldDeviceUnavailable (headphones unplugged):
  │   ├─ Pause BGM playback (Apple HIG: audio must pause on unplug)
  │   └─ Display pause overlay
  │
  └─ Other reasons: no action required
```

#### Beat Sync Recovery After Interruption

When resuming from an interruption during Chapter 4 (rhythm game), the beat sync clock MUST be recalibrated:

```
savedPosition = bgmPlayer.currentTime  // captured at .began
// ... interruption duration passes ...
// On .ended with .shouldResume:
bgmPlayer.play()
playbackStartTime = CACurrentMediaTime() - savedPosition
// Beat map now correctly aligned to resumed playback
```

Without this recalibration, `CACurrentMediaTime() - playbackStartTime` drifts by the interruption duration, causing all subsequent beat map lookups to misalign.

---

## Structural Constraints

### Singleton Pattern

```swift
@MainActor
@Observable
final class AudioManager {
    static let shared = AudioManager()
    private init() { /* session config + player init */ }
}
```

### Method Signatures

Public API surface MUST be minimal:

```swift
func playBGM(_ assetID: String, loop: Bool = true)
func stopBGM()
func crossFadeToBGM(_ assetID: String)
func playSFX(_ assetID: String)
func preloadAll()
func pause()
func resume()
func elapsedPlaybackTime() -> TimeInterval
```

- `playBGM(_:)` — starts or restarts a background music track
- `crossFadeToBGM(_:)` — dual-player cross-fade to a new BGM track
- `playSFX(_:)` — fire-and-forget SFX playback, no return value, no throws
- `preloadAll()` — called once during launch sequence
- `elapsedPlaybackTime()` — returns `CACurrentMediaTime() - playbackStartTime` for beat sync
- No public access to `AVAudioPlayer` instances
- Internal state (`bgmPlayerA`, `bgmPlayerB`, `sfxPlayers`, `isInterrupted`) is `private` or `private(set)`

### Error Handling

- All `try` calls on AVFoundation APIs wrapped in `do/catch`
- Catch blocks: log via `os.Logger` under `#if DEBUG`, degrade silently
- No `try!` on player creation or session configuration
- `try?` permitted for SFX playback where individual failure is non-critical
- Audio failure MUST NOT propagate to the UI layer or block chapter progression

### Naming

| Element             | Name                          |
| ------------------- | ----------------------------- |
| Singleton           | `AudioManager.shared`         |
| Active BGM player   | `bgmPlayerA`                  |
| Standby BGM player  | `bgmPlayerB`                  |
| SFX player pool     | `sfxPlayers`                  |
| Interruption flag   | `isInterrupted`               |
| Playback start time | `playbackStartTime`           |
| Play BGM method     | `playBGM(_:loop:)`            |
| Cross-fade method   | `crossFadeToBGM(_:)`          |
| Play SFX method     | `playSFX(_:)`                 |
| Preload method      | `preloadAll()`                |
| Timing method       | `elapsedPlaybackTime()`       |
| Volume constants    | `GameConstants.bgmVolume` etc |

---

## Anti-Patterns (Reject These)

- **Direct AVAudioPlayer access from views or scenes.** All audio routes through `AudioManager`.
- **`.ambient` or `.soloAmbient` session category.** Use `.playback` exclusively. Silent Switch must not mute the experience.
- **Single-player cross-fade (stop→start).** Creates audible gaps. Use dual-player overlap.
- **`Timer` or `DispatchQueue.asyncAfter` for beat sync.** Use `CACurrentMediaTime()` exclusively. Timer-based timing drifts ≥30ms under load.
- **`Task.sleep` for cross-fade interpolation.** Use `CADisplayLink` or frame-driven callback. Sleep granularity is too coarse for smooth volume transitions.
- **Calling `prepareToPlay()` at playback time.** Preload during launch. First-trigger latency spikes break rhythm game sync.
- **`ObservableObject` or `@Published` on AudioManager.** Use `@Observable`.
- **Combine publishers for audio events.** Use direct method calls and `async/await`.
- **`DispatchQueue.main.async` for thread safety.** Use `@MainActor` isolation.
- **`print()` for audio debug logging.** Use `os.Logger` under `#if DEBUG`.
- **Deactivating audio session between chapters.** Activate once at launch, hold for the session.
- **Missing interruption handler registration.** Both `interruptionNotification` and `routeChangeNotification` are mandatory.
- **Ignoring `.shouldResume` flag on interruption end.** Respecting this flag is required by Apple's audio session contract.
- **Playing `audio_bgm_finale` with `numberOfLoops = -1`.** The finale track plays exactly once.
- **Using `AVAudioPlayer.currentTime` as a timing source for beat sync.** Use `CACurrentMediaTime()`. Player timeline drifts on seek and interruption.
- **Blocking the main thread with synchronous audio session activation.** Wrap `setActive` in a `do/catch`, never force.
- **`.mixWithOthers` session option.** The app is the sole audio output.

## Post-Implementation Checklist

After implementing or modifying audio code, verify:

- [ ] `AVAudioSession` category is `.playback` (set at launch)
- [ ] No `.ambient`, `.soloAmbient`, or `.mixWithOthers` usage
- [ ] `AudioManager` is the sole owner of `AVAudioPlayer` instances
- [ ] Dual BGM players exist (`bgmPlayerA` + `bgmPlayerB`) for cross-fade
- [ ] Cross-fade uses 500ms overlap with both players active simultaneously
- [ ] All audio assets preloaded with `prepareToPlay()` during launch
- [ ] No `prepareToPlay()` calls at playback time
- [ ] `CACurrentMediaTime()` is the sole timing source for beat sync
- [ ] No `Timer`, `DispatchQueue`, or `Task.sleep` for audio timing
- [ ] `interruptionNotification` registered and handles `.began` / `.ended`
- [ ] `.shouldResume` flag respected on interruption end
- [ ] `routeChangeNotification` registered for headphone disconnect
- [ ] Beat sync clock recalibrated after interruption recovery
- [ ] `playbackStartTime` recalculated on resume: `CACurrentMediaTime() - savedPosition`
- [ ] SFX players independent of cross-fade logic
- [ ] `audio_bgm_finale` plays once (`numberOfLoops = 0`)
- [ ] `audio_bgm_main` loops infinitely (`numberOfLoops = -1`)
- [ ] No direct `AVAudioPlayer` usage outside `AudioManager`
- [ ] No force unwraps on Bundle URL lookups
- [ ] No Combine, no GCD, no `ObservableObject`
- [ ] No `print()` statements (use `os.Logger` under `#if DEBUG`)
- [ ] Audio failure never propagates to UI or blocks chapter progression
- [ ] `FlowCoordinator` notified on interruption (pause/resume game state)

## Resources

- **References**: See [references/audio-lifecycle-patterns.md](references/audio-lifecycle-patterns.md) for engine state machine, cross-fade sequence, and beat sync timing diagrams
