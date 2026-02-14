# Technical Design Document: Project OtterVerse — Starlight Sync

| **Author**        | **Dinesh (Staff Engineer, Love & Data Div.)**  |
| ----------------- | ---------------------------------------------- |
| **Status**        | **APPROVED FOR DEVELOPMENT**                   |
| **Platform**      | iOS Native (SwiftUI + SpriteKit + CoreHaptics) |
| **Target Device** | iPhone 17 Pro (A19 Pro, 120Hz ProMotion, 8GB+) |
| **Distribution**  | TestFlight (Apple Developer Program)           |
| **Last Reviewed** | 2026-02-14 (Staff Architect Review)            |

---

## 1. Executive Summary

### 1.1 Problem Statement

Long-distance communication suffers from "emotional compression."
Text bubbles and video calls lack the tactile weight and immersive
quality required for a significant relationship milestone.

### 1.2 Product Vision

**Starlight Sync** is a high-fidelity, native iOS experience designed
to re-inject "texture" into digital intimacy. By leveraging
CoreHaptics, Metal-accelerated graphics (SpriteKit), and spatial
audio, we create a 25-minute immersive narrative that guides the user
(Carolina) through a gamified metaphor of the relationship,
culminating in a permanent "Forever" commitment.

### 1.3 Core Value Proposition

- **Tactile Narrative:** Haptics and physics-based animations replace static UI.
- **Zero Latency:** All assets are pre-loaded into memory at launch
  (~300MB RAM) to ensure 120Hz fluidity on ProMotion display.
- **The "Forever" Signal:** A Discord webhook notifies the Creator
  (Dinesh) immediately upon completion, with 3x retry and
  fire-and-forget semantics ensuring the UI is never blocked.

---

## 2. Goals & Non-Goals

### 2.1 Goals

- Deliver a single-user, 25-minute immersive narrative experience for Carolina.
- Achieve 120Hz visual fluidity with zero loading screens between chapters.
- Provide tactile depth via CoreHaptics custom patterns synchronized with visual and audio feedback.
- Ensure the experience is completable regardless of gaming skill via Auto-Assist difficulty reduction.
- Notify Dinesh in real-time when Chapter 6 is completed via Discord webhook.

### 2.2 Non-Goals

- **Android support:** Out of scope. The experience is designed exclusively for iOS and Apple's native frameworks.
- **iPad support:** Out of scope. UI is designed for iPhone portrait mode only.
- **Multiplayer / shared experience:** Out of scope. This is a single-user narrative.
- **Localization / i18n:** Out of scope. All text is in English.
- **Replay value / randomized content:** Out of scope. The experience is a fixed linear narrative.
- **App Store public distribution:** Out of scope. Distribution is via TestFlight to a single user.
- **Backend infrastructure:** Out of scope. The app is fully offline-capable with a single fire-and-forget webhook.
- **Analytics / telemetry beyond the webhook:** Out of scope. TestFlight crash logs provide sufficient observability.

---

## 3. User Experience Definition (The 6-Chapter Arc)

### 3.1 Flow Control

The narrative is **strictly linear**. The user progresses
Chapter 1 → 2 → 3 → 4 → 5 → 6. There is no backward navigation
or chapter selection.

Each chapter has a **per-chapter Auto-Assist system** that
progressively reduces difficulty after repeated failures, ensuring
the user can never become permanently stuck. See §3.8 for
specifications.

### 3.2 Chapter 1: The Handshake (Connection)

- **Visual:** Deep black OLED background. A single, pulsing fingerprint glyph (SFSymbol `touchid`).
- **Interaction:** Long-press (minimum 3 seconds).
- **Haptics:** `CHHapticPattern` simulating a capacitor charge—increasing intensity and sharpness until a "snap."
- **Transition:** Screen "powers on" (CRT turn-on effect) into the Main Menu.

### 3.3 Chapter 2: The Packet Run (SpriteKit Infinite Runner)

- **Context:** "Distance is just latency."
- **Visual:** Neon Grid (Tron-style) with a parallax starfield background.
- **Character:** `Otter-Dinn` on a hoverboard.
- **Mechanic:** Tap to jump. Hold to glide. Avoid "Lag Spikes" (Glitch barriers). Collect "Packets" (Hearts).
- **Win Condition:** Survive 60 seconds or collect 20 hearts.
- **Auto-Assist:** After 3 deaths, obstacle speed reduces by 20% and gap width increases by 20%.

### 3.4 Chapter 3: The Cipher (Data Decryption)

- **Context:** "We have our own language."
- **Visual:** A Cryptex / Combination Lock interface. Brushed Metal/Glass texture.
- **Puzzle:** The phrase **"THIS IS CRIMINAL BEHAVIOUR"** is scrambled.
- **Interaction:** 3 segment-level scroll wheels arranged vertically, each representing a phrase segment:
  - Wheel 1: **"THIS IS"**
  - Wheel 2: **"CRIMINAL"**
  - Wheel 3: **"BEHAVIOUR"**
- **Haptics:** Each wheel scroll produces a haptic "click." When a
  correct segment aligns, a heavy "thud" `CHHapticEvent` fires.
- **UX Details:** Spaces between segments are pre-filled. Each wheel
  scrolls through scrambled phrase segments (not individual letters).
  The interaction mimics a physical Cryptex lock.
- **Win Condition:** All three wheels aligned to the correct segments.
- **Auto-Assist:** After 3 incorrect attempts, the correct wheel segment is highlighted with a subtle glow.

### 3.5 Chapter 4: The Firewall (Rhythm Defense)

- **Context:** "Protecting the Peace."
- **Visual:** Otters inside a glowing bubble center screen. "Noise" particles spawn from edges.
- **Mechanic:** Tap the side of the screen where noise approaches.
- **Audio-Sync:** Noise spawns on the beat of the background track
  using a **pre-authored beat map** (manually defined timestamp array
  synced to the specific track). No runtime FFT analysis.
- **Hit Window:** ±150ms default tolerance.
- **Win Condition:** Survive the duration of the song verse (approx. 45s).
- **Auto-Assist:** After 5 misses, the hit window widens to ±300ms ("God Mode"), making it effectively impossible to fail.

### 3.6 Chapter 5: The Blueprint (Constellation Zen)

- **Context:** "Building the Future."
- **Visual:** Architectural blueprint (Deep Blue background, White chalk lines).
- **Mechanic:** Connect-the-dots. Drag finger from node to node in sequential order (A→B→C→...).
- **Target Shape:** Fixed **heart silhouette**.
- **Nodes:** 12 total nodes:
  - 4 **labeled cornerstone nodes** positioned at key waypoints:
    **"Paris"** (top-left bump), **"New Apt"** (top-right bump),
    **"Dog"** (center dip), **"Coffee"** (bottom point).
  - 8 **unlabeled structural nodes** positioned between cornerstones
    to complete the recognizable heart curve.
