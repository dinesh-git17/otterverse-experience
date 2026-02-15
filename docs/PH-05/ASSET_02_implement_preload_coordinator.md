# Epic: ASSET_02 — Implement Asset Pre-load Coordinator

## Metadata

| Field         | Value                            |
| ------------- | -------------------------------- |
| **Epic ID**   | ASSET_02                         |
| **Epic Name** | implement_preload_coordinator    |
| **Phase**     | PH-05                            |
| **Domain**    | ASSET                            |
| **Owner**     | iOS Engineer                     |
| **Status**    | Draft                            |

---

## Problem Statement

ASSET_01 populates the Xcode asset catalog with production-ready HEIC backgrounds and PNG sprites, but the asset catalog is a build-time construct — images are compiled into `.car` and `.atlasc` binary formats. At runtime, accessing these assets via `UIImage(named:)` or `SKTextureAtlas(named:)` triggers lazy decoding: the compressed data is read from disk and the bitmap is decompressed to BGRA only when first drawn. This lazy decoding blocks the main thread for 50-150ms per HEIC image, causing visible frame drops during chapter transitions and violating the Design Doc §4.4 zero-latency guarantee ("All chapter assets are loaded into memory during the launch sequence. This guarantees zero-latency transitions between chapters").

Without a centralized pre-load coordinator, each chapter would independently trigger image decoding on first render, producing unpredictable stalls. The 7 audio players require `prepareToPlay()` to buffer PCM data (Design Doc §8.4). The 3 AHAP patterns require parsing into `CHHapticPattern` instances (Design Doc §7.6). The sprite atlas requires GPU texture upload via `SKTextureAtlas.preload()` (Design Doc §7.3). These operations must execute during the launch sequence (Design Doc §7.9.2), coordinated behind Chapter 1's 3-second long-press interaction window that naturally masks load time (Design Doc §4.4).

The Design Doc §7.9.5 explicitly defines "the pre-load coordinator" as the component responsible for holding strong references to decoded assets for the session duration: "UIImage instances are held as strong references in the pre-load coordinator. No eviction." This epic delivers that coordinator as a new `@Observable` `@MainActor` singleton that orchestrates the full §7.9.2 launch pre-load sequence and retains all decoded assets in memory until app termination.

---

## Goals

- Deliver `AssetPreloadCoordinator` as a production-ready `@Observable` `@MainActor` singleton at `Coordinators/AssetPreloadCoordinator.swift`.
- Decode all 5 HEIC background images to `UIImage` on background threads to avoid main-thread stalls, storing decoded instances as strong session-lifetime references per Design Doc §7.9.5.
- Pre-load the `Sprites` texture atlas via `SKTextureAtlas.preload(completionHandler:)`, ensuring all sprite textures are uploaded to the GPU texture cache before any SpriteKit scene renders.
- Orchestrate `AudioManager.shared.preloadAssets()` and `HapticManager.shared.preloadPatterns()` as part of the unified launch pre-load sequence per Design Doc §7.9.2.
- Verify custom font registration status (if a custom display font is adopted per Design Doc §7.7), falling back to SF Pro Rounded on failure.
- Integrate with the app launch sequence such that all assets are decoded and resident in memory before Chapter 1's long-press interaction completes (~3 seconds).
- Expose observable `preloadComplete: Bool` state to allow the app entry point or Chapter 1 view to gate chapter transitions on preload completion.
- Ensure total decoded memory footprint remains within the ~300MB budget per Design Doc §7.9.3.

## Non-Goals

