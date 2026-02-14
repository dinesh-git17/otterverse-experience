---
name: corehaptics-engine
description: Enforce CoreHaptics lifecycle management, AHAP asset caching, engine crash recovery, graceful degradation, and multi-sensory redundancy for HapticManager implementation. Use when HapticManager is implemented or modified, AHAP files are added or updated, haptic playback is integrated into chapters, or engine lifecycle handling is implemented. Triggers on haptic integration, engine lifecycle, AHAP parsing, haptic playback, or HapticManager modification.
---

# CoreHaptics Engine

Deterministic enforcement of CoreHaptics integration patterns covering `CHHapticEngine` lifecycle management, AHAP asset parsing and caching, crash recovery handlers, graceful degradation, and multi-sensory synchronization as defined in `Design-Doc.md` §7.6, §8.3, and §12.3.

## Pre-Implementation Verification

Before generating or modifying haptic code, verify:

1. The target component is `HapticManager` at `Managers/HapticManager.swift`.
2. No direct `CHHapticEngine` usage exists outside `HapticManager`.
3. All AHAP files referenced exist in the `Haptics/` bundle directory.

If any verification fails, **HALT** and cite the conflict.

## Workflow

### Step 1: Determine Task Type

Identify the scope of work:

**Implementing HapticManager?** → Follow Full Lifecycle Workflow
**Adding or modifying AHAP patterns?** → Follow Asset Management Workflow
**Integrating haptics into a chapter?** → Follow Playback Integration Workflow
**Fixing engine recovery?** → Follow Recovery Workflow

---

### Full Lifecycle Workflow

#### Phase 1: Engine Initialization

`HapticManager` MUST be a `@MainActor` singleton using `@Observable`. Initialization sequence:

```
1. Check CHHapticEngine.capabilitiesForHardware().supportsHaptics
2. If unsupported → set engineAvailable = false, return (silent no-op)
3. Create CHHapticEngine instance
4. Register stoppedHandler
5. Register resetHandler
6. Call engine.start()
7. Parse and cache all AHAP patterns (§7.6)
```

**Capability check MUST occur before engine creation.** If the device lacks a Taptic Engine, `HapticManager` becomes a silent no-op — no errors, no throws, no UI impact.

#### Phase 2: Handler Registration

**`stoppedHandler` requirements:**

```swift
engine.stoppedHandler = { [weak self] reason in
    // Log reason via os.Logger (#if DEBUG only)
    // Attempt restart: try engine.start()
    // On failure: set engineAvailable = false
}
```

- MUST use `[weak self]` capture
- MUST attempt engine restart exactly once
- MUST NOT throw or propagate errors to callers
- MUST NOT block the calling thread
- MUST update `engineAvailable` state on unrecoverable failure

**`resetHandler` requirements:**

```swift
engine.resetHandler = { [weak self] in
    // Recreate engine instance
    // Re-register stoppedHandler and resetHandler
    // Re-cache all AHAP patterns
    // Restart engine
}
```

- MUST recreate the engine (the old instance is invalid after reset)
- MUST re-register both handlers on the new engine
- MUST re-parse and re-cache all AHAP patterns
- MUST call `engine.start()` on the new instance
- On failure: set `engineAvailable = false`, continue without haptics

#### Phase 3: Teardown

Engine teardown occurs only at app termination. `HapticManager` holds the engine for the full session. No chapter-level teardown.

---

### Asset Management Workflow

#### AHAP Registry

Three AHAP pattern files are defined in `Design-Doc.md` §7.6:

| Asset ID                | File Path                       | Chapter Usage |
| ----------------------- | ------------------------------- | ------------- |
| `heartbeat.ahap`        | `Haptics/heartbeat.ahap`        | Ch. 4, Ch. 6  |
| `capacitor_charge.ahap` | `Haptics/capacitor_charge.ahap` | Ch. 1         |
| `thud.ahap`             | `Haptics/thud.ahap`             | Ch. 3         |

