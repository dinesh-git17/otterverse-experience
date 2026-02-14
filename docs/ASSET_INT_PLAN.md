# Asset Integration Plan

**Document ID:** ASSET-INT-001
**Source Location:** `/Users/Dinesh/Desktop/assets/`
**Authority:** `Design-Doc.md` §7, `CLAUDE.md` §4.6, §8
**Enforcement Level:** BLOCKING — agents MUST consult this document before integrating any asset.

---

## 1. Purpose

This document defines the deterministic integration plan for all visual assets staged at `/Users/Dinesh/Desktop/assets/`. It maps each asset to its Design Doc identifier, target catalog location, consuming component, required phase, and pre-integration transformations.

Agents MUST NOT integrate assets outside the phase windows defined here. Premature integration is a governance violation.

---

## 2. Source Inventory

11 PNG files at `/Users/Dinesh/Desktop/assets/`:

| # | Source File | Design Doc ID | Type | Dimensions | Size |
|---|-------------|---------------|------|------------|------|
| 1 | `app_icon.png` | `app_icon` | App Icon | 2048×2048 | 6.6 MB |
| 2 | `img_bg_intro.png` | `img_bg_intro` | Background | 1536×2752 | 6.6 MB |
| 3 | `img_bg_runner.png` | `img_bg_runner` | Background | 1536×2752 | 7.4 MB |
| 4 | `img_bg_cipher.png` | `img_bg_cipher` | Background | 1536×2752 | 8.3 MB |
| 5 | `img_bubble_shield.png` | `img_bubble_shield` | Sprite/BG | 1536×2752 | 7.5 MB |
| 6 | `img_bg_blueprint.png` | `img_bg_blueprint` | Background | 1536×2752 | 8.5 MB |
| 7 | `img_finale_art.png` | `img_finale_art` | Background | 1536×2752 | 7.5 MB |
| 8 | `sprite_otter_player.png` | `sprite_otter_player` | Sprite | 2816×1536 | 1.6 MB |
| 9 | `sprite_obstacle_glitch.png` | `sprite_obstacle_glitch` | Sprite | 2400×1792 | 5.1 MB |
| 10 | `sprite_heart_pickup.png` | `sprite_heart_pickup` | Sprite | 2400×1792 | 1.8 MB |
| 11 | `sprite_noise_particle.png` | `sprite_noise_particle` | Sprite | 2400×1792 | 2.7 MB |

### 2.1 Missing Assets (Not Yet Sourced)

The following Design Doc assets are NOT present in the source folder and must be sourced separately:

| Category | Asset ID | Design Doc Ref |
|----------|----------|----------------|
| Audio (BGM) | `audio_bgm_main` | §7.4 #1 |
| Audio (BGM) | `audio_bgm_finale` | §7.4 #2 |
| Audio (SFX) | `sfx_haptic_thud` | §7.4 #3 |
| Audio (SFX) | `sfx_success_chime` | §7.4 #4 |
| Audio (SFX) | `sfx_shield_impact` | §7.4 #5 |
| Audio (SFX) | `sfx_click` | §7.4 #6 |
| Audio (SFX) | `sfx_error` | §7.4 #7 |
| Haptic | `heartbeat.ahap` | §7.6 #1 |
| Haptic | `capacitor_charge.ahap` | §7.6 #2 |
| Haptic | `thud.ahap` | §7.6 #3 |
| Font (optional) | Custom display font | §7.7 |

These assets follow the same phase-gating rules. Audio integrates during PH-03/PH-05. Haptics integrate during PH-04/PH-05.

---

## 3. Pre-Integration Transformations

These transformations MUST be applied before placing assets into the catalog.

### 3.1 App Icon — Resize to 1024×1024

Design Doc §7.2 requires a single 1024×1024 PNG source in `AppIcon.appiconset/`. The source file is 2048×2048.

```bash
sips -z 1024 1024 /Users/Dinesh/Desktop/assets/app_icon.png --out <project>/StarlightSync/Assets.xcassets/AppIcon.appiconset/app_icon.png
```

### 3.2 Backgrounds — Convert PNG to HEIC

Design Doc §7.2 specifies HEIC format for all visual backgrounds. Source files are PNG.

```bash
# Per background file:
sips --setProperty format heic /Users/Dinesh/Desktop/assets/<file>.png --out <target>.heic
```

Apply to: `img_bg_intro`, `img_bg_runner`, `img_bg_cipher`, `img_bg_blueprint`, `img_finale_art`.

**Exception:** `img_bubble_shield` is consumed by `FirewallScene` as a sprite node (§7.2 component table). If used as an `SKTexture`, retain PNG format and place in the sprite atlas instead. If used as a SwiftUI `Image` background, convert to HEIC. Determine usage context at integration time per the `FirewallScene` implementation.

### 3.3 Backgrounds — Scale Variant Generation

Design Doc §7.2 requires `@2x` and `@3x` scale variants. Source images are 1536×2752 (single resolution).

**Interpretation:** 1536×2752 at `@3x` yields a logical resolution of 512×917pt — consistent with iPhone Pro Max logical width. Treat source files as `@3x` masters.

