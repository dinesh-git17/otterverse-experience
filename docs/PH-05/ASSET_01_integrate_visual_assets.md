# Epic: ASSET_01 — Integrate Visual Assets into Asset Catalog

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | ASSET_01                       |
| **Epic Name** | integrate_visual_assets        |
| **Phase**     | PH-05                          |
| **Domain**    | ASSET                          |
| **Owner**     | iOS Engineer                   |
| **Status**    | Complete                       |

---

## Problem Statement

All 11 visual assets required by the Design Doc (§7.2, §7.3) exist as raw PNG files at `/Users/Dinesh/Desktop/assets/` but the Xcode asset catalog at `StarlightSync/Assets.xcassets/` contains only empty placeholder imageset directories created during PH-01 (INFRA_01). The five background images require format conversion from PNG to HEIC per Design Doc §7.1 to achieve ~50% size reduction via hardware-decoded HEVC, and scale variant generation (`@2x` from `@3x` masters) per Design Doc §7.2. The four sprite atlas placeholder imagesets contain no actual texture files. Without integrated assets, the pre-load coordinator (ASSET_02) has no content to decode into memory, and no chapter view (PH-07 through PH-13) can render its visual identity.

The `docs/ASSET_INT_PLAN.md` §5.2 designates PH-05 as the canonical integration phase for all backgrounds and sprites. Integration before this phase gate is a governance violation per ASSET_INT_PLAN §5.3. This epic performs the file-level transformations and catalog placement prescribed by ASSET_INT_PLAN §3, populating the catalog structure scaffolded in PH-01 with production-ready image files that `actool` compiles into `.car` and `.atlasc` binary formats at build time.

---

## Goals

- Transform 5 background PNGs (`img_bg_intro`, `img_bg_runner`, `img_bg_cipher`, `img_bg_blueprint`, `img_finale_art`) to HEIC format per ASSET_INT_PLAN §3.2.
- Generate `@2x` scale variants (1024x1835) from `@3x` masters (1536x2752) per ASSET_INT_PLAN §3.3, producing 10 HEIC files total.
- Place all background HEIC files into `Assets.xcassets/Backgrounds/<id>.imageset/` directories with correctly configured `Contents.json` per ASSET_INT_PLAN §8.2.
- Place 4 sprite PNGs (`sprite_otter_player`, `sprite_obstacle_glitch`, `sprite_heart_pickup`, `sprite_noise_particle`) into `Assets.xcassets/Sprites.spriteatlas/<id>.imageset/` directories with correctly configured `Contents.json` per ASSET_INT_PLAN §8.3.
- Place `img_bubble_shield.png` into `Sprites.spriteatlas/img_bubble_shield.imageset/` per Design Doc §7.3 atlas grouping requirement ("Chapter 4's `sprite_noise_particle` shares an atlas group with `img_bubble_shield`") and ASSET_INT_PLAN §4.
- Achieve a clean `xcodebuild build` with all assets compiled by `actool` into `.car` (backgrounds) and `.atlasc` (sprite atlas) binary formats.
- Retain original source PNGs at `/Users/Dinesh/Desktop/assets/` unmodified.

## Non-Goals

- **No app icon integration.** Already completed in PH-01 (INFRA_01 S4). The 1024x1024 resized icon is in `AppIcon.appiconset/`.
- **No audio asset integration.** Audio files (BGM, SFX) are not yet sourced per ASSET_INT_PLAN §2.1. Audio assets integrate when files are provided by the project owner.
- **No AHAP haptic file creation or placement.** Haptic pattern files are authored separately and consumed by HapticManager (PH-04). AHAP placement is independent of this epic.
- **No pre-load coordinator code.** The Swift module that decodes and caches these assets at runtime is ASSET_02 scope. This epic handles file-level integration only.
- **No chapter view modifications.** Chapter views consume assets via identifier references during PH-07 through PH-13. No Swift code changes in this epic.
- **No custom font integration.** Font files are optional per Design Doc §7.7 and not present in the source folder.

---

## Technical Approach

All image transformations use `sips` (Scriptable Image Processing System), Apple's built-in command-line tool for image format conversion and resizing. This maintains the zero-third-party-dependency constraint per CLAUDE.md §3.1.

