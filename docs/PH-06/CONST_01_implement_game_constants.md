# Epic: CONST_01 — Implement GameConstants & Type-Safe Models

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | CONST_01                       |
| **Epic Name** | implement_game_constants       |
| **Phase**     | PH-06                          |
| **Domain**    | CONST                          |
| **Owner**     | iOS Engineer                   |
| **Status**    | Complete                       |

---

## Problem Statement

After PH-05 completion, all visual, audio, and haptic assets are integrated into the app bundle and the pre-load coordinator orchestrates their runtime decoding. However, every chapter implementation (PH-07 through PH-13) requires numeric tuning values — Auto-Assist thresholds, difficulty modifiers, animation timing, physics parameters, and the Chapter 4 beat map — that currently have no centralized definition. Without `GameConstants.swift`, each chapter developer would introduce magic number literals (e.g., `3` for death threshold, `0.5` for cross-fade duration, `60.0` for runner duration) scattered across view and scene files, violating CLAUDE.md §4.7 ("No magic numbers. All tuning values in `GameConstants`").

Additionally, existing manager code (AudioManager, HapticManager, AssetPreloadCoordinator) and all future chapter code reference assets via stringly-typed `String` literals (`"img_bg_intro"`, `"sfx_haptic_thud"`, `"heartbeat"`). CLAUDE.md §4.7 mandates "No stringly-typed APIs. Use enums for identifiers, asset names, UserDefaults keys." Without type-safe enums, asset identifier typos become silent runtime failures — a `UIImage(named:)` call with a misspelled identifier returns `nil` with no compiler diagnostic.

The Chapter 4 beat map (Design Doc §7.5) — a `[TimeInterval]` array of percussive hit timestamps synced to `audio_bgm_main` — must be authored and stored in `GameConstants` before `FirewallScene` can implement beat-synced noise particle spawning. The PHASES.md risk register identifies beat map authoring as the first task in PH-06 to surface timing accuracy issues early.

---

## Goals

- Create `GameConstants.swift` as a caseless `enum` namespace containing every numeric tuning value referenced by Design Doc §3.2–§3.8, eliminating all magic numbers from game logic.
- Define the complete Auto-Assist threshold matrix (Design Doc §3.8): 3 deaths, 3 incorrect attempts, 5 misses, 10s idle.
- Define all difficulty modifiers: speed reduction (−20%), gap width increase (+20%), hit windows (±150ms default, ±300ms assisted).
- Define all timing constants: 500ms cross-fade, 60s runner duration, 45s firewall duration, 3s long-press minimum, 0.8 slider exponent.
- Author the Chapter 4 beat map as a `[TimeInterval]` array with monotonically increasing timestamps within the `audio_bgm_main` track duration (Design Doc §7.5).
- Define type-safe `String`-backed enums for background asset identifiers, sprite atlas identifiers, audio identifiers (BGM + SFX), haptic pattern identifiers, and UserDefaults keys — replacing all stringly-typed access patterns.
- Register `GameConstants.swift` in `project.pbxproj` so the file compiles in the Sources build phase.

## Non-Goals

- **No modifications to existing manager code.** AudioManager, HapticManager, and AssetPreloadCoordinator currently use inline string literals for asset identifiers. Migrating these managers to consume `GameConstants` enums is a refactoring task outside PH-06 scope. Chapters (PH-07+) will use `GameConstants` enums from inception.
- **No modifications to FlowCoordinator.** The `Chapter` enum and `highestUnlockedChapterKey` constant are already defined in `FlowCoordinator.swift`. `GameConstants` provides complementary enums for assets and settings, not a replacement for the coordinator's internal state model.
- **No Chapter 5 node coordinates.** The 12-node heart silhouette layout (Design Doc §3.6) requires design iteration during PH-11 implementation. `GameConstants` defines the idle threshold (10s) and node count (12), but exact `CGPoint` coordinates are authored in PH-11.
- **No chapter implementation code.** This epic produces a data-only constants file. No views, scenes, or game logic.
- **No unit tests.** Beat map validation tests (monotonicity, duration bounds) are PH-15 scope. This epic defines the data; PH-15 validates it.
- **No runtime FFT or audio analysis.** The beat map is manually authored per Design Doc §7.5. No algorithmic beat detection.