```bash
# Generate @2x from @3x source:
sips -z 1835 1024 /Users/Dinesh/Desktop/assets/<file>.png --out <target>@2x.<ext>
```

Scale factor: `@2x` = source dimensions × (2/3) = 1024×1835.

Each background asset catalog entry requires:

- `<id>@2x.heic` — 1024×1835
- `<id>@3x.heic` — 1536×2752 (original, format-converted)
- `Contents.json` with scale descriptors

### 3.4 Sprites — No Transformation Required

Design Doc §7.3 specifies PNG with alpha channel. Source sprites are PNG. No conversion needed. Verify alpha channel presence at integration time.

---

## 4. Target Catalog Structure

After integration, the asset catalog MUST match this layout:

```
StarlightSync/Assets.xcassets/
├── AppIcon.appiconset/
│   ├── app_icon.png                    (1024×1024 PNG)
│   └── Contents.json
├── Backgrounds/
│   ├── img_bg_intro.imageset/
│   │   ├── img_bg_intro@2x.heic
│   │   ├── img_bg_intro@3x.heic
│   │   └── Contents.json
│   ├── img_bg_runner.imageset/
│   │   ├── img_bg_runner@2x.heic
│   │   ├── img_bg_runner@3x.heic
│   │   └── Contents.json
│   ├── img_bg_cipher.imageset/
│   │   ├── img_bg_cipher@2x.heic
│   │   ├── img_bg_cipher@3x.heic
│   │   └── Contents.json
│   ├── img_bg_blueprint.imageset/
│   │   ├── img_bg_blueprint@2x.heic
│   │   ├── img_bg_blueprint@3x.heic
│   │   └── Contents.json
│   └── img_finale_art.imageset/
│       ├── img_finale_art@2x.heic
│       ├── img_finale_art@3x.heic
│       └── Contents.json
├── Sprites.spriteatlas/
│   ├── sprite_otter_player.imageset/
│   │   ├── sprite_otter_player.png
│   │   └── Contents.json
│   ├── sprite_obstacle_glitch.imageset/
│   │   ├── sprite_obstacle_glitch.png
│   │   └── Contents.json
│   ├── sprite_heart_pickup.imageset/
│   │   ├── sprite_heart_pickup.png
│   │   └── Contents.json
│   ├── sprite_noise_particle.imageset/
│   │   ├── sprite_noise_particle.png
│   │   └── Contents.json
│   └── img_bubble_shield.imageset/
│       ├── img_bubble_shield.png
│       └── Contents.json
└── Contents.json
```

**Notes:**

- `img_bubble_shield` is placed in `Sprites.spriteatlas/` per §7.3 ("Chapter 4's `sprite_noise_particle` shares an atlas group with `img_bubble_shield`").
- Sprite images are single-resolution (SpriteKit handles point-to-pixel mapping via `SKTexture` scale property).
- Each `Contents.json` must declare `"rendering-intent" : "original"` (no template rendering).

---

## 5. Phase-Gated Integration Schedule

### 5.1 PH-01 — Xcode Project Scaffold

**Integrate:** `app_icon.png` only.

| Step | Action |
|------|--------|
| 1 | Create `Assets.xcassets/` with root `Contents.json` |
| 2 | Create `Assets.xcassets/AppIcon.appiconset/` |
| 3 | Resize `app_icon.png` to 1024×1024 (§3.1) |
| 4 | Place resized PNG in `AppIcon.appiconset/` |
| 5 | Write `Contents.json` with single-size icon descriptor |
| 6 | Create empty `Assets.xcassets/Backgrounds/` group with `Contents.json` |
| 7 | Create empty `Assets.xcassets/Sprites.spriteatlas/` with `Contents.json` |

**Do NOT integrate** backgrounds or sprites during PH-01. The catalog groups are created as empty scaffolds only.

### 5.2 PH-05 — Asset Pre-load Pipeline

**Integrate:** All 6 backgrounds + all 4 sprites + `img_bubble_shield`.

This is the canonical integration phase. PH-05 depends on PH-03 (AudioManager) and PH-04 (HapticManager), which means all subsystems that consume assets exist.

| Step | Action |
|------|--------|
| 1 | Convert 5 backgrounds from PNG to HEIC (§3.2) |
| 2 | Generate `@2x` scale variants for all backgrounds (§3.3) |
| 3 | Place HEIC files in `Backgrounds/<id>.imageset/` with `Contents.json` |
| 4 | Place 4 sprite PNGs in `Sprites.spriteatlas/<id>.imageset/` with `Contents.json` |
| 5 | Place `img_bubble_shield.png` in `Sprites.spriteatlas/img_bubble_shield.imageset/` |
| 6 | Implement pre-load coordinator per §7.9.2 launch sequence |
| 7 | Wire `SKTextureAtlas.preload(completionHandler:)` for sprite atlas |
| 8 | Wire `CGImageSource` HEIC decode on background threads for backgrounds |
| 9 | Validate total decoded memory ≤ 300MB budget (§7.9.3) |

### 5.3 Integration Prohibited Before Phase Gate