#### Parsing Rules

1. Parse all AHAP files during the launch pre-load sequence (§7.9.2, step 3)
2. Use `CHHapticPattern(contentsOf: url)` where `url` is obtained via `Bundle.main.url(forResource:withExtension:)`
3. Parse **once** at launch. Never re-parse during gameplay.
4. Store parsed `CHHapticPattern` objects in a dictionary keyed by asset identifier
5. Handle parse failures gracefully: log under `#if DEBUG`, skip the pattern, continue

#### Caching Rules

```
cachedPatterns: [String: CHHapticPattern]
```

- Key: AHAP filename without extension (e.g., `"heartbeat"`)
- Value: Parsed `CHHapticPattern` instance
- Lifetime: Entire app session (no eviction)
- Memory: <1MB total for all patterns (lightweight JSON-derived structs)
- Thread safety: Cache populated once at launch, read-only thereafter

#### Player Creation

Create `CHHapticPatternPlayer` instances on demand from cached patterns:

```
1. Look up CHHapticPattern in cache by identifier
2. If not found → return silently (pattern parse may have failed)
3. Create player: try engine.makePlayer(with: pattern)
4. Start player: try player.start(atTime: CHHapticTimeImmediate)
5. Catch all errors → log under #if DEBUG, continue
```

Players are transient. Create per-playback, do not cache players.

---

### Playback Integration Workflow

#### Access Rules

| Caller            | Permitted?                           |
| ----------------- | ------------------------------------ |
| Chapter View      | NO — route through coordinator event |
| `SKScene`         | NO — route through coordinator event |
| `FlowCoordinator` | YES — calls `HapticManager` methods  |
| `AudioManager`    | NO — parallel channel, not dependent |

Chapter views and scenes MUST NOT call `HapticManager` directly. Haptic triggers flow through `FlowCoordinator` or through the chapter view calling a coordinator method that internally triggers haptics.

**Exception:** Chapter views MAY call `HapticManager` directly for immediate UI feedback (wheel scroll detents, tap confirmations) where coordinator round-tripping adds latency. In this case, the view calls a single `HapticManager.play(_:)` method — no direct `CHHapticEngine` access.

#### Synchronization

Haptic, audio, and visual feedback MUST fire in the same run loop iteration for perceptual simultaneity:

```
1. FlowCoordinator receives chapter event
2. In the same @MainActor context:
   a. Trigger visual state change (SwiftUI @Observable mutation)
   b. Trigger AudioManager.playSFX(_:)
   c. Trigger HapticManager.play(_:)
3. All three fire within the same main thread dispatch
```

For time-critical synchronization (Chapter 4 rhythm game), use `CACurrentMediaTime()` as the shared clock source. `CHHapticPatternPlayer.start(atTime:)` accepts `TimeInterval` relative to `CACurrentMediaTime()`.

#### Degradation Guarantee

If `HapticManager.engineAvailable == false`:

- All `play(_:)` calls return immediately with no side effects
- No errors thrown or logged at runtime (parse-time logging under `#if DEBUG` only)
- Visual and audio channels continue independently
- Chapter progression is never gated on haptic success
- Auto-Assist logic is never gated on haptic state

---

### Recovery Workflow

Engine recovery follows a strict sequence:

```
stoppedHandler fires
  → Attempt engine.start()
  → Success? Resume normal operation
  → Failure? Set engineAvailable = false

resetHandler fires
  → Old engine instance is invalid
  → Create new CHHapticEngine()
  → Register stoppedHandler on new engine
  → Register resetHandler on new engine
  → Parse all AHAP patterns into new cache
  → Attempt new engine.start()
  → Success? Replace engine reference, resume
  → Failure? Set engineAvailable = false
```

**Critical invariant:** At no point does engine failure propagate beyond `HapticManager`. The rest of the app — coordinator, views, scenes, audio — operates identically whether haptics are available or not.

