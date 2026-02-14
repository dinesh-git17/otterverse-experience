# AVFoundation Audio Lifecycle Patterns

## Audio Session State Machine

```md
                    ┌──────────────────┐
                    │   App Launch     │
                    └────────┬─────────┘
                             │
                    setCategory(.playback)
                    setActive(true)
                             │
                             ▼
                    ┌──────────────────┐
          ┌───────►│     Active       │◄──────────┐
          │        └────────┬─────────┘           │
          │                 │                     │
          │    interruptionNotification      setActive(true)
          │         .began                   on .shouldResume
          │                 │                     │
          │                 ▼                     │
          │        ┌──────────────────┐           │
          │        │   Interrupted    │───────────┘
          │        └────────┬─────────┘
          │                 │
          │         .ended without
          │         .shouldResume
          │                 │
          │                 ▼
          │        ┌──────────────────┐
          │        │  Waiting Resume  │  Display overlay
          └────────│  (User Action)   │  Wait for tap
                   └──────────────────┘
```

## Dual-Player Cross-Fade Sequence

```md
Time ──────────────────────────────────────────►
     0ms                 250ms               500ms

PlayerA ████████████████████░░░░░░░░░░░░░░░░░░░░
 volume  1.0 ─────────── 0.5 ────────────── 0.0
                                             stop()

PlayerB ░░░░░░░░░░░░░░░░░░░░████████████████████
 volume  0.0 ─────────── 0.5 ────────────── 1.0
         play()

Cross-fade window: both players active simultaneously
No gap, no pop, no click artifact
```

### Cross-Fade Trigger Points

```md
Chapter Transition Sequence:
  │
  ├─ FlowCoordinator advances chapter
  │
  ├─ AudioManager.crossFadeToBGM(_:) called
  │   ├─ Is bgmPlayerB prepared? (prepareToPlay called at launch)
  │   │   ├─ Yes → Begin cross-fade
  │   │   └─ No → Fallback: stop A, start B (gap acceptable)
  │   │
  │   ├─ Set bgmPlayerB.currentTime = 0
  │   ├─ Set bgmPlayerB.volume = 0
  │   ├─ bgmPlayerB.play()
  │   │
  │   ├─ Start fade interpolation (CADisplayLink / TimelineView):
  │   │   ├─ fadeStartTime = CACurrentMediaTime()
  │   │   ├─ Per frame:
  │   │   │   elapsed = CACurrentMediaTime() - fadeStartTime
  │   │   │   progress = min(elapsed / 0.5, 1.0)
  │   │   │   playerA.volume = (1 - progress) * targetVolume
  │   │   │   playerB.volume = progress * targetVolume
  │   │   └─ When progress >= 1.0: stop interpolation
  │   │
  │   ├─ bgmPlayerA.stop()
  │   ├─ bgmPlayerA = bgmPlayerB
  │   └─ bgmPlayerB = nil
  │
  └─ Chapter view renders (audio transition is non-blocking)

Special case: Ch. 5 → Ch. 6 transition
  ├─ Cross-fade from audio_bgm_main to silence (fade out only)
  ├─ audio_bgm_finale starts on slider completion (not on chapter enter)
  └─ Finale track: numberOfLoops = 0, no cross-fade out
```

## Beat Synchronization Timing

```md
CACurrentMediaTime() timeline (Mach absolute time):
  T0          T0+0.5s     T0+1.0s     T0+1.5s     T0+2.0s
  │             │             │             │             │
  ▼             ▼             ▼             ▼             ▼
  play()      beat[0]       beat[1]       beat[2]       beat[3]
              spawn         spawn         spawn         spawn
              noise         noise         noise         noise

  playbackStartTime = T0
  elapsedPlaybackTime() = CACurrentMediaTime() - T0

  Beat map comparison:
  ┌─────────────────────────────────────────────────┐
  │ for beat in beatMap {                            │
  │   let delta = abs(elapsed - beat)                │
  │   if delta <= hitWindowTolerance {               │
  │     // Beat is hittable                          │
  │   }                                              │
  │ }                                                │
  └─────────────────────────────────────────────────┘

  Hit window visualization (±150ms default):
  beat[1] = 1.0s
          ◄── 150ms ──►beat◄── 150ms ──►
          0.85s        1.0s        1.15s
          │     HIT WINDOW     │
          └────────────────────┘

  Auto-Assist window (±300ms):
          ◄──── 300ms ────►beat◄──── 300ms ────►
          0.7s             1.0s             1.3s
          │        GOD MODE WINDOW         │
          └────────────────────────────────┘
```

## Interruption Recovery Sequence