- **Connection Rules:** Connections must be made sequentially.
  Incorrect connections snap back to the previous valid node with
  an error haptic feedback.
- **Win Condition:** All 12 nodes connected, completing the heart shape.
- **Auto-Assist:** After 10 seconds of idle (no interaction), the next correct node pulses with a glow animation.

### 3.7 Chapter 6: The Event Horizon (The Ask)

- **Visual:** White void that slowly fills with color.
- **Interaction:** A custom "Slide to Confirm" slider with
  **progressive resistance**. The slider uses a logarithmic decay
  function (`drag_position = finger_distance ^ 0.8`), making the
  handle feel physically "heavier" the closer it gets to completion,
  creating a "breaking through a barrier" moment at 100%.
- **Text:** **"Will you be mine forever?"**
- **Outcome:**
  - **User Action:** Slide completes (reaches 100% against progressive resistance).
  - **System (parallel):**
    1. Fires Discord webhook (fire-and-forget, non-blocking).
    2. Plays **"The Special Song"** (original composition, pre-loaded).
    3. Triggers confetti particle system.
  - **Webhook never blocks the UI.** The animation and music play instantly regardless of network status.

### 3.8 Auto-Assist Specification

| Chapter               | Trigger              | Mechanism                         | Effect                         |
| --------------------- | -------------------- | --------------------------------- | ------------------------------ |
| **Ch. 2 (Runner)**    | 3 deaths             | Reduce obstacle speed, widen gaps | Speed -20%, Gap width +20%     |
| **Ch. 3 (Cipher)**    | 3 incorrect attempts | Highlight correct wheel segment   | Subtle glow on correct segment |
| **Ch. 4 (Rhythm)**    | 5 misses             | Widen hit window                  | ±150ms → ±300ms ("God Mode")   |
| **Ch. 5 (Blueprint)** | 10s idle             | Pulse next correct node           | Glow animation on target node  |

Auto-Assist preserves the illusion of skill and success. It lowers
difficulty to near-zero without breaking immersion via a hard skip
button.

---

## 4. System Architecture Overview

### 4.1 High-Level Pattern

We utilize a **Flow Coordinator** pattern to manage the linear narrative state.

- **App Wrapper:** `StarlightSyncApp` (SwiftUI)
- **State Manager:** `FlowCoordinator` (ObservableObject)
- **View Factory:** Switches between `SwiftUI` Views (Chapters 1, 3, 5, 6) and `SpriteKit` Scenes (Chapters 2, 4).

### 4.2 Component Boundaries

- **View Layer:** SwiftUI for static interactions, `SpriteView` for
  game loops. `SKScene` instances must be properly deallocated
  between chapters to prevent `SpriteView` memory leaks.
- **Audio Engine:** `AudioManager` singleton wrapping `AVAudioPlayer`
  for cross-fading and ducking. See §8 for lifecycle management.
- **Haptic Engine:** `HapticManager` singleton wrapping `CoreHaptics` for custom AHAP playback. See §8 for lifecycle management.

### 4.3 State Persistence

**Mechanism:** `UserDefaults`
**Key Schema:**

| Key                      | Type  | Description                                                                 |
| ------------------------ | ----- | --------------------------------------------------------------------------- |
| `highestUnlockedChapter` | `Int` | The highest chapter index the user has completed (0-indexed). Default: `0`. |

**Behavior:** On app launch, `FlowCoordinator` reads
`highestUnlockedChapter` and resumes from the **start** of that
chapter. Exact mid-chapter state (score, puzzle progress) is not
preserved — the user restarts the current chapter from the beginning.

**Rationale:** Chapter-level checkpoints prevent frustration from
interruptions (phone calls, low battery, accidental swipe-away)
without over-engineering exact state serialization for a 25-minute
linear experience.

### 4.4 Memory Strategy

**Approach:** Pre-load all assets at app launch.

All chapter assets (7 HEIC backgrounds, 4 sprite textures, 2 BGM
tracks, 5 SFX, 3 AHAP patterns) are loaded into memory during the
launch sequence. This guarantees zero-latency transitions between
chapters — critical for maintaining emotional flow. See §7.9 for the
full pre-load sequence and per-category memory breakdown.

**Estimated RAM footprint:** ~300MB. The target device (iPhone 17
Pro, 8GB+ RAM) makes this trivially safe with >5GB headroom. See
§7.9.3 for the detailed memory budget.

**Trade-off:** Higher launch time (~2-3s) in exchange for zero
inter-chapter loading. A launch splash screen (the OLED black +
pulsing fingerprint of Chapter 1) naturally masks this.

---

## 5. Technology Stack (Justified)

| **Layer**        | **Technology**      | **Justification**                                                                                             |
| ---------------- | ------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Language**     | **Swift 5.9+**      | Native performance, type safety, access to latest Apple APIs.                                                 |
| **UI Framework** | **SwiftUI**         | Best-in-class animation primitives (`matchedGeometryEffect`).                                                 |
| **Game Engine**  | **SpriteKit**       | Native 2D engine. Seamlessly integrates into SwiftUI via `SpriteView`.                                        |
| **Haptics**      | **CoreHaptics**     | Required for "Sharpness" and "Intensity" control. Standard `UINotificationFeedbackGenerator` is insufficient. |
| **Audio**        | **AVFoundation**    | Low-latency audio playback. Necessary for rhythm game sync.                                                   |
| **Telemetry**    | **Discord Webhook** | Simplest, zero-auth way to send a "Ping" to Dinesh's phone when she says Yes.                                 |
| **Persistence**  | **UserDefaults**    | Lightweight key-value store for chapter checkpoint. No relational data model needed.                          |

---

## 6. Alternatives Considered

### 6.1 Cross-Platform (Flutter / React Native) vs. Native iOS

| Criteria              | Flutter / React Native                                                               | Native iOS (SwiftUI + SpriteKit)                                      |
| --------------------- | ------------------------------------------------------------------------------------ | --------------------------------------------------------------------- |
| CoreHaptics access    | Requires platform channel / bridge. Limited control over sharpness/intensity curves. | First-class API access. Full AHAP pattern support.                    |
| SpriteKit integration | Not available. Would require a separate game engine (Flame, Unity embed).            | Native `SpriteView` composable directly in SwiftUI.                   |
| 120Hz ProMotion       | Achievable but requires manual frame scheduling.                                     | Automatic with SwiftUI/SpriteKit on ProMotion displays.               |
| Audio latency         | Higher due to bridge overhead. Rhythm game sync at ±150ms would be at risk.          | Native `AVAudioPlayer` with `prepareToPlay()` achieves <10ms latency. |
| Target audience       | One user, one device, one platform. Cross-platform adds complexity for zero benefit. | Perfect fit for single-platform, single-device deployment.            |