---

## Technical Approach

`GameConstants` is implemented as a caseless `enum` (no instances, pure namespace) at `StarlightSync/Models/GameConstants.swift`. Nested caseless enums provide logical grouping: `GameConstants.AutoAssist`, `GameConstants.Timing`, `GameConstants.Difficulty`, `GameConstants.Physics`, and `GameConstants.BeatMap` for numeric constants, plus `GameConstants.BackgroundAsset`, `GameConstants.SpriteAsset`, `GameConstants.AudioAsset`, `GameConstants.HapticAsset`, and `GameConstants.Persistence` for type-safe `String`-backed identifier enums.

All numeric constants are `static let` properties with explicit types (`Int`, `TimeInterval`, `Float`, `Double`). Type-safe identifier enums conform to `String` with `rawValue` strings matching the exact identifiers used by `UIImage(named:)`, `SKTextureAtlas.textureNamed()`, `Bundle.main.url(forResource:withExtension:)`, and `UserDefaults` key strings. This pattern enables compile-time verification of identifier usage — a deleted enum case produces a compiler error at every call site, unlike a silently broken string literal.

The beat map array is a `static let beatMap: [TimeInterval]` property within `GameConstants.BeatMap`. Timestamps are authored by analyzing `audio_bgm_main.m4a` and marking percussive hits manually. The array must satisfy two invariants: (1) monotonically increasing values, and (2) all values within the track duration. These invariants are verified by unit tests in PH-15, not enforced at compile time.

The file is registered in `project.pbxproj` with a `PBXFileReference` entry, a `PBXBuildFile` entry referencing it, inclusion in the Models `PBXGroup`, and inclusion in the `PBXSourcesBuildPhase`. This follows the established pbxproj registration pattern used by all prior source files (AudioManager, HapticManager, AssetPreloadCoordinator, FlowCoordinator).

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| `FlowCoordinator.Chapter` enum for chapter identifier alignment | COORD_01 (PH-02) | Complete | iOS Engineer |
| `audio_bgm_main.m4a` in bundle for beat map timestamp authoring | ASSET_03 (PH-05) | Complete | iOS Engineer |
| AHAP file names (`heartbeat`, `capacitor_charge`, `thud`) for haptic enum alignment | ASSET_04 (PH-05) | Complete | iOS Engineer |
| Asset catalog identifiers for background and sprite enum alignment | ASSET_01 (PH-05) | Complete | iOS Engineer |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| Auto-Assist thresholds and difficulty modifiers | PH-07 through PH-13 | Every chapter consumes `GameConstants.AutoAssist` and `GameConstants.Difficulty` values for adaptive difficulty logic |
| Timing constants | PH-07 through PH-13 | Chapters reference `GameConstants.Timing` for animation durations, hold thresholds, game timers |
| Beat map array | PH-10 (Chapter 4 Firewall) | `FirewallScene` schedules `sprite_noise_particle` spawning from `GameConstants.BeatMap.timestamps` |
| Type-safe asset enums | PH-07 through PH-13 | Chapters reference `GameConstants.BackgroundAsset`, `SpriteAsset`, `AudioAsset`, `HapticAsset` for compile-time-safe asset access |
| Beat map data for validation tests | PH-15 (Unit Tests) | Beat map monotonicity and duration-bound tests consume `GameConstants.BeatMap.timestamps` |
| Slider exponent constant | PH-13 (Chapter 6) | `FrictionSlider` uses `GameConstants.Timing.sliderExponent` for progressive resistance calculation |

---

## Stories

### Story 1: Create GameConstants namespace with Auto-Assist threshold constants

**Acceptance Criteria:**