**Background transformation pipeline:** For each of the 5 backgrounds, the pipeline is: (1) treat the 1536x2752 source PNG as the `@3x` master, (2) convert the `@3x` master from PNG to HEIC via `sips --setProperty format heic`, producing `<id>@3x.heic`, (3) resize the source PNG to 1024x1835 (`@2x` = source dimensions x 2/3) via `sips -z 1835 1024`, (4) convert the resized PNG to HEIC, producing `<id>@2x.heic`. Each background imageset directory receives exactly two files plus a `Contents.json` referencing both scale variants.

**Sprite placement:** No transformation is required for sprites. Design Doc §7.3 specifies PNG with alpha channel, and source files are already PNG. The 4 sprite PNGs and `img_bubble_shield.png` are copied directly into their respective imageset directories within `Sprites.spriteatlas/`. Sprite images are single-resolution — SpriteKit handles point-to-pixel mapping via `SKTexture`'s scale property at runtime.

**Atlas grouping:** `img_bubble_shield` is placed in `Sprites.spriteatlas/` (not `Backgrounds/`) per ASSET_INT_PLAN §4, despite having the `img_` prefix. This ensures `img_bubble_shield` and `sprite_noise_particle` are packed into a single GPU texture sheet by `actool` at build time, reducing per-frame texture binding overhead in `FirewallScene` from 2 binds to 1 — consistent with the Design Doc §7.3 optimization note.

**Contents.json configuration:** Each imageset's `Contents.json` follows the templates defined in ASSET_INT_PLAN §8.2 (backgrounds with `@2x`/`@3x` scale descriptors, `"compression-type": "lossless"`) and §8.3 (sprites with `1x` universal scale, no compression property). Group-level `Contents.json` files in `Backgrounds/` and `Sprites.spriteatlas/` use the §8.4 template with `"provides-namespace": true`.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| Asset catalog scaffold with `Backgrounds/` and `Sprites.spriteatlas/` groups | INFRA_01 (PH-01) | Complete | iOS Engineer |
| Source PNG files at `/Users/Dinesh/Desktop/assets/` | External (project owner) | Available | Project Owner |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| Background HEIC files in asset catalog | ASSET_02 (PH-05) | Pre-load coordinator decodes backgrounds to UIImage during launch sequence |
| Sprite atlas with texture files | ASSET_02 (PH-05) | Pre-load coordinator calls `SKTextureAtlas.preload()` on populated atlas |
| `img_bg_intro` in catalog | PH-07 | HandshakeView renders Chapter 1 OLED background |
| `img_bg_runner` in catalog | PH-08 | PacketRunScene renders parallax scrolling background |
| `img_bg_cipher` in catalog | PH-09 | CipherView renders vault door background |
| `img_bubble_shield` in atlas | PH-10 | FirewallScene renders center-screen otter shield sprite |
| `img_bg_blueprint` in catalog | PH-11 | BlueprintView renders architectural blueprint background |
| `img_finale_art` in catalog | PH-13 | EventHorizonView renders finale art cross-fade |
| `sprite_otter_player` in atlas | PH-08 | PacketRunScene renders player character |
| `sprite_obstacle_glitch` in atlas | PH-08 | PacketRunScene renders obstacle spawner |
| `sprite_heart_pickup` in atlas | PH-08 | PacketRunScene renders heart collectibles |
| `sprite_noise_particle` in atlas | PH-10 | FirewallScene renders beat-synced noise particles |

---

## Stories

### Story 1: Transform background PNGs to HEIC format with scale variants

**Acceptance Criteria:**

- [x] 5 backgrounds transformed: `img_bg_intro`, `img_bg_runner`, `img_bg_cipher`, `img_bg_blueprint`, `img_finale_art`.
- [x] Each background produces two HEIC files: `<id>@3x.heic` (1536x2752, format-converted from source) and `<id>@2x.heic` (1024x1835, resized then format-converted).
- [x] Transformation uses `sips` exclusively — no third-party image tools.
- [x] `@3x` HEIC files are visually identical to the source PNGs (lossless HEIC conversion, not lossy JPEG-style compression).
- [x] `@2x` HEIC files are correctly downscaled with no aspect ratio distortion (2752 x 2/3 = 1835, 1536 x 2/3 = 1024).
- [x] 10 total HEIC files produced (5 backgrounds x 2 scale variants).
- [x] `img_bubble_shield` is NOT transformed to HEIC — it remains PNG and is handled in Story 3.
- [x] Source PNGs at `/Users/Dinesh/Desktop/assets/` are not modified or deleted.