| Asset | Earliest Integration | Why |
|-------|---------------------|-----|
| `app_icon.png` | PH-01 | Requires `Assets.xcassets/AppIcon.appiconset/` |
| All backgrounds | PH-05 | Requires preload pipeline; no catalog before PH-01 |
| All sprites | PH-05 | Requires `SKTextureAtlas.preload()` wiring |
| `img_bubble_shield` | PH-05 | Shares atlas with `sprite_noise_particle` |

An agent attempting to integrate backgrounds during PH-02, PH-03, or PH-04 MUST refuse and cite this section.

---

## 6. Component Binding Validation

At integration time, verify each asset is referenced ONLY by its designated consumer. Cross-chapter asset access is a governance violation per `CLAUDE.md` §3.2, §8.

| Asset ID | Sole Consumer | Chapter | Lookup Pattern |
|----------|---------------|---------|----------------|
| `img_bg_intro` | `HandshakeView` | Ch. 1 | `Image("img_bg_intro")` |
| `img_bg_runner` | `PacketRunScene` | Ch. 2 | `SKTexture(imageNamed: "img_bg_runner")` or preload reference |
| `img_bg_cipher` | `CipherView` | Ch. 3 | `Image("img_bg_cipher")` |
| `img_bubble_shield` | `FirewallScene` | Ch. 4 | `SKTexture(imageNamed: "img_bubble_shield")` |
| `img_bg_blueprint` | `BlueprintView` | Ch. 5 | `Image("img_bg_blueprint")` |
| `img_finale_art` | `EventHorizonView` | Ch. 6 | `Image("img_finale_art")` |
| `sprite_otter_player` | `PacketRunScene` | Ch. 2 | `SKTextureAtlas(named: "Sprites").textureNamed("sprite_otter_player")` |
| `sprite_obstacle_glitch` | `PacketRunScene` | Ch. 2 | `SKTextureAtlas(named: "Sprites").textureNamed("sprite_obstacle_glitch")` |
| `sprite_heart_pickup` | `PacketRunScene` | Ch. 2 | `SKTextureAtlas(named: "Sprites").textureNamed("sprite_heart_pickup")` |
| `sprite_noise_particle` | `FirewallScene` | Ch. 4 | `SKTextureAtlas(named: "Sprites").textureNamed("sprite_noise_particle")` |
| `app_icon` | System (SpringBoard) | N/A | Xcode-managed |

---

## 7. Preload Sequence Alignment

Per Design Doc §7.9.2, the launch pre-load sequence is:

```
1. AVAudioSession.configure(.playback)           // ~10ms
2. CHHapticEngine.start()                         // ~50ms
3. AHAP patterns → CHHapticPattern cache          // ~20ms
4. Audio: prepareToPlay() for all AVAudioPlayers  // ~200ms
5. HEIC backgrounds → UIImage decode (bg threads) // ~500ms  ← backgrounds
6. SKTextureAtlas.preload() for sprite atlases    // ~300ms  ← sprites
7. Custom font registration verification          // ~10ms
                                           Total: ~1.1s
```

Steps 5 and 6 are the asset integration points. The preload coordinator (PH-05) must:

- Decode HEIC backgrounds on background threads via `CGImageSource`
- Call `SKTextureAtlas.preload(completionHandler:)` for the sprite atlas
- Hold decoded `UIImage` references as strong properties (no eviction — §7.9.5)
- Complete all loading behind Chapter 1's 3-second long-press interaction window

---

## 8. Contents.json Templates

### 8.1 App Icon

```json
{
  "images" : [
    {
      "filename" : "app_icon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

### 8.2 Background Image Set (per asset)

```json
{
  "images" : [
    {
      "filename" : "<id>@2x.heic",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "<id>@3x.heic",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "compression-type" : "lossless",
    "preserves-vector-representation" : false
  }
}
```

### 8.3 Sprite Image Set (per asset)

```json
{
  "images" : [
    {
      "filename" : "<id>.png",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : false
  }
}
```

### 8.4 Folder Group (Backgrounds/, Sprites.spriteatlas/)

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "provides-namespace" : true
  }
}
```

---

## 9. Validation Checklist

Before marking asset integration complete for any phase, verify:

- [ ] Every integrated asset ID matches Design Doc §7.2–7.3 exactly (snake_case).
- [ ] Backgrounds are HEIC with `@2x` and `@3x` variants.
- [ ] Sprites are PNG with alpha channel, placed inside `Sprites.spriteatlas/`.
- [ ] `img_bubble_shield` is in the sprite atlas (not Backgrounds).
- [ ] App icon is exactly 1024×1024 PNG.
- [ ] Every `Contents.json` is valid and references correct filenames.
- [ ] No asset is consumed by a component outside its designated chapter (§6 table).
- [ ] No asset is integrated before its phase gate (§5.3 table).
- [ ] Preload coordinator references all integrated assets in the correct sequence (§7).
- [ ] Total decoded memory footprint ≤ 300MB (§7.9.3 of Design Doc).
- [ ] Source PNGs retained at `/Users/Dinesh/Desktop/assets/` — never deleted.
