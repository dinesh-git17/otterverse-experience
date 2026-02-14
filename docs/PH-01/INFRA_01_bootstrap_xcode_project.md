# Epic: INFRA_01 — Bootstrap Xcode Project

## Metadata

| Field         | Value                        |
| ------------- | ---------------------------- |
| **Epic ID**   | INFRA_01                     |
| **Epic Name** | bootstrap_xcode_project      |
| **Phase**     | PH-01                        |
| **Domain**    | INFRA                        |
| **Owner**     | iOS Engineer                 |
| **Status**    | Complete                     |

---

## Problem Statement

No Xcode project exists. The repository contains governance documents (`CLAUDE.md`, `Design-Doc.md`), skill infrastructure, and agent context scaffolding — but zero Swift source code, no build target, no asset pipeline, and no directory structure for implementation. Every subsequent phase (PH-02 through PH-17) depends on a buildable project shell. Until this project exists, no chapter code, no manager singletons, no game logic, and no tests can be written. The entire 17-phase delivery pipeline is blocked at the root.

The target device is iPhone 17 Pro (A19 Pro, iOS 19+, 120Hz ProMotion, full Taptic Engine). The project must be configured for this hardware profile from inception to prevent retroactive build setting corrections that would cascade through dependent phases.

---

## Goals

- Deliver a buildable Xcode project targeting iOS 19+ that compiles with zero errors and zero warnings via `xcodebuild build`.
- Establish the canonical directory structure defined in CLAUDE.md §8, with all source group directories, asset catalog containers, and bundle resource directories present and correctly organized.
- Configure the asset pipeline (Assets.xcassets image sets, Sprites.spriteatlas group, Audio/ and Haptics/ bundle directories) so that subsequent phases can drop assets into pre-existing locations without project file surgery.

## Non-Goals

- **No Swift source code beyond the app entry point.** `FlowCoordinator`, `AudioManager`, `HapticManager`, and all chapter views are PH-02+ deliverables. This epic produces the empty shell they attach to.
- **No actual asset files (HEIC, PNG, M4A, AHAP).** Asset catalog groups and bundle directories are created with organizational structure only. Real assets are authored and integrated during chapter phases.
- **No TestFlight configuration or App Store Connect setup.** Signing is configured for local development builds. Distribution provisioning is deferred to PH-17.
- **No CI/CD pipeline.** Per CLAUDE.md §9, all work is local and pre-remote. No GitHub Actions, Xcode Cloud, or Fastlane.

---

## Technical Approach

The project will be initialized as a single-target iOS application using the SwiftUI App lifecycle (`@main` entry point). The deployment target is iOS 19.0, matching the iPhone 17 Pro's launch OS. The project uses Swift 5.9+ (matching the active Xcode toolchain) with strict concurrency checking enabled to align with CLAUDE.md §4.1's mandate for modern Swift concurrency.

The directory structure follows CLAUDE.md §8 exactly: `Coordinators/`, `Managers/`, `Services/`, `Chapters/` (with six subdirectories `Chapter1_Handshake/` through `Chapter6_EventHorizon/`), `Models/`, `Components/`, `Audio/` (with `SFX/` subdirectory), and `Haptics/`. Each directory will contain a `.gitkeep` file to ensure empty directories are tracked by git until implementation files replace them. These `.gitkeep` files are explicitly temporary scaffolding — they are removed as real source files populate each directory.

The asset catalog (`Assets.xcassets`) will be structured with named groups for chapter backgrounds (`Backgrounds/`) and the app icon (`AppIcon.appiconset/`). A separate `Sprites.spriteatlas` folder will be created for SpriteKit texture atlas compilation. These groups provide the organizational skeleton that asset authors target during chapter implementation phases. Audio and haptic assets live outside the asset catalog as loose bundle resources in `Audio/` and `Haptics/` directories, matching the Design-Doc §7.1 storage location specification.

Build settings will target iPhone-only (no iPad), portrait orientation locked, with status bar hidden for the immersive game experience. The bundle identifier will follow reverse-DNS convention. Signing will use automatic code signing with the development team configured for the active Apple Developer Program enrollment.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency                             | Source   | Status    | Owner        |
| -------------------------------------- | -------- | --------- | ------------ |
| Active Apple Developer Program enrollment | External | Committed | Project Owner |
| Xcode toolchain with Swift 5.9+ and iOS 19 SDK | External | Committed | iOS Engineer |

### Outbound (This Epic Unblocks)