**Dependencies:** None
**Completion Signal:** 10 HEIC files exist, each with correct dimensions verified via `sips --getProperty pixelWidth --getProperty pixelHeight`. No source files deleted.

---

### Story 2: Place background HEIC files into asset catalog image sets

**Acceptance Criteria:**

- [x] 5 background imageset directories exist at `Assets.xcassets/Backgrounds/<id>.imageset/`, each containing exactly 3 files: `<id>@2x.heic`, `<id>@3x.heic`, and `Contents.json`.
- [x] If placeholder imageset directories from PH-01 exist, they are updated in-place (no duplicate directories).
- [x] If an `img_bubble_shield.imageset/` exists inside `Backgrounds/`, it is removed — `img_bubble_shield` belongs in `Sprites.spriteatlas/` per ASSET_INT_PLAN §4.
- [x] Each `Contents.json` follows ASSET_INT_PLAN §8.2 template exactly:
  - `images` array with `@2x` and `@3x` entries, `"idiom": "universal"`, correct filenames.
  - `properties` block with `"compression-type": "lossless"` and `"preserves-vector-representation": false`.
- [x] `Backgrounds/Contents.json` (group-level) contains `"provides-namespace": true` per ASSET_INT_PLAN §8.4.
- [x] No stale placeholder files (`.gitkeep`, empty PNGs) remain in background imageset directories.
- [x] Asset identifiers accessible via `Image("img_bg_intro")` etc. in SwiftUI and `UIImage(named: "img_bg_intro")` in UIKit.

**Dependencies:** ASSET_01-S1
**Completion Signal:** `xcodebuild build` compiles the asset catalog without warnings. `actool` processes all 5 background image sets into `Assets.car`.

---

### Story 3: Place sprite and shield PNG files into sprite atlas image sets

**Acceptance Criteria:**

- [x] 4 sprite imageset directories exist at `Assets.xcassets/Sprites.spriteatlas/<id>.imageset/`, each containing exactly 2 files: `<id>.png` and `Contents.json`.
- [x] Sprites placed: `sprite_otter_player`, `sprite_obstacle_glitch`, `sprite_heart_pickup`, `sprite_noise_particle`.
- [x] `img_bubble_shield.imageset/` exists at `Assets.xcassets/Sprites.spriteatlas/img_bubble_shield.imageset/` with `img_bubble_shield.png` and `Contents.json`.
- [x] If the `img_bubble_shield.imageset/` directory does not exist in the sprite atlas (not scaffolded in PH-01), create it with correct structure.
- [x] Each sprite `Contents.json` follows ASSET_INT_PLAN §8.3 template exactly:
  - `images` array with single `1x` universal entry, correct PNG filename.
  - `properties` block with `"preserves-vector-representation": false`.
  - No `"compression-type"` property (sprites use default compression).
- [x] `Sprites.spriteatlas/Contents.json` (group-level) contains `"provides-namespace": true` per ASSET_INT_PLAN §8.4.
- [x] All sprite PNGs retain alpha channel (transparency) — verified via `sips --getProperty hasAlpha`.
- [x] No stale placeholder files (`.gitkeep`, empty PNGs) remain in sprite imageset directories.
- [x] Total of 5 image sets in sprite atlas (4 sprites + `img_bubble_shield`).
- [x] Sprites accessible via `SKTextureAtlas(named: "Sprites").textureNamed("sprite_otter_player")` etc. at runtime.

**Dependencies:** None (parallel with S1/S2)
**Completion Signal:** `xcodebuild build` compiles the sprite atlas without warnings. `actool` packs all 5 sprite entries into `Sprites.atlasc/` texture sheets.

---

### Story 4: Validate asset catalog integrity, build, and governance compliance

**Acceptance Criteria:**