**Decision:** Native iOS. The haptic, audio, and game engine
requirements demand first-class Apple framework access.
Cross-platform adds bridging complexity with no audience benefit.

### 6.2 Unity / Godot vs. SpriteKit

| Criteria            | Unity / Godot                                                             | SpriteKit                                                   |
| ------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------- |
| SwiftUI integration | Requires embedding a Unity view controller. Complex lifecycle management. | `SpriteView` is a native SwiftUI view. Trivial integration. |
| Bundle size         | Unity runtime adds 30-80MB. Godot adds 20-40MB.                           | Zero overhead — SpriteKit is part of the OS.                |
| CoreHaptics access  | Requires native plugin.                                                   | Direct access from the same Swift codebase.                 |
| 2D game capability  | Massively overpowered for 2 simple 2D mini-games.                         | Purpose-built for 2D scenes. Right-sized for scope.         |
| Learning curve      | Separate editor, scripting language (C# / GDScript), build pipeline.      | Same Swift language, same Xcode project.                    |

**Decision:** SpriteKit. Two simple 2D mini-games (runner + rhythm
defense) do not justify a full game engine runtime. SpriteKit is
part of the OS, requires zero additional dependencies, and
integrates natively with SwiftUI.

---

## 7. Asset Pipeline & Media Dependencies

### 7.1 Asset Manifest

**Target bundle size:** 100–300MB
**Image format:** HEIC (Apple's native HEVC-based format — 50% smaller than PNG at equivalent quality, hardware-decoded via A19 Pro HEVC decoder)
**Sprite format:** PNG with alpha channel (required for SpriteKit texture atlas composition and transparency)
**Audio format:** AAC 256kbps `.m4a` (hardware-decoded via Apple AudioToolbox — zero CPU overhead)
**Haptic format:** AHAP (Apple Haptic Audio Pattern) JSON
**Font format:** System fonts (SF Pro Rounded, SF Mono); optional custom `.otf` for display headers

| Category           | Count     | Est. Total Size | Storage Location                       |
| ------------------ | --------- | --------------- | -------------------------------------- |
| Visual Backgrounds | 7         | ~25MB           | `Assets.xcassets/Backgrounds/`         |
| Sprite Sheets      | 4         | ~7MB            | `Assets.xcassets/Sprites.spriteatlas/` |
| Audio (BGM)        | 2         | ~20MB           | `Audio/`                               |
| Audio (SFX)        | 5         | ~4MB            | `Audio/SFX/`                           |
| Haptic Patterns    | 3         | <100KB          | `Haptics/`                             |
| Font Assets        | 0–1       | ~200KB          | `Fonts/` (if custom font adopted)      |
| App Icon           | 1         | ~1MB            | `Assets.xcassets/AppIcon.appiconset/`  |
| **Total**          | **22–23** | **~57MB**       | —                                      |

### 7.2 Visual Assets (GenAI Prompts)

**Target Style:** Pixar/Disney Animation Style, 3D Render, 8K Resolution, Cinematic Lighting, Wide Angle.
**Format:** HEIC, stored in Xcode Asset Catalog (`Assets.xcassets/Backgrounds/`) with `@2x` and `@3x` scale variants.
**Build-Time Processing:** `actool` (Xcode's Asset Catalog Compiler) compiles catalog entries into `.car` (compiled asset catalog) binary format during archive. HEIC assets are hardware-decoded at runtime via the A19 Pro's dedicated HEVC decoder — zero CPU cost for decompression.

| #   | Asset ID (Xcode)    | Chapter               | GenAI Prompt                                                                                                                                                                                                     | Est. Size |
| --- | ------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| 1   | `img_bg_intro`      | Ch. 1 (Handshake)     | "A pitch black background with a faint, glowing neon purple fingerprint scanner in the center. Minimalist, high tech, OLED deep blacks."                                                                         | ~2MB      |
| 2   | `img_bg_runner`     | Ch. 2 (Packet Run)    | "Cyberpunk neon grid floor stretching to an infinite horizon, deep purple and teal starfield sky, 80s synthwave aesthetic, wide angle, seamless texture."                                                        | ~4MB      |
| 3   | `img_bg_cipher`     | Ch. 3 (Cipher)        | "Extreme close-up of a high-tech bank vault door mechanism, brushed steel texture, glowing blue tumbler numbers, cinematic dramatic lighting, macro photography."                                                | ~4MB      |
| 4   | `img_bubble_shield` | Ch. 4 (Firewall)      | "Two cute otters (one slightly larger, one smaller) hugging tightly inside a glowing translucent energy sphere, floating in deep space. The sphere is protecting them from the void. Pixar style, emotional."    | ~4MB      |
| 5   | `img_bg_blueprint`  | Ch. 5 (Blueprint)     | "Architectural blueprint texture, deep royal blue paper with faint white chalk grid lines, technical aesthetic, clean and minimal."                                                                              | ~3MB      |
| 6   | `img_finale_art`    | Ch. 6 (Event Horizon) | "Two otters sitting on a futuristic balcony overlooking a utopia city at sunrise. They are holding hands and looking at the horizon. Golden hour lighting, romantic, hopeful, highly detailed fur and clothing." | ~4MB      |
| 7   | `app_icon`          | App Icon              | "A glowing neon pink heart inside a glass sphere, set against a deep purple space background. 3D render, glossy icon style."                                                                                     | ~1MB      |

**App Icon Delivery:** `app_icon` is placed in `Assets.xcassets/AppIcon.appiconset/` as a single 1024×1024 PNG source. Xcode auto-generates all required icon sizes (Home Screen, Spotlight, Settings, App Switcher, TestFlight listing) at build time.

**Runtime Loading:** All HEIC backgrounds are pre-loaded into `UIImage` instances during the launch sequence (§7.9). Each image is decoded from HEIC to BGRA bitmap on a background thread via `CGImageSource` to avoid main-thread stalls. Decoded images are retained in memory for the session duration to guarantee zero-latency chapter transitions.

**Component Dependencies:**

| Asset               | Consumed By          | Usage                                                                        |
| ------------------- | -------------------- | ---------------------------------------------------------------------------- |
| `img_bg_intro`      | `HandshakeView`      | Full-screen OLED background behind fingerprint glyph                         |
| `img_bg_runner`     | `PacketRunScene`     | Parallax scrolling background layer (tiled horizontally for infinite scroll) |
| `img_bg_cipher`     | `CipherView`         | Static background behind Cryptex wheel interface                             |
| `img_bubble_shield` | `FirewallScene`      | Center-screen shield sprite; anchor point for particle deflection            |
| `img_bg_blueprint`  | `BlueprintView`      | Full-screen background behind node layout                                    |
| `img_finale_art`    | `EventHorizonView`   | Revealed after slider completion; cross-fades from white void                |
| `app_icon`          | System (SpringBoard) | Home screen icon, App Switcher, TestFlight listing                           |

### 7.3 Sprite Assets

**Target Style:** Transparent PNGs matching the Pixar/Disney visual language defined in §7.2.
**Format:** PNG with alpha channel (transparency required for compositing over scene backgrounds).
**Storage:** `Assets.xcassets/Sprites.spriteatlas/` — Xcode's Sprite Atlas feature groups sprites into a single texture atlas at build time.
**Build-Time Processing:** `actool` packs all sprites in the `.spriteatlas` folder into optimized GPU texture sheets with power-of-2 dimensions, minimizing per-frame texture binding overhead. Alpha premultiplication is applied automatically.

| #   | Asset ID (Xcode)         | Chapter            | GenAI Prompt                                                                                                                                                                                         | Est. Size |
| --- | ------------------------ | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| 1   | `sprite_otter_player`    | Ch. 2 (Packet Run) | "Full body shot of a cute otter character named Dinn wearing futuristic goggles and a small backpack, riding a floating hoverboard. Side profile view, action pose, white background (for removal)." | ~3MB      |
| 2   | `sprite_obstacle_glitch` | Ch. 2 (Packet Run) | "A jagged, glitchy red digital barrier, pixelated and corrupted style, glowing red edges, white background."                                                                                         | ~2MB      |
| 3   | `sprite_heart_pickup`    | Ch. 2 (Packet Run) | "A floating 3D pixel heart, glowing pink, video game power-up style, white background."                                                                                                              | ~1MB      |
| 4   | `sprite_noise_particle`  | Ch. 4 (Firewall)   | "A spiky red geometric shape, aggressive looking, glowing, 3D render, white background."                                                                                                             | ~1MB      |

**Texture Atlas Performance:** Chapter 2 sprites (`sprite_otter_player`, `sprite_obstacle_glitch`, `sprite_heart_pickup`) are grouped into a single `SKTextureAtlas`, reducing per-frame GPU texture binding from 3 binds to 1 — critical for sustaining 120fps on the runner scene. Chapter 4's `sprite_noise_particle` shares an atlas group with `img_bubble_shield` for the same optimization.

**Runtime Loading:** All `SKTexture` instances are pre-loaded via `SKTextureAtlas.preload(completionHandler:)` during the launch sequence (§7.9). Pre-loaded textures are retained in the SpriteKit texture cache for the session duration.

**Component Dependencies:**

| Asset                    | Consumed By      | Usage                                                                         |
| ------------------------ | ---------------- | ----------------------------------------------------------------------------- |
| `sprite_otter_player`    | `PacketRunScene` | Player `SKSpriteNode`; carries `SKPhysicsBody` for collision                  |
| `sprite_obstacle_glitch` | `PacketRunScene` | Obstacle spawner pool; `SKPhysicsBody` for collision detection                |
| `sprite_heart_pickup`    | `PacketRunScene` | Collectible spawner; triggers score increment + `sfx_success_chime`           |
| `sprite_noise_particle`  | `FirewallScene`  | Enemy nodes spawned on beat map timestamps; `SKPhysicsBody` for tap detection |

### 7.4 Audio Assets

**Format:** AAC 256kbps (`.m4a`). Hardware-decoded via Apple's AudioToolbox framework — zero CPU overhead on playback.
**Storage:** Background music tracks in `Audio/` at the bundle root. Sound effects in `Audio/SFX/`.
**Build-Time Processing:** AAC files are copied to the app bundle without re-encoding (already in the target codec). Xcode's Copy Bundle Resources build phase handles placement.
**Audio Rights:** `audio_bgm_finale` is an original composition created for this project. `audio_bgm_main` is royalty-free or AI-generated (Suno/Udio). All SFX are original or royalty-free. No licensing encumbrances.

| #   | Asset ID (Xcode)    | Type             | Chapter(s)  | Description                                                                                   | Est. Size |
| --- | ------------------- | ---------------- | ----------- | --------------------------------------------------------------------------------------------- | --------- |
| 1   | `audio_bgm_main`    | Background Music | Ch. 1–5     | Lo-Fi / Synthwave loop. Continuous playback with cross-fade on chapter transitions.           | ~8MB      |
| 2   | `audio_bgm_finale`  | Background Music | Ch. 6       | "The Special Song." Triggered at the exact moment the slider reaches 100%.                    | ~12MB     |
| 3   | `sfx_haptic_thud`   | Sound Effect     | Ch. 1, 3    | Low-frequency bass-heavy thud. Paired with `CHHapticEvent` on capacitor snap and cipher lock. | <1MB      |
| 4   | `sfx_success_chime` | Sound Effect     | Ch. 2, 3, 5 | High-pitch sparkle chime. Heart pickup, puzzle solve, node connection.                        | <1MB      |
| 5   | `sfx_shield_impact` | Sound Effect     | Ch. 4       | Sci-fi deflect / shield hit. Triggered on successful noise tap in rhythm defense.             | <1MB      |
| 6   | `sfx_click`         | Sound Effect     | Ch. 3       | Cipher wheel scroll detent click. Paired with haptic click per wheel tick.                    | <1MB      |
| 7   | `sfx_error`         | Sound Effect     | Ch. 5       | Incorrect connection snap-back. Paired with error haptic on invalid node attempt.             | <1MB      |

**Runtime Loading:** All `AVAudioPlayer` instances are created and `prepareToPlay()` is called during the launch pre-load phase (§7.9, §8.4). For Chapter 4 rhythm sync, `audio_bgm_main` MUST be prepared before the scene transition begins to guarantee <10ms playback latency.

**Cross-Fade Strategy:** `AudioManager` maintains two `AVAudioPlayer` instances for BGM — one active, one standby. On chapter transitions, the standby player fades in over 500ms while the active player fades out over 500ms. SFX players operate independently and do not participate in cross-fade logic.

**Component Dependencies:**

| Asset               | Consumed By                               | Trigger                                                            |
| ------------------- | ----------------------------------------- | ------------------------------------------------------------------ |
| `audio_bgm_main`    | `AudioManager`                            | Starts on Ch. 1 completion; loops through Ch. 2–5                  |
| `audio_bgm_finale`  | `AudioManager`                            | Starts on Ch. 6 slider reaching 100%; plays once                   |
| `sfx_haptic_thud`   | `AudioManager` via `FlowCoordinator`      | Capacitor snap (Ch. 1), cipher segment lock (Ch. 3)                |
| `sfx_success_chime` | `AudioManager` via scene/view controllers | Heart collect (Ch. 2), segment solve (Ch. 3), node connect (Ch. 5) |
| `sfx_shield_impact` | `AudioManager` via `FirewallScene`        | Successful noise tap within hit window (Ch. 4)                     |
| `sfx_click`         | `AudioManager` via `CipherWheelView`      | Per-tick wheel scroll (Ch. 3)                                      |
| `sfx_error`         | `AudioManager` via `BlueprintView`        | Invalid node connection attempt (Ch. 5)                            |

### 7.5 Beat Map Asset (Chapter 4)

The rhythm game uses a **pre-authored beat map** — a manually defined array of timestamps synced to `audio_bgm_main`. Stored as a Swift array of `TimeInterval` values in `GameConstants`.

```swift
static let beatMap: [TimeInterval] = [0.5, 1.0, 1.5, 2.0, 2.5, ...]
```

**Authoring:** Each timestamp is manually identified by listening to the track and marking percussive hits. Budget 1–2 hours for this task (§16.2). Timestamps MUST be monotonically increasing and fall within the track duration.

**Runtime Sync:** Beat synchronization MUST use `CACurrentMediaTime()` for timing — **NOT** `Timer`, `DispatchQueue.asyncAfter`, or `Task.sleep`, which are subject to scheduling jitter.

**Component Dependencies:** `FirewallScene` consumes the beat map array to schedule `sprite_noise_particle` spawn events synchronized with `audio_bgm_main` playback.

### 7.6 Haptic Pattern Assets

**Format:** AHAP (Apple Haptic Audio Pattern) JSON files.
**Storage:** `Haptics/` directory at the bundle root.
**Build-Time Processing:** Copied to the bundle as-is via Xcode's Copy Bundle Resources phase. AHAP is a JSON-based format parsed at runtime by CoreHaptics.
**Runtime Loading:** AHAP files are parsed into `CHHapticPattern` instances during the launch pre-load phase (§7.9). Patterns are cached in `HapticManager` and replayed via `CHHapticPatternPlayer` instances on demand. See §8.3 for engine lifecycle and crash recovery.

| #   | Asset ID                | Description                                           | Chapter Usage                                       |
| --- | ----------------------- | ----------------------------------------------------- | --------------------------------------------------- |
| 1   | `heartbeat.ahap`        | Pulsing heartbeat with rising intensity and sharpness | Ch. 1 (capacitor charge), Ch. 6 (slider resistance) |
| 2   | `capacitor_charge.ahap` | Continuous intensity ramp with sharp snap event       | Ch. 1 (long-press feedback culminating in "snap")   |
| 3   | `thud.ahap`             | Single heavy transient event                          | Ch. 3 (correct cipher segment lock confirmation)    |

**Graceful Degradation:** If `CHHapticEngine` fails to start or stalls during playback, `HapticManager` silently degrades. Visual feedback (animations, color changes) and audio feedback (`sfx_haptic_thud`, `sfx_click`) provide full redundancy. See §8.3 and §12.3.

### 7.7 Font Assets

**Primary Font:** **SF Pro Rounded** — Apple system font. No asset required; accessed via `Font.system(design: .rounded)` in SwiftUI.
**Monospace Font:** **SF Mono** — Apple system font. No asset required; accessed via `Font.system(.body, design: .monospaced)` in SwiftUI.
**Display Header Font (Optional):** **Clash Display** or **Monument Extended** — custom `.otf` font for cyberpunk/sci-fi header styling.

**Custom Font Integration (if adopted):**

| Property       | Value                                                                          |
| -------------- | ------------------------------------------------------------------------------ |
| Format         | `.otf` (OpenType)                                                              |
| Storage        | `Fonts/` bundle directory                                                      |
| Registration   | `Info.plist` → `UIAppFonts` ("Fonts provided by application") array            |
| Runtime Access | `Font.custom("ClashDisplay-Bold", size: 24)` in SwiftUI                        |
| Fallback       | System `SF Pro Rounded` via `.font(.system(design: .rounded))` on load failure |
| Size Impact    | ~200KB per weight variant                                                      |

**Component Dependencies:**

| Font                                         | Used In                         | Purpose                                                                  |
| -------------------------------------------- | ------------------------------- | ------------------------------------------------------------------------ |
| SF Pro Rounded                               | All chapter views, overlays     | Body text, labels, buttons — primary UI typeface                         |
| SF Mono                                      | `CipherView`, `CipherWheelView` | Cipher puzzle text; monospaced alignment for scroll wheel segments       |
| Clash Display / Monument Extended (optional) | Chapter title cards, Ch. 6 text | Distinctive sci-fi header styling for "Will you be mine forever?" prompt |

### 7.8 Configuration Secrets

Configuration secrets are runtime constants that MUST NOT appear as plaintext string literals in source code or the compiled binary. Full security model in §9.

| Secret                | Purpose                                             | Storage Location       | Status        |
| --------------------- | --------------------------------------------------- | ---------------------- | ------------- |
| `DISCORD_WEBHOOK_URL` | Discord channel webhook for Ch. 6 completion signal | `WebhookService.swift` | Active        |
| `ENCRYPTION_KEY`      | Reserved for future `UserDefaults` value encryption | `SecretStore.swift`    | Reserved (v2) |

**Storage Pattern:** Both secrets use XOR-encoded `[UInt8]` byte arrays with a compile-time XOR key. See §9.2 for the encoding approach, §9.4 for source control exclusion, and §9.5 for rotation strategy.

**Runtime Access:** Secrets are decoded in-memory at the call site via XOR key. The decoded `String` is never persisted to disk, logged, or retained beyond the immediate use scope.

### 7.9 Asset Pipeline & Runtime Loading

#### 7.9.1 Build-Time Processing

| Asset Type       | Build Tool                                 | Process                                                                 | Output                          |
| ---------------- | ------------------------------------------ | ----------------------------------------------------------------------- | ------------------------------- |
| HEIC Backgrounds | `actool` (Asset Catalog Compiler)          | Compiled into `.car` binary; device-appropriate scale variants selected | `Assets.car` in app bundle      |
| PNG Sprites      | `actool` + Sprite Atlas                    | Packed into texture atlas sheets; GPU-optimal power-of-2 dimensions     | `Sprites.atlasc/` in app bundle |
| App Icon         | `actool`                                   | Auto-generates all required icon sizes from 1024×1024 source            | `AppIcon` set in `Assets.car`   |
| AAC Audio        | Xcode Copy Bundle Resources                | Copied without re-encoding; AAC is already hardware-optimized           | `Audio/` directory in bundle    |
| AHAP Patterns    | Xcode Copy Bundle Resources                | Copied as-is; JSON parsed at runtime by CoreHaptics                     | `Haptics/` directory in bundle  |
| Custom Fonts     | Xcode Copy Bundle Resources + `Info.plist` | Copied to bundle; registered via `UIAppFonts` plist key                 | `Fonts/` directory in bundle    |

#### 7.9.2 Launch Pre-Load Sequence

All assets are pre-loaded during the launch sequence behind the Chapter 1 OLED black screen. Loading order is optimized for dependency priority:

```txt
1. AVAudioSession.configure(.playback)           // ~10ms
2. CHHapticEngine.start()                         // ~50ms
3. AHAP patterns → CHHapticPattern cache          // ~20ms
4. Audio: prepareToPlay() for all AVAudioPlayers  // ~200ms
5. HEIC backgrounds → UIImage decode (bg threads) // ~500ms
6. SKTextureAtlas.preload() for sprite atlases    // ~300ms
7. Custom font registration verification          // ~10ms
                                           Total: ~1.1s
```

Chapter 1's 3-second long-press interaction naturally masks the entire pre-load phase. By the time the user completes the Handshake, all assets are decoded and resident in memory.

#### 7.9.3 Memory Budget

| Asset Category       | Decoded Memory Footprint | Notes                                                       |
| -------------------- | ------------------------ | ----------------------------------------------------------- |
| HEIC Backgrounds (7) | ~180MB                   | 4K images decoded to BGRA bitmap; largest allocation        |
| Sprite Textures (4)  | ~40MB                    | PNG decoded to GPU texture; atlas packing reduces overhead  |
| Audio Buffers (7)    | ~24MB                    | AAC decoded to PCM on `prepareToPlay()`                     |
| AHAP Patterns (3)    | <1MB                     | Lightweight JSON-derived structs                            |
| Font Glyphs          | <5MB                     | System fonts cached by CoreText; custom font adds ~1MB      |
| **Total**            | **~250MB**               | Within ~300MB budget; 5GB+ headroom on target device (§4.4) |

#### 7.9.4 Asset Lifecycle

Assets are loaded once at launch and released only on app termination. No per-chapter loading or unloading occurs. This is a deliberate trade-off: higher baseline memory in exchange for guaranteed zero-latency chapter transitions and uninterrupted emotional flow.

The sole exception is `SKScene` instances — scene nodes and action sequences are torn down on chapter transitions (§11.5) while the underlying `SKTexture` atlas data remains in the GPU texture cache.

#### 7.9.5 Caching Strategy

- **Image Cache:** `UIImage` instances are held as strong references in the pre-load coordinator. No eviction. The ~250MB footprint is well within device headroom.
- **Texture Cache:** SpriteKit's internal `SKTextureAtlas` cache retains GPU-uploaded textures. No manual cache management required.
- **Audio Cache:** `AVAudioPlayer` instances with `prepareToPlay()` keep decoded PCM buffers in memory. No re-decoding between chapters.
- **Haptic Cache:** `CHHapticPattern` objects are lightweight and retained in `HapticManager` for the session.
- **No CDN, no remote assets, no on-demand resources.** All assets are bundled. The app is fully offline-capable.

---

## 8. Audio & Haptic Engine Lifecycle

### 8.1 AVAudioSession Configuration

- **Category:** `.playback` — ensures audio plays even when the Silent Switch (mute) is on. This is critical for the experience.
- **Mode:** `.default`
- **Options:** No `.mixWithOthers` — the app's audio should be the sole audio output.

### 8.2 Interruption Handling

The `AudioManager` registers for `AVAudioSession.interruptionNotification`:

- **`.began`:** Pause `FlowCoordinator` state (freeze game loop /
  timer). Pause all `AVAudioPlayer` instances. Pause
  `CHHapticEngine`.
- **`.ended` with `.shouldResume`:** Resume audio playback. Resume
  haptic engine. Resume `FlowCoordinator`. Display a brief
  "Welcome Back" overlay before unpausing gameplay.

### 8.3 CoreHaptics Engine Recovery

`CHHapticEngine` has documented stall behavior. The `HapticManager` implements:

- **`stoppedHandler`:** Called when the engine stops unexpectedly.
  Logs the reason and attempts to restart the engine via
  `engine.start()`.
- **`resetHandler`:** Called when the engine resets. Re-registers all
  AHAP patterns (§7.6) and restarts the engine.

If the haptic engine cannot be recovered, the app continues without
haptics — visual and audio feedback remain functional (multi-sensory
redundancy). See §7.6 for pattern assets and §12.3 for redundancy model.

### 8.4 Audio Preloading

`AVAudioPlayer.prepareToPlay()` is called for all audio assets (§7.4)
during the launch pre-load phase (§7.9.2). For Chapter 4 (rhythm game),
the `audio_bgm_main` track **must** be prepared before the scene
transition begins to guarantee <10ms playback latency.

---

## 9. Security Model

### 9.1 Threat Model

This is a single-user app distributed via TestFlight to one known device. The threat surface is minimal:

- **Primary risk:** Discord webhook URL extraction from the compiled binary via `strings` or binary analysis.
- **Impact if exploited:** An attacker could spam the Discord channel with webhook messages.
- **Likelihood:** Extremely low — the IPA is only accessible to the TestFlight user.

### 9.2 Secret Storage

All configuration secrets (§7.8) are stored as **XOR-encoded byte arrays** in the binary. At runtime, secrets are decoded in-memory before use.

```swift
private let obfuscatedURL: [UInt8] = [0xAB, 0xCD, ...] // XOR-encoded bytes
private let xorKey: UInt8 = 0x5A

func webhookURL() -> String {
    String(bytes: obfuscatedURL.map { $0 ^ xorKey }, encoding: .utf8)!
}
```

**Acknowledged limitation:** XOR obfuscation is trivially reversible
by a motivated attacker. This is accepted given the single-user
threat model and zero-backend constraint.

**Applicable Secrets:**

| Secret                | Location               | XOR Key Storage         | Notes                                         |
| --------------------- | ---------------------- | ----------------------- | --------------------------------------------- |
| `DISCORD_WEBHOOK_URL` | `WebhookService.swift` | Inline `UInt8` constant | Active; decoded at Ch. 6 webhook fire         |
| `ENCRYPTION_KEY`      | `SecretStore.swift`    | Inline `UInt8` constant | Reserved for v2; not decoded in current build |

### 9.3 Webhook Contract

- **Endpoint:** Discord Webhook URL (XOR-obfuscated in binary)
- **Method:** `POST`
- **Headers:** `Content-Type: application/json`
- **Payload:**

```json
{
  "content": "@everyone SHE SAID YES! ❤️"
}
```

- **Retry Policy:** 3 attempts with exponential backoff (1s, 2s, 4s). Fire-and-forget — the UI never waits for a response.
- **Failure behavior:** If all 3 attempts fail (no internet, Discord
  outage, rate limit), the failure is silently discarded. The finale
  animation, music, and confetti play regardless.

### 9.4 Source Control Exclusion

Secrets MUST be excluded from source control in all forms except XOR-encoded byte arrays.

- **`.gitignore` rules:** `Secrets.plaintext`, `*.secret`, and `*.env` patterns are included to prevent accidental commit of raw secret files.
- **Pre-commit validation:** Before every commit (see `CLAUDE.md` §9.5), verify no plaintext URL patterns matching `https://discord.com/api/webhooks/` exist in staged files.
- **Prohibited operations:** Raw webhook URLs MUST NOT appear in code comments, documentation, test fixtures, log output, or `Info.plist` values. See `CLAUDE.md` §5 for the full prohibition list.

### 9.5 Secret Rotation Strategy

- **`DISCORD_WEBHOOK_URL` rotation:** Generate a new webhook URL in Discord Server Settings → Integrations. XOR-encode the new URL bytes with the existing (or new) XOR key. Replace the `[UInt8]` array in `WebhookService.swift`. Archive and distribute a new TestFlight build.
- **`ENCRYPTION_KEY` rotation:** Not applicable in v1.0. The key is reserved and unused. If activated in v2, rotation requires re-encrypting any persisted `UserDefaults` values with the new key before replacing the encoded key in `SecretStore.swift`.
- **Key compromise response:** If either secret is suspected compromised, invalidate the Discord webhook immediately via Discord admin panel (webhook deletion) and rotate to a new URL. The `ENCRYPTION_KEY` carries no external risk since it protects only local-device `UserDefaults` data.

---

## 10. Device Compatibility & Distribution

### 10.1 Target Device

| Spec            | Value                              |
| --------------- | ---------------------------------- |
| **Device**      | iPhone 17 Pro                      |
| **Chip**        | A19 Pro                            |
| **Display**     | 120Hz ProMotion (adaptive refresh) |
| **RAM**         | 8GB+                               |
| **CoreHaptics** | Full Taptic Engine support         |
| **Minimum iOS** | iOS 19+                            |

### 10.2 Display Considerations

- The "120Hz fluidity" claim is validated — iPhone 17 Pro supports ProMotion.
- SwiftUI animations and SpriteKit scenes automatically render at 120fps on ProMotion displays.
- All UI is designed for iPhone portrait mode only. No landscape support. No iPad layout.

### 10.3 Distribution: TestFlight

**Prerequisites:**

- Active Apple Developer Program enrollment ($99/year).
- App created in App Store Connect.
- Xcode project configured with signing certificates and provisioning profile.
- Carolina's email registered as an external tester (or internal tester if on the same team).

**Pipeline:**

1. Archive the build in Xcode.
2. Upload to App Store Connect via Xcode Organizer or `xcodebuild`.
3. Wait for TestFlight processing (~10-30 min).
4. Send TestFlight invitation to Carolina's email.
5. Carolina installs via TestFlight app on her iPhone 17 Pro.

---

## 11. Failure Handling & Resilience

### 11.1 Crash on Launch

Wrap the main `FlowCoordinator` initialization in a do-catch block.
On failure, reset `UserDefaults` state
(`highestUnlockedChapter = 0`) and attempt a clean restart.

### 11.2 Audio Session Interruption (Phone Call / Siri)

See §8.2. Game state pauses on interruption, resumes when the system signals `.shouldResume`.

### 11.3 CoreHaptics Engine Stall

See §8.3. Engine is restarted via `stoppedHandler` /
`resetHandler`. If unrecoverable, the app degrades gracefully —
visual and audio cues provide redundant feedback.

### 11.4 Webhook Failure

See §9.3. 3x retry with exponential backoff. Silent discard on total failure. UI is never blocked.

### 11.5 SpriteView Memory Leaks

`SpriteView` in SwiftUI has known memory leak issues when scenes are not properly deallocated. On chapter transition:

1. Call `scene.removeAllChildren()` and `scene.removeAllActions()`.
2. Set the `SKScene` reference to `nil`.
3. Allow `SpriteView` to be removed from the SwiftUI view hierarchy before the next chapter's view is rendered.

Underlying `SKTexture` atlas data is NOT released during scene teardown — it remains in the GPU texture cache per §7.9.4.

### 11.6 Low Memory Warning

If `UIApplication.didReceiveMemoryWarningNotification` fires, the
app does not attempt to unload assets (pre-load-all strategy per
§7.9.4). On iPhone 17 Pro with 8GB+ RAM and ~250MB app footprint
(§7.9.3), this scenario is not expected. If it occurs, the OS will
terminate background apps first.

---

## 12. Accessibility

### 12.1 Scope

Full VoiceOver and Dynamic Type support are **non-goals** for this
single-user app. Basic accessibility considerations are implemented
as follows:

### 12.2 Reduce Motion

The app checks `UIAccessibility.isReduceMotionEnabled`. If enabled:

- Particle effects are reduced (fewer particles, slower movement).
- Transition animations between chapters use cross-fades instead of `matchedGeometryEffect` spatial transitions.
- The CRT turn-on effect in Chapter 1 is replaced with a simple fade-in.

### 12.3 Multi-Sensory Redundancy

All feedback is delivered through **three channels simultaneously** where applicable:

- **Visual:** On-screen animation or color change.
- **Audio:** Sound effect (§7.4).
- **Haptic:** CoreHaptics pattern (§7.6).

This ensures the experience is not degraded if the user has the mute
switch on (mitigated by `.playback` category), if haptics are
disabled in system settings, or if the user is in a loud
environment.

---

## 13. Testing Strategy

### 13.1 Unit Tests (XCTest)

| Component           | Test Coverage                                                                                  |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| `FlowCoordinator`   | State transitions: chapter progression, checkpoint save/load, Auto-Assist trigger logic.       |
| Cipher validation   | Correct segment matching, incorrect attempt counting, Auto-Assist activation after 3 failures. |
| Webhook retry logic | 3x retry with exponential backoff, silent discard on total failure, non-blocking behavior.     |
| Beat map timing     | Beat timestamps are monotonically increasing, within track duration, properly spaced.          |

### 13.2 Manual Playtest (On-Device)

Performed on the actual target device (iPhone 17 Pro). The simulator **does not support CoreHaptics**.

| Test Case                                                    | Validation Method                                      |
| ------------------------------------------------------------ | ------------------------------------------------------ |
| Haptic patterns feel correct per chapter                     | Subjective on-device evaluation                        |
| Audio-haptic sync in Chapter 4                               | Subjective; beat map hit windows verified by feel      |
| "The Special Song" plays at exact moment slider reaches 100% | Visual + audio timing check                            |
| Chapter transitions are seamless (no loading flicker)        | Visual check at 120fps                                 |
| Auto-Assist activates correctly per chapter                  | Intentional failure testing                            |
| App survives phone call interruption mid-chapter             | Call self during playtest, verify pause/resume         |
| App resumes from checkpoint after force-quit                 | Kill app mid-chapter, relaunch, verify chapter restart |
| Webhook fires successfully                                   | Check Discord channel after Chapter 6 completion       |
| Progressive slider resistance feels immersive                | Subjective UX evaluation                               |

### 13.3 QA Time Budget

The original 1-hour allocation (Phase 4) is for the **final
validation pass** only. Testing occurs continuously throughout
development:

- Unit tests run on every build.
- On-device playtesting occurs at the end of each sprint (Phase 2A, 2B, 2C).
- The final 1-hour pass is a full end-to-end playthrough on the target device.

---

## 14. Observability

### 14.1 Crash Reporting

**TestFlight crash logs** via App Store Connect. No additional crash reporting SDK (e.g., Firebase Crashlytics) is integrated.

**Rationale:** Single-user app. If a crash occurs, Carolina will
report it directly. TestFlight provides symbolicated crash logs
accessible in App Store Connect for debugging.

### 14.2 Webhook as Telemetry

The Discord webhook serves as the sole "alive" signal. If the
webhook message appears in the Discord channel, the app was
successfully completed end-to-end. No intermediate telemetry is
collected.

---

## 15. Implementation Roadmap

### Phase 1: The Skeleton (Hours 0-2)

- Setup Xcode Project (signing, provisioning, Asset Catalog, Sprite Atlas groups).
- Implement `FlowCoordinator` (state machine with chapter enum, `UserDefaults` checkpoint).
- Implement `HapticManager` (singleton, `CHHapticEngine` lifecycle, `stoppedHandler`/`resetHandler`).
- Implement `AudioManager` (singleton, `AVAudioSession.Category.playback`, interruption observer).
- Implement asset pre-load pipeline (§7.9.2): image decode, texture atlas preload, audio prepare, AHAP parse.
- Register custom font in `Info.plist` (if adopted per §7.7).

### Phase 2: The Games (Hours 2-10)

- **Sprint A:** Chapter 2 (Runner). `SKScene`, physics bodies,
  jump/glide logic, obstacle spawning, Auto-Assist
  (3 deaths → speed -20%, gaps +20%).
- **Sprint B:** Chapter 4 (Rhythm Defense). Tap detection,
  pre-authored beat map, hit window ±150ms, Auto-Assist
  (5 misses → ±300ms).
- **Sprint C:** Chapter 3 (Cipher). 3-segment Cryptex wheels,
  scroll haptics, Auto-Assist (3 fails → highlight). Chapter 5
  (Blueprint). 12-node heart layout, sequential connection,
  snap-back on error, Auto-Assist (10s idle → pulse).

### Phase 3: The Polish (Hours 10-15)

- Integrate Audio (background loops + SFX + cross-fading between chapters).
- Add `matchedGeometryEffect` transitions between chapters (with `Reduce Motion` fallback).
- Implement Chapter 6 progressive-resistance slider (`drag ^ 0.8` logarithmic decay).
- Implement the "Forever" Webhook (XOR-decoded URL, POST, 3x retry, fire-and-forget).
- Implement Chapter 1 CRT turn-on effect.
- Integrate confetti particle system for Chapter 6 finale.

### Phase 4: Quality Assurance (Hours 15-18)

- Run XCTest unit test suite (FlowCoordinator, Cipher, Webhook, Beat Map).
- Full end-to-end playtest on iPhone 17 Pro.
- **Critical Check:** Ensure "The Special Song" plays at the exact moment the slider completes.
- Test interruption handling (phone call mid-chapter, force-quit and relaunch).
- Test webhook delivery to Discord.
- Test Auto-Assist activation in all 4 chapters via intentional failure.

### Phase 5: Distribution (Hours 18-19)

- Archive build in Xcode.
- Upload to App Store Connect.
- Send TestFlight invitation to Carolina.
- Verify TestFlight install on target device (if accessible).

---

## 16. Open Questions & Risks

### 16.1 Resolved Risks

| Risk                              | Mitigation                                                                                                                                         | Status        |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| Audio Sync Latency in Ch. 4       | Pre-authored beat map + `AVAudioPlayer.prepareToPlay()` + generous hit window (±150ms, ±300ms with assist). Use `CACurrentMediaTime()` for timing. | **Mitigated** |
| Crash on Launch                   | `FlowCoordinator` init wrapped in do-catch. Reset `UserDefaults` on failure.                                                                       | **Mitigated** |
| User gets stuck on a chapter      | Per-chapter Auto-Assist system reduces difficulty to near-zero. See §3.8.                                                                          | **Mitigated** |
| Webhook fails (no internet)       | 3x retry, fire-and-forget. Finale plays regardless.                                                                                                | **Mitigated** |
| Audio stops during phone call     | `AVAudioSession` interruption observer pauses/resumes game state.                                                                                  | **Mitigated** |
| Haptic engine stalls              | `CHHapticEngine.stoppedHandler` + `resetHandler` restart the engine. Graceful degradation if unrecoverable.                                        | **Mitigated** |
| Webhook URL extracted from binary | XOR obfuscation. Risk accepted given single-user threat model.                                                                                     | **Accepted**  |
| SpriteView memory leaks           | Explicit scene cleanup on chapter transitions.                                                                                                     | **Mitigated** |

### 16.2 Open Risks

| Risk                                       | Severity | Notes                                                                                                  |
| ------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------ |
| Beat map authoring time                    | Medium   | Requires manual timestamping of every beat in the Ch. 4 track. Budget 1-2 hours for this task alone.   |
| Progressive slider resistance tuning       | Medium   | The `x^0.8` exponent may need adjustment during playtesting to feel "right."                           |
| Total implementation time exceeds estimate | Medium   | 19-hour roadmap is aggressive. Realistic estimate: 24-30 hours with asset generation and tuning.       |
| GenAI asset quality inconsistency          | Low      | Generated images may require multiple iterations to achieve consistent art style across all 11 assets. |
| Custom font licensing                      | Low      | If Clash Display or Monument Extended is adopted, verify license permits TestFlight distribution.      |

---