| Dependency                        | Target   | Description                                                              |
| --------------------------------- | -------- | ------------------------------------------------------------------------ |
| Buildable Xcode project           | INFRA_02 | Git initialization requires project files to exist for initial commit     |
| Buildable Xcode project           | PH-02    | FlowCoordinator implementation requires a compilable target              |
| Asset catalog structure            | PH-05    | Asset pre-load pipeline expects catalog groups at known paths            |
| Directory structure                | PH-03, PH-04 | AudioManager and HapticManager files target `Managers/` directory   |
| Xcode project with signing         | PH-12    | WebhookService requires a build target with network entitlement          |

---

## Stories

### Story 1: Create Xcode project with StarlightSync app target

**Acceptance Criteria:**

- [x] Xcode project named `StarlightSync` exists at the repository root with a `.xcodeproj` bundle.
- [x] Single application target `StarlightSync` with SwiftUI App lifecycle (`@main` struct in `StarlightSyncApp.swift`).
- [x] `StarlightSyncApp.swift` contains a minimal `@main` entry point with a placeholder `ContentView` displaying the app name. No business logic.
- [x] `ContentView` includes a `#Preview` macro.
- [x] Project opens in Xcode without errors or migration prompts.

**Dependencies:** None
**Completion Signal:** `xcodebuild -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build` exits with code 0.

---

### Story 2: Configure build settings for iOS 19+ and iPhone 17 Pro

**Acceptance Criteria:**

- [x] Deployment target is iOS 19.0.
- [x] Targeted device family is iPhone only (no iPad — `TARGETED_DEVICE_FAMILY = 1`).
- [x] Swift language version is 5.9 or matches the active Xcode toolchain default.
- [x] Strict concurrency checking is enabled (`SWIFT_STRICT_CONCURRENCY = complete`).
- [x] Supported interface orientations restricted to portrait only (`UIInterfaceOrientationPortrait`).
- [x] Status bar is hidden (`UIStatusBarHidden = YES` in Info.plist or via SwiftUI modifier).
- [x] Bundle identifier follows reverse-DNS convention (e.g., `com.otterverse.starlightsync`).
- [x] Automatic code signing configured with development team ID.

**Dependencies:** INFRA_01-S1
**Completion Signal:** `xcodebuild -showBuildSettings` output confirms `IPHONEOS_DEPLOYMENT_TARGET = 19.0`, `TARGETED_DEVICE_FAMILY = 1`, and `SWIFT_STRICT_CONCURRENCY = complete`.

---

### Story 3: Create source directory structure per CLAUDE.md §8

**Acceptance Criteria:**

- [x] `Coordinators/` directory exists at project root level.
- [x] `Managers/` directory exists at project root level.
- [x] `Services/` directory exists at project root level.
- [x] `Models/` directory exists at project root level.
- [x] `Components/` directory exists at project root level.
- [x] `Chapters/` directory exists with six subdirectories: `Chapter1_Handshake/`, `Chapter2_PacketRun/`, `Chapter3_Cipher/`, `Chapter4_Firewall/`, `Chapter5_Blueprint/`, `Chapter6_EventHorizon/`.
- [x] Each empty directory contains a `.gitkeep` file for version control tracking.
- [x] All directories are registered as groups (not folder references) in the Xcode project navigator.
- [x] No loose Swift files exist in the project root except `StarlightSyncApp.swift`.

**Dependencies:** INFRA_01-S1
**Completion Signal:** `find StarlightSync/ -type d | sort` output matches the canonical tree from CLAUDE.md §8. All directories visible in Xcode project navigator.

---

### Story 4: Configure Assets.xcassets with chapter background image set groups

**Acceptance Criteria:**

- [x] `Assets.xcassets` exists at the project root level within the target source directory.
- [x] `Backgrounds/` group within `Assets.xcassets` contains 7 named image sets matching Design-Doc §7.2 asset IDs: `img_bg_intro`, `img_bg_runner`, `img_bg_cipher`, `img_bubble_shield`, `img_bg_blueprint`, `img_finale_art`, `app_icon`.
- [x] Each image set contains a valid `Contents.json` with empty `images` array entries for @2x and @3x scale variants.
- [x] `AppIcon.appiconset/` exists with a valid `Contents.json` skeleton.
- [x] `AccentColor` colorset is removed or replaced with a project-specific color (no default system accent color per CLAUDE.md §4.2).
- [x] Asset catalog compiles without warnings via `actool`.

**Dependencies:** INFRA_01-S1
**Completion Signal:** Xcode Asset Catalog editor displays all 7 named image sets under `Backgrounds/` and a configured `AppIcon` set. Build produces no asset catalog warnings.

---

### Story 5: Configure Sprites.spriteatlas for SpriteKit texture atlas

**Acceptance Criteria:**