- **No asset file integration.** Placing image files into the asset catalog is ASSET_01 scope. This epic consumes assets already present in the catalog.
- **No audio file sourcing or creation.** Audio assets (BGM, SFX) are not yet available per ASSET_INT_PLAN §2.1. `AudioManager.preloadAssets()` is called but operates on whatever audio files are present in the bundle. The coordinator handles empty audio gracefully.
- **No AHAP file authoring.** Haptic pattern files are authored by the project owner. `HapticManager.preloadPatterns()` is called but operates on whatever AHAP files are present in the bundle. The coordinator handles missing patterns gracefully.
- **No chapter view modifications.** Chapter views consume pre-decoded assets via standard SwiftUI `Image("name")` or SpriteKit `SKTextureAtlas(named:)` APIs. The coordinator ensures assets are decoded before chapters render but does not expose per-asset accessors to views.
- **No asset eviction or LRU cache management.** Design Doc §7.9.4 mandates no per-chapter loading or unloading: "Assets are loaded once at launch and released only on app termination."
- **No CDN, remote assets, or on-demand resources.** Design Doc §7.9.5: "No CDN, no remote assets, no on-demand resources. All assets are bundled."
- **No unit tests.** Formal test suite is PH-15 scope. The coordinator's design allows testability via injectable asset resolution, but test implementation is deferred.
- **No GameConstants integration.** Asset identifiers are defined as private named constants in this epic. PH-06 will extract them to `GameConstants` type-safe enums; the coordinator will be updated to reference those enums at that time.

---

## Technical Approach

`AssetPreloadCoordinator` is implemented as a `@MainActor` `@Observable` `final class` with a `static let shared` singleton accessor and `private init()`, following the same pattern as `AudioManager` and `HapticManager`. The singleton is retained by its static property for the entire process lifetime, ensuring decoded asset references are never released.

**Session-lifetime storage:** The coordinator maintains two private storage properties: (1) `var decodedBackgrounds: [String: UIImage]` — a dictionary mapping asset identifiers to pre-decoded `UIImage` instances for the 5 HEIC backgrounds, and (2) `var spriteAtlas: SKTextureAtlas?` — a strong reference to the preloaded sprite atlas. These properties are populated during the preload sequence and never mutated afterward.

**Background image decoding:** Each HEIC background is loaded from the asset catalog via `UIImage(named:)` and then force-decoded to a BGRA bitmap via `UIImage.byPreparingForDisplay()`. This async method performs decompression on a system-managed background thread, returning the prepared image to the caller. The coordinator uses `async let` parallelism to decode multiple backgrounds concurrently, minimizing total decode time. The decoded images are stored as strong references in the `decodedBackgrounds` dictionary. SwiftUI chapter views benefit from this pre-decode because the underlying `CGImage` data is shared via iOS's system image cache — `Image("img_bg_intro")` renders instantly because the bitmap is already resident.

**Sprite atlas preloading:** `SKTextureAtlas(named: "Sprites").preload(completionHandler:)` is a callback-based API. The coordinator wraps it in a `withCheckedContinuation` bridge to integrate with `async/await`. After preloading, the atlas reference is stored as a strong property to prevent the GPU texture cache from evicting the texture sheets. SpriteKit scenes access textures via `SKTextureAtlas(named:).textureNamed()` as normal — the preload ensures the GPU upload has already occurred.

**Manager orchestration:** The coordinator calls `HapticManager.shared.preloadPatterns()` and `AudioManager.shared.preloadAssets()` as synchronous operations within the preload sequence. Both methods are idempotent — repeated calls skip already-cached assets. `AVAudioSession` configuration and `CHHapticEngine` startup are handled by the respective manager initializers (first access to `.shared` triggers `init()`), consistent with the Design Doc §7.9.2 ordering.

**Font verification:** The coordinator checks custom font availability via `UIFont(name:size:)`. If the custom font is not registered (expected until a custom font is adopted per Design Doc §7.7), the check completes silently. The coordinator logs registration status under `#if DEBUG` but does not fail or block preloading.

**Launch integration:** `StarlightSyncApp` or the initial view triggers `AssetPreloadCoordinator.shared.preloadAllAssets()` as an async task during app launch. The preload executes concurrently with Chapter 1's OLED black screen and fingerprint glyph render. The coordinator's observable `preloadComplete` property transitions to `true` when all assets are decoded. Chapter 1's completion-to-Chapter-2 transition can observe this property to ensure preloading is finished before advancing.

**Failure isolation:** All preload operations use `do/catch` with `#if DEBUG` logging. Individual asset decode failures are logged and skipped — a single corrupt image does not abort the preload sequence. If `SKTextureAtlas.preload()` fails, the atlas is still usable via on-demand loading (degraded but functional). Audio and haptic preload failures are handled by their respective managers. The coordinator's `preloadComplete` transitions to `true` regardless of individual failures to avoid blocking the user experience.