```md
Normal playback at elapsed = 25.3s
  │
  ├─ Phone call arrives
  │   interruptionNotification(.began)
  │   │
  │   ├─ savedPositionA = bgmPlayerA.currentTime  // 25.3s
  │   ├─ bgmPlayerA.pause()
  │   ├─ FlowCoordinator.pauseGameState()
  │   └─ isInterrupted = true
  │
  │   ... 45 seconds of phone call ...
  │
  ├─ Phone call ends
  │   interruptionNotification(.ended, options: .shouldResume)
  │   │
  │   ├─ try AVAudioSession.sharedInstance().setActive(true)
  │   ├─ bgmPlayerA.play()
  │   │
  │   ├─ Recalibrate beat sync clock:
  │   │   playbackStartTime = CACurrentMediaTime() - savedPositionA
  │   │   // If CACurrentMediaTime() is now T0 + 70.3s:
  │   │   // playbackStartTime = (T0 + 70.3) - 25.3 = T0 + 45.0
  │   │   // elapsedPlaybackTime() = (T0 + 70.3) - (T0 + 45.0) = 25.3s ✓
  │   │
  │   ├─ FlowCoordinator.resumeGameState()
  │   └─ isInterrupted = false
  │
  └─ Playback continues at 25.3s with correct beat alignment

WITHOUT recalibration (BUG):
  playbackStartTime remains T0
  elapsedPlaybackTime() = (T0 + 70.3) - T0 = 70.3s
  Beat map lookups offset by +45s → all spawns wrong ✗
```

## Preload Sequence

```md
Launch Pre-Load (§7.9.2, Step 4, ~200ms budget)
  │
  ├─ BGM Players:
  │   ├─ audio_bgm_main:
  │   │   ├─ Bundle.main.url(forResource:withExtension:)
  │   │   │   └─ nil? Log, skip
  │   │   ├─ AVAudioPlayer(contentsOf: url)
  │   │   │   └─ throws? Log, skip
  │   │   ├─ player.numberOfLoops = -1
  │   │   ├─ player.volume = GameConstants.bgmVolume
  │   │   └─ player.prepareToPlay()  // AAC → PCM decode (~8MB)
  │   │
  │   └─ audio_bgm_finale:
  │       ├─ Same init sequence
  │       ├─ player.numberOfLoops = 0  // plays once
  │       └─ player.prepareToPlay()  // AAC → PCM decode (~12MB)
  │
  ├─ SFX Players:
  │   ├─ For each SFX asset (sfx_haptic_thud, sfx_success_chime,
  │   │   sfx_shield_impact, sfx_click, sfx_error):
  │   │   ├─ Bundle.main.url → AVAudioPlayer → prepareToPlay()
  │   │   ├─ player.numberOfLoops = 0
  │   │   └─ Store in sfxPlayers[assetID]
  │   │
  │   └─ Total SFX decode: ~4MB PCM
  │
  └─ Result: all 7 players initialized, decoded, ready
     Total memory: ~24MB decoded audio buffers
     First-trigger latency: <10ms (PCM already in memory)
```

## Access Control Matrix

| Caller            | playBGM | crossFade | playSFX | pause/resume | elapsedTime |
| ----------------- | ------- | --------- | ------- | ------------ | ----------- |
| FlowCoordinator   | YES     | YES       | YES     | YES          | NO          |
| Chapter View      | NO      | NO        | YES*    | NO           | NO          |
| SKScene            | NO      | NO        | YES*    | NO           | YES         |
| HapticManager     | NO      | NO        | NO      | NO           | NO          |
| WebhookService    | NO      | NO        | NO      | NO           | NO          |

*Chapter views and scenes call `playSFX` for immediate UI feedback (cipher clicks, shield impacts). BGM control routes through `FlowCoordinator` exclusively.

## Multi-Sensory Audio Dependencies

| Event                 | Audio Asset         | Paired Haptic           | Visual Feedback          |
| --------------------- | ------------------- | ----------------------- | ------------------------ |
| Ch. 1 capacitor snap  | `sfx_haptic_thud`   | `capacitor_charge.ahap` | CRT power-on effect      |
| Ch. 2 heart collect   | `sfx_success_chime` | Light transient          | Particle burst           |
| Ch. 3 wheel scroll    | `sfx_click`         | Detent click             | Wheel rotation           |
| Ch. 3 segment lock    | `sfx_haptic_thud`   | `thud.ahap`             | Glow confirmation        |
| Ch. 4 beat hit        | `sfx_shield_impact` | `heartbeat.ahap`        | Shield flash             |
| Ch. 5 node connect    | `sfx_success_chime` | Light transient          | Line draw animation      |
| Ch. 5 invalid connect | `sfx_error`         | Error buzz               | Snap-back animation      |
| Ch. 6 finale          | `audio_bgm_finale`  | `heartbeat.ahap`        | Confetti + art reveal    |

If audio fails: visual + haptic channels provide partial feedback. Chapter progression is never gated on audio playback success.