- [x] `Sprites.spriteatlas` folder exists within `Assets.xcassets` (or as a top-level folder reference, depending on Xcode's atlas compilation requirements).
- [x] Atlas contains 4 named sprite placeholders matching Design-Doc §7.3 asset IDs: `sprite_otter_player`, `sprite_obstacle_glitch`, `sprite_heart_pickup`, `sprite_noise_particle`.
- [x] Each sprite placeholder has a valid `Contents.json` configured for texture atlas compilation.
- [x] Atlas structure is compatible with `SKTextureAtlas.preload(completionHandler:)` API (validated in PH-05).

**Dependencies:** INFRA_01-S1
**Completion Signal:** `Sprites.spriteatlas` visible in Xcode navigator. `xcodebuild build` compiles the atlas without errors. `SKTextureAtlas(named: "Sprites")` resolves at runtime (verified in PH-05).

---

### Story 6: Create Audio/ and Haptics/ bundle resource directories

**Acceptance Criteria:**

- [x] `Audio/` directory exists at the project source root with `SFX/` subdirectory.
- [x] `Haptics/` directory exists at the project source root.
- [x] Both directories are added to the target's "Copy Bundle Resources" build phase as folder references.
- [x] Directory structure matches Design-Doc §7.1 storage locations: audio in `Audio/` and `Audio/SFX/`, haptics in `Haptics/`.
- [x] `.gitkeep` files present in empty directories for version control.
- [x] Directories are accessible at runtime via `Bundle.main.path(forResource:ofType:subdirectory:)`.

**Dependencies:** INFRA_01-S1
**Completion Signal:** Build succeeds. `Audio/` and `Haptics/` directories appear in the compiled `.app` bundle (verified via `find` on the built product in DerivedData).

---

### Story 7: Validate project builds with zero errors and zero warnings

**Acceptance Criteria:**

- [x] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` exits with return code 0.
- [x] Build log contains zero errors.
- [x] Build log contains zero warnings (including deprecation, signing, and asset catalog warnings).
- [x] App launches on iOS Simulator and displays the placeholder content view.
- [x] No `print` statements in any committed source file.
- [x] No force unwraps (`!`) in any committed source file.
- [x] No deprecated APIs referenced in any committed source file.

**Dependencies:** INFRA_01-S1, INFRA_01-S2, INFRA_01-S3, INFRA_01-S4, INFRA_01-S5, INFRA_01-S6
**Completion Signal:** Clean `xcodebuild build` with exit code 0, zero errors, zero warnings. Simulator shows running app.

---

## Risks

| Risk                                                         | Impact (1-5) | Likelihood (1-5) | Score | Mitigation                                                                                          | Owner        |
| ------------------------------------------------------------ | :----------: | :--------------: | :---: | --------------------------------------------------------------------------------------------------- | ------------ |
| iOS 19 SDK not available in current Xcode toolchain          |      5       |        2         |  10   | Verify Xcode version supports iOS 19 target before starting. Fall back to latest available beta SDK. | iOS Engineer |
| Automatic signing fails without Developer Program enrollment |      3       |        2         |   6   | Confirm Apple Developer Program membership is active. Use manual signing as fallback.                | Project Owner |
| Xcode project file (.pbxproj) manual edits cause corruption  |      4       |        3         |  12   | Never edit .pbxproj manually. Use Xcode GUI or `xcodebuild` commands exclusively. Per CLAUDE.md §6. | iOS Engineer |
| Asset catalog structure incompatible with future atlas needs  |      2       |        2         |   4   | Follow Design-Doc §7.1–7.3 specifications exactly. Validate atlas compilation in build.             | iOS Engineer |

---

## Definition of Done

- [x] All 7 stories completed and individually verified.
- [x] `xcodebuild build` succeeds with zero errors and zero warnings.
- [x] Directory tree matches CLAUDE.md §8 layout exactly.
- [x] Asset catalog contains all placeholder groups per Design-Doc §7.1–7.3.
- [x] No force unwraps, no `print` statements, no deprecated APIs in committed code.
- [x] `#Preview` macro present on all SwiftUI views.
- [x] No third-party dependencies introduced.
- [x] No AI attribution artifacts in source files, comments, or file headers (Protocol Zero).

## Exit Criteria

- [x] All Definition of Done conditions satisfied.
- [x] Project opens in Xcode without errors, migration dialogs, or missing references.
- [x] Build succeeds on a clean checkout (delete DerivedData, rebuild).
- [x] Directory structure validated against CLAUDE.md §8 canonical tree.
- [x] INFRA_02 (version control initialization) is unblocked and ready to execute.