---

## Structural Constraints

### Singleton Pattern

```swift
@MainActor
@Observable
final class HapticManager {
    static let shared = HapticManager()
    private init() { /* lifecycle init */ }
}
```

- `@MainActor` isolation for thread safety
- `@Observable` for SwiftUI state reactivity (if `engineAvailable` drives UI)
- `private init` prevents additional instances
- No `ObservableObject`, no `@Published`, no Combine

### Method Signatures

Public API surface MUST be minimal:

```swift
func play(_ patternName: String)
func preloadPatterns()
```

- `play(_:)` — fire-and-forget, no return value, no throws
- `preloadPatterns()` — called once during launch sequence
- No public access to `CHHapticEngine`, `CHHapticPattern`, or `CHHapticPatternPlayer`
- Internal state (`engineAvailable`, `cachedPatterns`) is `private` or `private(set)`

### Error Handling

- All `try` calls on CoreHaptics APIs wrapped in `do/catch`
- Catch blocks: log via `os.Logger` under `#if DEBUG`, set degraded state
- No `try!` or `try?` with ignored results where failure indicates engine death
- `try?` permitted only for transient player creation where individual playback failure is acceptable

### Naming

| Element                    | Name                                   |
| -------------------------- | -------------------------------------- |
| Singleton                  | `HapticManager.shared`                 |
| Pattern cache              | `cachedPatterns`                       |
| Engine reference           | `engine`                               |
| Availability flag          | `engineAvailable`                      |
| Play method                | `play(_:)`                             |
| Preload method             | `preloadPatterns()`                    |
| Pattern identifiers (enum) | `HapticPattern` or via `GameConstants` |

---

## Anti-Patterns (Reject These)

- **Direct CHHapticEngine access from views or scenes.** All haptics route through `HapticManager`.
- **Synchronous engine.start() on main thread without async context.** Engine start is async-safe; use `Task` if called from synchronous context.
- **Caching CHHapticPatternPlayer instances.** Players are lightweight and transient. Create per-playback.
- **Missing stoppedHandler or resetHandler.** Both are mandatory. Engine without recovery handlers is a governance violation.
- **Force unwrapping Bundle.main.url(forResource:withExtension:).** AHAP file lookup returns optional. Guard and degrade.
- **Gating chapter progression on haptic availability.** Haptics are enhancement-only. Progression is independent.
- **Using Timer or DispatchQueue for haptic timing.** Use `CACurrentMediaTime()` exclusively.
- **ObservableObject or @Published on HapticManager.** Use `@Observable`.
- **Combine publishers for haptic events.** Use direct method calls from coordinator context.
- **print() for haptic debug logging.** Use `os.Logger` under `#if DEBUG`.
- **Re-parsing AHAP files on each playback.** Parse once at launch, cache for session.

## Post-Implementation Validation

After implementing or modifying haptic code, verify:

- [ ] `HapticManager` is the sole owner of `CHHapticEngine`
- [ ] `stoppedHandler` is registered and attempts restart
- [ ] `resetHandler` is registered and recreates engine + re-caches patterns
- [ ] All three AHAP patterns are parsed at launch and cached
- [ ] `play(_:)` is fire-and-forget with no throws
- [ ] Engine failure never propagates to UI or coordinator
- [ ] Chapter progression never depends on haptic availability
- [ ] No direct `CHHapticEngine` usage outside `HapticManager`
- [ ] No force unwraps on Bundle URL lookups
- [ ] No Combine, no GCD, no `ObservableObject`
- [ ] No `print()` statements (use `os.Logger` under `#if DEBUG`)
- [ ] Multi-sensory redundancy preserved (visual + audio unaffected by haptic failure)

## Resources

- **References**: See [references/lifecycle-patterns.md](references/lifecycle-patterns.md) for engine state machine and recovery sequences