**Concurrency model:** `async/await` with `async let` for parallel image decoding. No `DispatchQueue`, `Timer`, GCD, or Combine per CLAUDE.md §4.1. `@MainActor` isolation ensures observable state mutations occur on the main actor. Image decoding via `byPreparingForDisplay()` is inherently background-threaded by the system.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| `AudioManager` singleton with `preloadAssets()` API | AUDIO_01 (PH-03) | Complete | iOS Engineer |
| `HapticManager` singleton with `preloadPatterns()` API | HAPTIC_01 (PH-04) | Complete | iOS Engineer |
| Visual assets integrated into asset catalog | ASSET_01 (PH-05) | Draft | iOS Engineer |
| `Coordinators/` directory in project structure | INFRA_01 (PH-01) | Complete | iOS Engineer |
| Walking skeleton with chapter routing | COORD_02 (PH-02) | Complete | iOS Architect |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| Pre-decoded background images resident in memory | PH-07 through PH-13 | Chapter views render backgrounds with zero decode latency |
| Pre-loaded sprite atlas with GPU texture cache populated | PH-08 (PacketRunScene), PH-10 (FirewallScene) | SpriteKit scenes access textures with zero GPU upload latency |
| `preloadComplete` observable state | PH-07 | Chapter 1 can gate transition to Chapter 2 on preload completion |
| Audio players prepared with `prepareToPlay()` | PH-07 through PH-13 | BGM and SFX playback starts with <10ms latency |
| AHAP patterns cached in HapticManager | PH-07, PH-09, PH-13 | Haptic playback fires immediately without AHAP re-parsing |
| Full pre-load orchestration validated | PH-14 | Cross-chapter transitions are zero-latency with all assets resident |

---

## Stories

### Story 1: Create AssetPreloadCoordinator @Observable @MainActor singleton class

**Acceptance Criteria:**

- [ ] `AssetPreloadCoordinator` declared as `@Observable @MainActor final class` at `StarlightSync/Coordinators/AssetPreloadCoordinator.swift`.
- [ ] `static let shared` singleton accessor.
- [ ] `private init()` preventing external instantiation.
- [ ] Observable state property: `private(set) var preloadComplete: Bool = false`.
- [ ] Private storage: `private var decodedBackgrounds: [String: UIImage] = [:]` for session-lifetime image retention.
- [ ] Private storage: `private var spriteAtlas: SKTextureAtlas?` for session-lifetime atlas retention.
- [ ] Public method signature: `func preloadAllAssets() async` — the single entry point for the full preload sequence.
- [ ] Private named constants for all 5 background asset identifiers (e.g., `private let backgroundIntro = "img_bg_intro"`).
- [ ] Private named constant for sprite atlas name: `private let spriteAtlasName = "Sprites"`.
- [ ] No `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject`, or Combine imports.
- [ ] No force unwraps in the entire file.
- [ ] File contains exactly one primary type (`AssetPreloadCoordinator`).
- [ ] `import UIKit`, `import SpriteKit`, and `import os` as framework imports.
- [ ] File registered in `project.pbxproj` — PBXFileReference, PBXBuildFile, PBXGroup (Coordinators), and PBXSourcesBuildPhase entries present.

**Dependencies:** None
**Completion Signal:** `AssetPreloadCoordinator.shared` compiles and returns a configured singleton. `preloadComplete` is observable from SwiftUI views. `xcodebuild build` succeeds with zero errors.

---

### Story 2: Implement background image pre-decode on background threads

**Acceptance Criteria:**