- [x] `GameConstants.swift` exists at `StarlightSync/Models/GameConstants.swift`.
- [x] `GameConstants` is a caseless `enum` (no cases, no `init`).
- [x] Nested caseless `enum AutoAssist` contains exactly 4 `static let` constants:
  - `runnerDeathThreshold: Int = 3` (Ch. 2, Design Doc §3.3)
  - `cipherIncorrectThreshold: Int = 3` (Ch. 3, Design Doc §3.4)
  - `firewallMissThreshold: Int = 5` (Ch. 4, Design Doc §3.5)
  - `blueprintIdleThreshold: TimeInterval = 10.0` (Ch. 5, Design Doc §3.6)
- [x] Every constant value traces to a specific Design Doc §3.8 table cell.
- [x] File compiles with zero errors and zero warnings.
- [x] No magic numbers — every value is a named constant with a descriptive identifier.

**Dependencies:** None
**Completion Signal:** `GameConstants.AutoAssist.runnerDeathThreshold` resolves in code completion and compiles.

---

### Story 2: Add game timing and duration constants

**Acceptance Criteria:**

- [x] Nested caseless `enum Timing` contains all game timing values as `static let` properties:
  - `crossFadeDuration: TimeInterval = 0.5` (Design Doc §7.4, §8.4)
  - `runnerDuration: TimeInterval = 60.0` (Design Doc §3.3)
  - `firewallDuration: TimeInterval = 45.0` (Design Doc §3.5)
  - `handshakeHoldDuration: TimeInterval = 3.0` (Design Doc §3.2)
  - `sliderExponent: Double = 0.8` (Design Doc §3.7)
  - `blueprintIdlePulseDuration: TimeInterval = 10.0` — alias to `AutoAssist.blueprintIdleThreshold` or standalone constant (Design Doc §3.6)