- [x] Final asset catalog directory structure matches ASSET_INT_PLAN §4 exactly — 5 background image sets in `Backgrounds/`, 5 sprite image sets in `Sprites.spriteatlas/`, app icon in `AppIcon.appiconset/`.
- [x] Every `Contents.json` is syntactically valid JSON (parseable by `python3 -m json.tool`).
- [x] Every `Contents.json` references files that actually exist in the same directory (no dangling filename references).
- [x] No asset is consumed by a component outside its designated chapter per ASSET_INT_PLAN §6 binding table.
- [x] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0 and zero `actool` warnings.
- [x] `python3 scripts/audit.py --all` passes with zero violations.
- [x] No Protocol Zero violations — no AI attribution in comments, filenames, or commit messages.
- [x] Source PNGs retained at `/Users/Dinesh/Desktop/assets/` — all 11 original files present and unmodified.
- [x] No plaintext secret patterns in any new or modified file (CLAUDE.md §5).
- [x] Background HEIC file sizes are measurably smaller than source PNGs (HEIC compression verified).

**Dependencies:** ASSET_01-S1, ASSET_01-S2, ASSET_01-S3
**Completion Signal:** Clean build with zero errors and zero asset catalog warnings. Audit passes 7/7 checks. `ls -la` on catalog directories confirms correct file count and structure.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| `sips` HEIC conversion produces lossy output instead of lossless | 3 | 2 | 6 | Verify output quality by comparing file sizes and visual inspection. `sips` default HEIC conversion is visually lossless at maximum quality. If quality loss is detected, use `--setProperty formatOptions 100` flag for maximum quality. | iOS Engineer |
| `@2x` resize produces pixel rounding artifacts on non-integer dimension scaling | 2 | 1 | 2 | Source dimensions (1536x2752) divide cleanly by 3: 512x917.33 logical points. The `@2x` variant at 1024x1835 is 2x the logical size (rounding 917.33 x 2 = 1834.67, rounded to 1835). This is standard practice for device scale factors. | iOS Engineer |
| `actool` rejects HEIC files in asset catalog on older Xcode versions | 4 | 1 | 4 | Project uses Xcode 26.2 which fully supports HEIC in asset catalogs. HEIC has been supported since Xcode 9 / iOS 11. No version risk on the target toolchain. | iOS Engineer |
| Sprite atlas texture sheet exceeds GPU memory limit at build time | 3 | 1 | 3 | Total sprite PNG size is ~14MB uncompressed. `actool` packs into power-of-2 texture sheets. iPhone 17 Pro GPU supports texture sheets up to 16384x16384. The 5 sprites fit comfortably in a single atlas sheet. | iOS Engineer |
| `img_bubble_shield.imageset/` already exists in `Backgrounds/` from PH-01 scaffold causing duplicate asset ID | 3 | 3 | 9 | Story 2 explicitly checks for and removes any `img_bubble_shield.imageset/` directory from `Backgrounds/` before Story 3 places it in `Sprites.spriteatlas/`. Build will fail on duplicate asset IDs, providing an immediate signal if this is missed. | iOS Engineer |

---

## Definition of Done

- [x] All 4 stories completed and individually verified.
- [x] 5 background image sets contain `@2x` and `@3x` HEIC files with valid `Contents.json`.
- [x] 5 sprite atlas image sets contain PNG files with valid `Contents.json`.
- [x] `img_bubble_shield` is in `Sprites.spriteatlas/` (not `Backgrounds/`).
- [x] Asset catalog directory structure matches ASSET_INT_PLAN §4 exactly.
- [x] `xcodebuild build` succeeds with zero errors and zero `actool` warnings.
- [x] `scripts/audit.py --all` passes with zero violations.
- [x] No Protocol Zero violations.
- [x] Source PNGs at `/Users/Dinesh/Desktop/assets/` are unmodified and intact.
- [x] No third-party tools used for image processing (Apple `sips` only).

## Exit Criteria

- [x] All Definition of Done conditions satisfied.
- [x] ASSET_02 (pre-load coordinator) is unblocked — asset catalog contains all visual assets for decoding.
- [x] PH-07 through PH-13 (chapter implementations) are unblocked — all background and sprite identifiers resolve from the asset catalog.
- [x] No asset ID conflicts or duplicate imageset directories in the catalog.
- [x] Epic ID `ASSET_01` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