- [ ] All 5 HEIC backgrounds decoded: `img_bg_intro`, `img_bg_runner`, `img_bg_cipher`, `img_bg_blueprint`, `img_finale_art`.
- [ ] Each background loaded via `UIImage(named:)` from the asset catalog.
- [ ] Each loaded `UIImage` force-decoded to BGRA bitmap via `byPreparingForDisplay()` to avoid lazy decoding stalls on first render.
- [ ] `byPreparingForDisplay()` executes on system-managed background threads — verified by the absence of main-thread stalls during decoding.
- [ ] Decoded `UIImage` instances stored in `decodedBackgrounds` dictionary keyed by asset identifier.
- [ ] Multiple backgrounds decoded concurrently using `async let` or `withTaskGroup` for parallelism.
- [ ] Individual decode failure (nil from `UIImage(named:)` or `byPreparingForDisplay()`) is logged via `os.Logger` under `#if DEBUG` and skipped — does not abort the batch.
- [ ] Decode operates on whatever backgrounds are available — missing assets (not yet integrated by ASSET_01) are skipped gracefully.
- [ ] No `DispatchQueue`, `Timer`, GCD, or Combine used for background-thread decoding.
- [ ] Strong references retained in `decodedBackgrounds` dictionary — never evicted, never set to `nil`.

**Dependencies:** ASSET_02-S1
**Completion Signal:** After `preloadAllAssets()` completes, `decodedBackgrounds.count` equals the number of successfully decoded backgrounds (up to 5). `Image("img_bg_intro")` in a SwiftUI view renders without any main-thread decode stall because the underlying `CGImage` is already resident.

---

### Story 3: Implement SKTextureAtlas preload for sprite atlas

**Acceptance Criteria:**

- [ ] `SKTextureAtlas(named: "Sprites")` created and preloaded via `preload(completionHandler:)`.
- [ ] Callback-based `preload(completionHandler:)` API wrapped in `withCheckedContinuation` to bridge to `async/await`.
- [ ] After preloading, the atlas reference stored in `self.spriteAtlas` as a strong session-lifetime reference.
- [ ] GPU texture cache populated with all sprite textures — verified by the absence of first-frame texture upload stalls in SpriteKit scenes.
- [ ] Preload failure (empty atlas, missing textures) logged via `os.Logger` under `#if DEBUG` — does not abort the preload sequence.
- [ ] If sprite atlas has no content (ASSET_01 not yet integrated), preload completes gracefully with a debug log.
- [ ] No `DispatchQueue`, `Timer`, GCD, or Combine used.
- [ ] Atlas reference is never set to `nil` after preloading — prevents GPU texture cache eviction per Design Doc §7.9.4.

**Dependencies:** ASSET_02-S1
**Completion Signal:** After `preloadAllAssets()` completes, `spriteAtlas` is non-nil. `SKTextureAtlas(named: "Sprites").textureNamed("sprite_otter_player")` returns a preloaded `SKTexture` without triggering on-demand GPU upload.

---

### Story 4: Orchestrate AudioManager, HapticManager, and font verification in preload sequence

**Acceptance Criteria:**

- [ ] `HapticManager.shared.preloadPatterns()` called during the preload sequence, triggering AHAP pattern parsing and caching for `heartbeat`, `capacitor_charge`, and `thud` patterns.
- [ ] `AudioManager.shared.preloadAssets()` called during the preload sequence, triggering `prepareToPlay()` on all audio player instances.
- [ ] Accessing `.shared` on `AudioManager` and `HapticManager` triggers their respective initializers, which handle `AVAudioSession.configure(.playback)` (step 1 of §7.9.2) and `CHHapticEngine.start()` (step 2 of §7.9.2).
- [ ] Preload sequence follows Design Doc §7.9.2 ordering: (1) audio session config, (2) haptic engine start, (3) AHAP cache, (4) audio prepare, (5) image decode, (6) texture preload, (7) font check.
- [ ] Custom font verification: check `UIFont(name: <customFontName>, size: 17)` — if nil, log under `#if DEBUG` that custom font is not registered and system fonts will be used as fallback.
- [ ] Font verification does not fail or block preloading — it is informational only.
- [ ] Manager preload failures are handled by their respective managers — the coordinator does not catch or re-handle their errors.
- [ ] All calls are synchronous method invocations on `@MainActor` singletons — no cross-actor messaging needed.
- [ ] Preload operations that can run concurrently (e.g., image decode + audio prepare) are parallelized where safe.