- [x] Every timing value has an explicit `TimeInterval` or `Double` type annotation.
- [x] No `Timer`, `DispatchQueue`, or `Task.sleep` references (constants only — timing mechanism is the consumer's responsibility per CLAUDE.md §4.5).
- [x] All values traceable to specific Design Doc sections.

**Dependencies:** CONST_01-S1 (GameConstants namespace must exist)
**Completion Signal:** `GameConstants.Timing.runnerDuration` compiles and equals `60.0`.

---

### Story 3: Add difficulty modifier and physics tuning constants

**Acceptance Criteria:**

- [x] Nested caseless `enum Difficulty` contains:
  - `runnerSpeedReduction: Double = 0.20` (Design Doc §3.3, "speed −20%")
  - `runnerGapIncrease: Double = 0.20` (Design Doc §3.3, "gap width +20%")
  - `firewallDefaultHitWindow: TimeInterval = 0.150` (Design Doc §3.5, ±150ms)
  - `firewallAssistedHitWindow: TimeInterval = 0.300` (Design Doc §3.5, ±300ms)
- [x] Nested caseless `enum Physics` contains Chapter 2 runner physics tuning:
  - `runnerHeartTarget: Int = 20` (Design Doc §3.3, collect 20 hearts)
  - `targetFrameRate: Int = 120` (Design Doc §10.2, ProMotion)
- [x] All percentage values stored as `Double` fractions (0.20, not 20) for direct multiplication in game logic.
- [x] Hit window values stored as positive `TimeInterval` — consuming code applies ± bidirectionally.
- [x] No physics body configuration or SpriteKit imports — pure numeric data.

**Dependencies:** CONST_01-S1
**Completion Signal:** `GameConstants.Difficulty.firewallDefaultHitWindow` compiles and equals `0.150`.

---

### Story 4: Author Chapter 4 beat map timestamp array

**Acceptance Criteria:**

- [x] Nested caseless `enum BeatMap` contains `static let timestamps: [TimeInterval]` with manually authored percussive hit timestamps synced to `audio_bgm_main.m4a`.
- [x] Array contains a minimum of 25 entries (sufficient for ~45s at reasonable beat density).
- [x] All timestamps are monotonically increasing (`timestamps[i] < timestamps[i+1]` for all valid `i`).
- [x] All timestamps are positive and within the `audio_bgm_main` track duration.
- [x] First timestamp is ≥0.5s (allow audio playback initialization latency).
- [x] Timestamps represent percussive hits suitable for noise particle spawning (Design Doc §7.5).
- [x] No runtime FFT or audio analysis — timestamps are static compile-time data.
- [x] A `static let trackDuration: TimeInterval` constant stores the `audio_bgm_main` total duration for validation reference.

**Dependencies:** CONST_01-S1, ASSET_03 (audio file must exist in bundle for manual analysis)
**Completion Signal:** `GameConstants.BeatMap.timestamps` compiles as a non-empty `[TimeInterval]` array with monotonically increasing values.

---

### Story 5: Define type-safe enums for visual asset identifiers

**Acceptance Criteria:**

- [x] `enum BackgroundAsset: String` with cases matching asset catalog identifiers exactly:
  - `case intro = "img_bg_intro"`
  - `case runner = "img_bg_runner"`
  - `case cipher = "img_bg_cipher"`
  - `case blueprint = "img_bg_blueprint"`
  - `case finale = "img_finale_art"`
- [x] `enum SpriteAsset: String` with cases matching sprite atlas texture names exactly:
  - `case otterPlayer = "sprite_otter_player"`
  - `case obstacleGlitch = "sprite_obstacle_glitch"`
  - `case heartPickup = "sprite_heart_pickup"`
  - `case noiseParticle = "sprite_noise_particle"`
  - `case bubbleShield = "img_bubble_shield"`
- [x] `enum SpriteAtlas: String` with a single case:
  - `case sprites = "Sprites"`
- [x] All `rawValue` strings match the identifiers registered in `Assets.xcassets` by ASSET_01 and used by `AssetPreloadCoordinator`.
- [x] Enums are nested inside `GameConstants` or defined at file scope within `GameConstants.swift`.
- [x] Chapter views (PH-07+) can reference `GameConstants.BackgroundAsset.intro.rawValue` instead of `"img_bg_intro"`.

**Dependencies:** CONST_01-S1, ASSET_01 (asset catalog identifiers must be finalized)
**Completion Signal:** `GameConstants.BackgroundAsset.intro.rawValue == "img_bg_intro"` compiles and evaluates to `true`.

---

### Story 6: Define type-safe enums for audio, haptic, and persistence identifiers

**Acceptance Criteria:**

- [x] `enum AudioAsset: String` with cases for all 7 audio files (Design Doc §7.4):
  - `case bgmMain = "audio_bgm_main"`
  - `case bgmFinale = "audio_bgm_finale"`
  - `case sfxThud = "sfx_haptic_thud"`
  - `case sfxChime = "sfx_success_chime"`
  - `case sfxShieldImpact = "sfx_shield_impact"`
  - `case sfxClick = "sfx_click"`
  - `case sfxError = "sfx_error"`
- [x] `static let audioFileExtension = "m4a"` for consistent bundle resolution.
- [x] `enum HapticAsset: String` with cases for all 3 AHAP patterns (Design Doc §7.6):
  - `case heartbeat = "heartbeat"`
  - `case capacitorCharge = "capacitor_charge"`
  - `case thud = "thud"`
- [x] `static let hapticFileExtension = "ahap"` for consistent bundle resolution.
- [x] `enum Persistence: String` with the single UserDefaults key:
  - `case highestUnlockedChapter = "highestUnlockedChapter"`
- [x] All `rawValue` strings match the identifiers used by `AudioManager.preloadAssets()`, `HapticManager.preloadPatterns()`, and `FlowCoordinator`.
- [x] No additional UserDefaults keys beyond what Design Doc §4.3 specifies.

**Dependencies:** CONST_01-S1, ASSET_03 (audio file names), ASSET_04 (AHAP file names)
**Completion Signal:** `GameConstants.AudioAsset.bgmMain.rawValue == "audio_bgm_main"` compiles and evaluates to `true`.

---

### Story 7: Register GameConstants.swift in project.pbxproj and validate governance compliance

**Acceptance Criteria:**

- [x] `GameConstants.swift` has a `PBXFileReference` entry in `project.pbxproj`.
- [x] A `PBXBuildFile` entry references the `PBXFileReference`.
- [x] The file reference is listed in the Models `PBXGroup` children array.
- [x] The build file is listed in the `PBXSourcesBuildPhase` files array.
- [x] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0, zero errors, zero warnings.
- [x] `python3 scripts/audit.py --all` passes with zero violations (7/7 checks).
- [x] No Protocol Zero violations — no AI attribution in file headers, comments, or identifiers.
- [x] No force unwraps (`!`) anywhere in the file.
- [x] No `print` statements.
- [x] No `import` statements beyond `Foundation` (pure data file — no framework dependencies).
- [x] File body follows CLAUDE.md §4.7 naming conventions: `lowerCamelCase` for constants, `UpperCamelCase` for types.
- [x] Models `.gitkeep` placeholder removed if present.

**Dependencies:** CONST_01-S1 through CONST_01-S6 (all constants defined before final validation)
**Completion Signal:** Clean build, audit 7/7, file registered in all 4 required pbxproj sections.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| Beat map timestamps misaligned with actual percussive hits in `audio_bgm_main` | 3 | 3 | 9 | Define beat map as a `GameConstants` tunable. PH-16 on-device QA allocates explicit time for perceptual beat map validation and iterative adjustment. Timestamps are refined by listening on the target device. | iOS Engineer |
| Enum `rawValue` strings diverge from actual asset catalog or bundle resource names | 4 | 2 | 8 | Acceptance criteria require exact string matching against identifiers registered by ASSET_01, ASSET_03, and ASSET_04. PH-15 unit tests validate that identifiers resolve to non-nil resources at runtime. | iOS Engineer |
| `audio_bgm_main` track duration unknown until runtime analysis, making beat map bounds validation impossible at compile time | 2 | 2 | 4 | Store `trackDuration` as a `GameConstants.BeatMap` constant authored alongside timestamps. PH-15 tests validate `timestamps.last <= trackDuration`. Duration is verified via `AVAudioPlayer.duration` in PH-16. | iOS Engineer |
| Constant names clash with identifiers in existing FlowCoordinator or manager code | 2 | 1 | 2 | GameConstants uses nested enums for namespacing. All constants are accessed as `GameConstants.X.y`, eliminating global namespace collisions. FlowCoordinator retains its own `Chapter` enum unchanged. | iOS Engineer |

---

## Definition of Done

- [x] All 7 stories completed and individually verified.
- [x] `GameConstants.swift` compiles as a single file with no external dependencies beyond `Foundation`.
- [x] Every Auto-Assist threshold, timing value, difficulty modifier, and physics constant traces to a specific Design Doc section.
- [x] Beat map array contains ≥25 monotonically increasing timestamps within track duration.
- [x] All type-safe enums have `rawValue` strings matching asset catalog, bundle resource, and UserDefaults identifiers exactly.
- [x] `xcodebuild build` succeeds with zero errors and zero warnings.
- [x] `scripts/audit.py --all` passes with zero violations (7/7 checks).
- [x] No Protocol Zero violations.
- [x] No force unwraps, no `print` statements, no deprecated APIs.
- [x] File registered in all 4 required `project.pbxproj` sections (PBXFileReference, PBXBuildFile, PBXGroup, PBXSourcesBuildPhase).
- [x] Models directory `.gitkeep` removed if present.

## Exit Criteria

- [x] All Definition of Done conditions satisfied.
- [x] PH-07 through PH-13 (all chapter implementations) are unblocked — every chapter can reference `GameConstants` for thresholds, timing, and asset identifiers.
- [x] PH-15 (unit test suite) is unblocked — beat map validation tests can consume `GameConstants.BeatMap.timestamps`.
- [x] PH-10 (Chapter 4 Firewall) is unblocked — beat map timestamps exist for `FirewallScene` noise particle scheduling.
- [x] No residual magic numbers or stringly-typed identifiers required by any downstream phase.
- [x] Epic ID `CONST_01` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
