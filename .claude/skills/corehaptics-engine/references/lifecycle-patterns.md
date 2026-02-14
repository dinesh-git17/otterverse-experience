# CoreHaptics Engine Lifecycle Patterns

## Engine State Machine

```md
                    ┌─────────────┐
                    │  No Device  │  supportsHaptics == false
                    │  Support    │  → engineAvailable = false
                    └─────────────┘  → all play() calls are no-ops

                    ┌─────────────┐
        ┌──────────►│   Created   │
        │           └──────┬──────┘
        │                  │ engine.start()
        │                  ▼
        │           ┌─────────────┐
        │     ┌────►│   Running   │◄────────────┐
        │     │     └──────┬──────┘              │
        │     │            │                     │
        │     │    stoppedHandler        resetHandler
        │     │            │                     │
        │     │            ▼                     ▼
        │     │     ┌─────────────┐      ┌─────────────┐
        │     │     │   Stopped   │      │    Reset     │
        │     │     └──────┬──────┘      └──────┬──────┘
        │     │            │                     │
        │     │   try engine.start()    create new engine
        │     │            │            re-register handlers
        │     │            │            re-cache patterns
        │     │            ▼            try engine.start()
        │     │     ┌─────────────┐              │
        │     └─────│  Restarted  │◄─────────────┘
        │           └─────────────┘
        │                  │
        │           on failure:
        │                  ▼
        │           ┌─────────────┐
        │           │  Degraded   │  engineAvailable = false
        │           │  (No-Op)    │  visual + audio continue
        └───────────└─────────────┘
              resetHandler may
              attempt recovery
```

## Recovery Sequences

### stoppedHandler Recovery

```md
Event: Engine stops unexpectedly
  │
  ├─ stoppedHandler(reason:) fires
  │   ├─ reason == .audioSessionInterrupt
  │   │   └─ Wait for audio session resumption, then restart
  │   ├─ reason == .applicationSuspended
  │   │   └─ Restart on foreground return
  │   ├─ reason == .idleTimeout
  │   │   └─ Restart immediately
  │   ├─ reason == .systemError
  │   │   └─ Attempt restart; degrade on failure
  │   └─ reason == .engineDestroyed / .notifyWhenFinished
  │       └─ Degrade (engine cannot be restarted)
  │
  ├─ Restart attempt: engine.start()
  │   ├─ Success → Resume normal operation
  │   └─ Failure → Set engineAvailable = false
  │
  └─ No error propagation beyond HapticManager
```

### resetHandler Recovery

```md
Event: Engine resets (internal state invalidated)
  │
  ├─ resetHandler fires
  │   ├─ Old engine instance is INVALID (do not reuse)
  │   ├─ Old cached patterns are INVALID (tied to old engine)
  │   └─ Old players are INVALID
  │
  ├─ Full reconstruction:
  │   1. engine = CHHapticEngine()
  │   2. engine.stoppedHandler = { ... }
  │   3. engine.resetHandler = { ... }
  │   4. try engine.start()
  │   5. Re-parse all AHAP files → new CHHapticPattern instances
  │   6. Replace cachedPatterns dictionary
  │
  ├─ Success → Resume normal operation with new engine
  └─ Failure → Set engineAvailable = false
```

## AHAP Parsing Sequence

```md
Launch Pre-Load (§7.9.2, Step 3, ~20ms budget)
  │
  ├─ For each AHAP file in registry:
  │   │
  │   ├─ Bundle.main.url(forResource: name, withExtension: "ahap")
  │   │   ├─ nil → Log warning (#if DEBUG), skip
  │   │   └─ URL → Continue
  │   │
  │   ├─ CHHapticPattern(contentsOf: url)
  │   │   ├─ throws → Log error (#if DEBUG), skip
  │   │   └─ pattern → Store in cachedPatterns[name]
  │   │
  │   └─ Continue to next file
  │
  └─ Result: cachedPatterns populated with 0–3 entries
     Missing entries degrade silently at playback time
```

## Playback Sequence

```
HapticManager.play("heartbeat") called
  │
  ├─ Guard engineAvailable == true
  │   └─ false → Return immediately (no-op)
  │
  ├─ Guard let pattern = cachedPatterns["heartbeat"]
  │   └─ nil → Return immediately (pattern not cached)
  │
  ├─ Guard let engine = engine
  │   └─ nil → Return immediately (engine deallocated)
  │
  ├─ do {
  │     let player = try engine.makePlayer(with: pattern)
  │     try player.start(atTime: CHHapticTimeImmediate)
  │   } catch {
  │     #if DEBUG
  │       logger.error("Haptic playback failed: \(error)")
  │     #endif
  │   }
  │
  └─ Return (fire-and-forget)
```

## Audio-Haptic Synchronization (Chapter 4)

```
Rhythm game beat arrives at timestamp T
  │
  ├─ let now = CACurrentMediaTime()
  ├─ let offset = T - now  // may be 0 for immediate
  │
  ├─ AudioManager.playSFX("sfx_shield_impact")
  │   └─ Uses AVAudioPlayer.play(atTime: now + offset)
  │
  ├─ HapticManager.playAtTime("thud", time: now + offset)
  │   └─ Uses player.start(atTime: now + offset)
  │
  └─ Visual state mutation (immediate, SwiftUI handles next frame)
```

## Multi-Sensory Redundancy Matrix

| Event                      | Visual                     | Audio                | Haptic                  |
| -------------------------- | -------------------------- | -------------------- | ----------------------- |
| Ch. 1 capacitor snap       | CRT power-on effect        | `sfx_haptic_thud`    | `capacitor_charge.ahap` |
| Ch. 2 heart collect        | Particle burst             | `sfx_success_chime`  | Light transient         |
| Ch. 3 wheel scroll         | Wheel rotation animation   | `sfx_click`          | Detent click            |
| Ch. 3 segment lock         | Glow confirmation          | `sfx_haptic_thud`    | `thud.ahap`             |
| Ch. 4 beat hit             | Shield flash               | `sfx_shield_impact`  | `heartbeat.ahap`        |
| Ch. 5 node connect         | Line draw animation        | `sfx_success_chime`  | Light transient         |
| Ch. 5 invalid connect      | Snap-back animation        | `sfx_error`          | Error buzz              |
| Ch. 6 slider progress      | Fill bar animation         | Intensity ramp       | Progressive intensity   |
| Ch. 6 finale               | Confetti particle system   | `audio_bgm_finale`   | `heartbeat.ahap`        |

If haptic column fails: visual + audio provide complete feedback. No user action requires haptic confirmation to proceed.