**Dependencies:** ASSET_02-S1, ASSET_02-S2, ASSET_02-S3
**Completion Signal:** After `preloadAllAssets()` completes, `HapticManager.shared` has cached AHAP patterns (if AHAP files exist in bundle), `AudioManager.shared` has prepared audio players (if audio files exist in bundle), and font registration status is logged.

---

### Story 5: Integrate preload coordinator with app launch and Chapter 1 timing

**Acceptance Criteria:**

- [ ] `AssetPreloadCoordinator.shared.preloadAllAssets()` called as an `async` task during app launch in `StarlightSyncApp.swift` or the initial view's `.task` modifier.
- [ ] Preload executes concurrently with Chapter 1's OLED black screen render — the user sees the fingerprint glyph while assets decode in the background.
- [ ] `preloadComplete` transitions from `false` to `true` when the full preload sequence finishes.
- [ ] Preload completes within Chapter 1's 3-second long-press interaction window per Design Doc §7.9.2 (~1.1s typical total).
- [ ] If preload has not completed when Chapter 1's long-press finishes, the transition to Chapter 2 waits on `preloadComplete` — no chapter transition occurs with undecoded assets.
- [ ] `preloadComplete` is set to `true` even if individual assets fail to decode — the coordinator does not block the experience on partial failures.
- [ ] No splash screen, loading indicator, or progress bar — Chapter 1's long-press interaction naturally masks the preload time per Design Doc §4.4.
- [ ] `StarlightSyncApp.swift` modifications are minimal — a single `.task` block or `onAppear` trigger.

**Dependencies:** ASSET_02-S1 through ASSET_02-S4
**Completion Signal:** App launches, Chapter 1 renders immediately (OLED black + fingerprint glyph), preload runs in background, `preloadComplete` becomes `true` before or during the 3-second long-press. Transition to Chapter 2 proceeds only after preload completes.

---

### Story 6: Validate memory budget, preload timing, and governance compliance

**Acceptance Criteria:**

- [ ] Total decoded memory footprint is within ~300MB budget per Design Doc §7.9.3:
  - HEIC backgrounds (5): ~180MB decoded to BGRA bitmap.
  - Sprite textures (5): ~40MB in GPU texture cache.
  - Audio buffers: ~24MB (when audio files are available).
  - AHAP patterns: <1MB.
  - Fonts: <5MB.
- [ ] Preload sequence completes within ~3 seconds on target hardware class (iPhone 17 Pro, A19 Pro).
- [ ] Zero force unwraps (`!`) in `AssetPreloadCoordinator.swift`.
- [ ] Zero `print` statements — all diagnostics use `os.Logger` under `#if DEBUG`.
- [ ] Zero deprecated API usage (`ObservableObject`, `@Published`, `@StateObject`, `DispatchQueue`, `Combine`).
- [ ] Zero Combine imports.
- [ ] Zero AI attribution artifacts (Protocol Zero compliance).
- [ ] Zero magic numbers — all asset identifiers and timing values as named constants.
- [ ] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0 and zero warnings.
- [ ] `python3 scripts/audit.py --all` passes with zero violations.
- [ ] File registered in `project.pbxproj` — PBXFileReference, PBXBuildFile, PBXGroup (Coordinators), and PBXSourcesBuildPhase entries present.
- [ ] No direct `SKTextureAtlas.preload()`, `UIImage(named:)`, or `CGImageSource` calls exist anywhere in the codebase outside `AssetPreloadCoordinator.swift` for preload purposes. Chapter views use standard SwiftUI `Image("name")` — they do not duplicate preload logic.

**Dependencies:** ASSET_02-S1 through ASSET_02-S5
**Completion Signal:** Clean build with zero errors. Audit script passes 7/7 checks. `AssetPreloadCoordinator.swift` compiles and is callable from `StarlightSyncApp.swift`. Memory budget validated by inspection of asset sizes against §7.9.3 table.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| `UIImage.byPreparingForDisplay()` unavailable or behaves differently on iOS 26 SDK | 3 | 1 | 3 | `byPreparingForDisplay()` is stable API since iOS 15. iOS 26 SDK includes it. If unavailable, fall back to `preparingForDisplay()` (synchronous variant called on a nonisolated context). Verify API availability against iOS 26 SDK headers. | iOS Engineer |
| Audio and AHAP files not yet present in bundle — preload calls produce empty caches | 2 | 5 | 10 | Both `AudioManager.preloadAssets()` and `HapticManager.preloadPatterns()` handle missing files gracefully (logged and skipped). The coordinator calls them regardless — when files are added later, the preload will cache them on next launch. | iOS Engineer |
| `SKTextureAtlas.preload(completionHandler:)` callback never fires if atlas is empty | 3 | 3 | 9 | Wrap the preload in a timeout mechanism using `Task.sleep` with a 5-second maximum wait. If the callback does not fire within 5 seconds, proceed with `preloadComplete = true` and log a warning. The atlas will fall back to on-demand loading. | iOS Engineer |
| Total decoded memory exceeds 300MB budget on the specific source images | 3 | 2 | 6 | Design Doc §7.9.3 estimates ~250MB total. The 300MB budget has ~50MB headroom. If exceeded, investigate individual image dimensions (over-sized source files may decode to larger-than-expected bitmaps). The target device has 8GB+ RAM with >5GB headroom. | iOS Engineer |
| `@MainActor` isolation conflicts with `byPreparingForDisplay()` async behavior in Swift 6.0 strict concurrency | 4 | 2 | 8 | `byPreparingForDisplay()` is a `nonisolated` async method on `UIImage`. It can be called from `@MainActor` context — the system dispatches the decode work to a background thread and resumes the caller on the main actor. Verify correct behavior under Swift 6.0 strict concurrency checking. | iOS Engineer |
| Preload takes longer than 3 seconds, not completing before Chapter 1 long-press finishes | 3 | 2 | 6 | Story 5 includes a gate: Chapter 1 completion waits on `preloadComplete`. This is a safety net — if preload is slow, the user simply holds the fingerprint a moment longer. The Design Doc §7.9.2 estimates ~1.1s total, well within the 3s window. | iOS Engineer |

---

## Definition of Done

- [ ] All 6 stories completed and individually verified.
- [ ] `AssetPreloadCoordinator` compiles as `@Observable @MainActor final class` with `static let shared`.
- [ ] All 5 HEIC backgrounds decoded to `UIImage` on background threads and stored as strong session-lifetime references.
- [ ] Sprite atlas preloaded via `SKTextureAtlas.preload()` with strong reference retained.
- [ ] `AudioManager.preloadAssets()` and `HapticManager.preloadPatterns()` called during preload sequence.
- [ ] Custom font registration verified (informational — does not block preload).
- [ ] `preloadComplete` observable property transitions to `true` after all preload operations finish.
- [ ] Preload integrated with app launch — executes during Chapter 1's long-press window.
- [ ] Total decoded memory within ~300MB budget per Design Doc §7.9.3.
- [ ] Preload completes within ~3 seconds per Design Doc §7.9.2 timing.
- [ ] Zero force unwraps, zero print statements, zero deprecated APIs, zero Combine usage.
- [ ] `xcodebuild build` succeeds with zero errors.
- [ ] `scripts/audit.py --all` passes with zero violations.
- [ ] No AI attribution artifacts (Protocol Zero).
- [ ] File registered in `project.pbxproj` with all required build phase entries.

## Exit Criteria

- [ ] All Definition of Done conditions satisfied.
- [ ] `AssetPreloadCoordinator.swift` exists at `StarlightSync/Coordinators/AssetPreloadCoordinator.swift` as a fully compilable singleton.
- [ ] PH-07 through PH-13 (chapter implementations) are unblocked — all asset types are pre-decoded and resident in memory before chapter views render.
- [ ] PH-14 (cross-chapter transitions) is unblocked — zero-latency transitions guaranteed by pre-loaded assets.
- [ ] PH-08 and PH-10 (SpriteKit chapters) are unblocked — sprite atlas textures are GPU-cached before scenes initialize.
- [ ] PH-05 phase gate passed — both ASSET_01 and ASSET_02 complete, all visual assets integrated and pre-loadable.
- [ ] Epic ID `ASSET_02` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
