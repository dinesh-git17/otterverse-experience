# Epic: ASSET_03 — Integrate Audio Assets into Bundle

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | ASSET_03                       |
| **Epic Name** | integrate_audio_assets         |
| **Phase**     | PH-05                          |
| **Domain**    | ASSET                          |
| **Owner**     | iOS Engineer                   |
| **Status**    | Draft                          |

---

## Problem Statement

The `AudioManager` singleton (PH-03) exposes a `preloadAssets()` method that calls `prepareToPlay()` on `AVAudioPlayer` instances, but the project's `Audio/` and `Audio/SFX/` bundle directories contain only `.gitkeep` placeholder files from PH-01 (INFRA_01 S6). Nine audio files — 2 background music tracks and 7 sound effects — now exist at `/Users/Dinesh/Desktop/assets/audio/` as AAC `.m4a` files matching the Design Doc §7.4 asset manifest identifiers. Without these files in the bundle, `AudioManager` cannot create `AVAudioPlayer` instances, no chapter can play BGM or SFX, and the Chapter 4 rhythm game cannot function (its beat map synchronization requires `audio_bgm_main` for timing).

ASSET_INT_PLAN §2.1 identified audio as "Missing Assets (Not Yet Sourced)" at the time of writing. The assets are now available. §2.1 also states: "Audio integrates during PH-03/PH-05." This epic integrates all audio files into the bundle during PH-05, alongside the visual asset integration (ASSET_01) and pre-load coordinator (ASSET_02), consolidating all asset work into a single phase.

The source directory also contains 2 alternate SFX files (`sfx_fail_soft.m4a`, `sfx_heart_collect.m4a`) not listed in Design Doc §7.4. These are retained in the bundle as available alternates for potential use during chapter tuning (PH-07 through PH-13) but are not mapped to any Design Doc identifier.

---

## Goals

- Place 2 BGM tracks (`audio_bgm_main.m4a`, `audio_bgm_finale.m4a`) into `StarlightSync/Audio/` bundle directory.
- Place 5 Design Doc SFX files (`sfx_haptic_thud.m4a`, `sfx_success_chime.m4a`, `sfx_shield_impact.m4a`, `sfx_click.m4a`, `sfx_error.m4a`) into `StarlightSync/Audio/SFX/` bundle directory.
- Place 2 alternate SFX files (`sfx_fail_soft.m4a`, `sfx_heart_collect.m4a`) into `StarlightSync/Audio/SFX/` alongside Design Doc SFX.
- Verify all audio files are included in the Copy Bundle Resources build phase via the folder reference mechanism established in PH-01.
- Verify `AudioManager` can resolve audio file URLs via `Bundle.main.url(forResource:withExtension:subdirectory:)` for all 7 Design Doc assets.
- Achieve a clean `xcodebuild build` with all audio files copied to the app bundle.
- Retain original source files at `/Users/Dinesh/Desktop/assets/audio/` unmodified.

## Non-Goals

- **No audio format conversion.** Source files are AAC `.m4a` — the target format per Design Doc §7.4. No re-encoding, no sample rate conversion.
- **No AudioManager code modifications.** `AudioManager` (PH-03) already handles `AVAudioPlayer` creation, `prepareToPlay()`, cross-fade, and interruption handling. This epic places files; it does not change playback code.
- **No beat map authoring.** The beat map is a `[TimeInterval]` array in `GameConstants.swift` (PH-06 scope). Having `audio_bgm_main` in-bundle unblocks PH-06 beat map authoring, but the array itself is not created here.
- **No chapter-level audio wiring.** Triggering specific SFX on chapter events (heart collect, cipher click, shield impact) is PH-07 through PH-13 scope.
- **No alternate SFX mapping to Design Doc identifiers.** The 2 alternate files are bundled for availability but not assigned to any chapter event. Re-mapping (e.g., replacing `sfx_success_chime` with `sfx_heart_collect`) is a chapter-level tuning decision.

---

## Technical Approach

Audio files are placed directly into the `StarlightSync/Audio/` and `StarlightSync/Audio/SFX/` directories on disk. These directories were created as Xcode folder references (blue folders) in PH-01 (INFRA_01 S6), meaning any file placed within them is automatically included in the Copy Bundle Resources build phase — no per-file `project.pbxproj` modifications are required. The `.gitkeep` placeholder files are removed after audio files are placed, as the directories are no longer empty.

**No format conversion is required.** Design Doc §7.4 specifies "AAC 256kbps `.m4a`" and §7.9.1 states "AAC files are copied to the app bundle without re-encoding (already in the target codec)." The source files are verified as valid AAC/ALAC `.m4a` containers via the `file` command.

**Bundle resource resolution:** `AudioManager` resolves audio files via `Bundle.main.url(forResource:withExtension:subdirectory:)`. For BGM files in `Audio/`, the subdirectory is `"Audio"`. For SFX files in `Audio/SFX/`, the subdirectory is `"Audio/SFX"`. The file names (without extension) serve as the resource identifier — e.g., `Bundle.main.url(forResource: "audio_bgm_main", withExtension: "m4a", subdirectory: "Audio")`.

**File organization follows Design Doc §7.4:**

| File | Type | Bundle Location |
|------|------|----------------|
| `audio_bgm_main.m4a` | BGM | `Audio/` |
| `audio_bgm_finale.m4a` | BGM | `Audio/` |
| `sfx_haptic_thud.m4a` | SFX | `Audio/SFX/` |
| `sfx_success_chime.m4a` | SFX | `Audio/SFX/` |
| `sfx_shield_impact.m4a` | SFX | `Audio/SFX/` |
| `sfx_click.m4a` | SFX | `Audio/SFX/` |
| `sfx_error.m4a` | SFX | `Audio/SFX/` |
| `sfx_fail_soft.m4a` | Alternate SFX | `Audio/SFX/` |
| `sfx_heart_collect.m4a` | Alternate SFX | `Audio/SFX/` |

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| `Audio/` and `Audio/SFX/` folder references in Copy Bundle Resources | INFRA_01 (PH-01) | Complete | iOS Engineer |
| Audio source files at `/Users/Dinesh/Desktop/assets/audio/` | External (project owner) | Available | Project Owner |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| `audio_bgm_main.m4a` in bundle | ASSET_02 (PH-05) | Pre-load coordinator calls `AudioManager.preloadAssets()` which creates `AVAudioPlayer` instances from bundled files |
| `audio_bgm_main.m4a` in bundle | PH-06 | GameConstants beat map authoring requires the BGM track for manual timestamp identification |
| `audio_bgm_main.m4a` in bundle | PH-07 | Chapter 1 completion triggers BGM loop start; BGM loops through Chapters 2-5 |
| `audio_bgm_finale.m4a` in bundle | PH-13 | Chapter 6 slider completion triggers "The Special Song" playback |
| `sfx_haptic_thud.m4a` in bundle | PH-07, PH-09 | Capacitor snap (Ch.1) and cipher segment lock (Ch.3) |
| `sfx_success_chime.m4a` in bundle | PH-08, PH-09, PH-11 | Heart collect (Ch.2), segment solve (Ch.3), node connect (Ch.5) |
| `sfx_shield_impact.m4a` in bundle | PH-10 | Successful noise tap in rhythm defense (Ch.4) |
| `sfx_click.m4a` in bundle | PH-09 | Cipher wheel scroll detent (Ch.3) |
| `sfx_error.m4a` in bundle | PH-11 | Invalid node connection snap-back (Ch.5) |
| All audio files prepared via `prepareToPlay()` | PH-14 | Cross-chapter transitions use pre-loaded audio for <10ms playback latency |

---

## Stories

### Story 1: Place BGM tracks in Audio/ bundle directory

**Acceptance Criteria:**

- [ ] `audio_bgm_main.m4a` copied from `/Users/Dinesh/Desktop/assets/audio/` to `StarlightSync/Audio/audio_bgm_main.m4a`.
- [ ] `audio_bgm_finale.m4a` copied from `/Users/Dinesh/Desktop/assets/audio/` to `StarlightSync/Audio/audio_bgm_finale.m4a`.
- [ ] File names match Design Doc §7.4 asset IDs exactly (snake_case, `.m4a` extension).
- [ ] Files are valid AAC/ALAC `.m4a` containers (verified via `file` command).
- [ ] `.gitkeep` in `StarlightSync/Audio/` removed — directory is no longer empty.
- [ ] Source files at `/Users/Dinesh/Desktop/assets/audio/` are not modified or deleted.

**Dependencies:** None
**Completion Signal:** `ls StarlightSync/Audio/` shows `audio_bgm_main.m4a` and `audio_bgm_finale.m4a` with correct file sizes matching the source.

---

### Story 2: Place SFX files in Audio/SFX/ bundle directory

**Acceptance Criteria:**

- [ ] 5 Design Doc SFX files copied to `StarlightSync/Audio/SFX/`:
  - `sfx_haptic_thud.m4a`
  - `sfx_success_chime.m4a`
  - `sfx_shield_impact.m4a`
  - `sfx_click.m4a`
  - `sfx_error.m4a`
- [ ] 2 alternate SFX files copied to `StarlightSync/Audio/SFX/`:
  - `sfx_fail_soft.m4a`
  - `sfx_heart_collect.m4a`
- [ ] File names match source file names exactly (snake_case, `.m4a` extension).
- [ ] All 7 files are valid AAC/ALAC `.m4a` containers (verified via `file` command).
- [ ] `.gitkeep` in `StarlightSync/Audio/SFX/` removed — directory is no longer empty.
- [ ] Source files at `/Users/Dinesh/Desktop/assets/audio/` are not modified or deleted.

**Dependencies:** None (parallel with S1)
**Completion Signal:** `ls StarlightSync/Audio/SFX/` shows all 7 SFX files with correct file sizes.

---

### Story 3: Verify audio file accessibility via Bundle resource resolution

**Acceptance Criteria:**

- [ ] All 9 audio files appear in the Xcode Copy Bundle Resources build phase automatically via folder reference inclusion. No manual `project.pbxproj` edits required for individual audio files.
- [ ] `Bundle.main.url(forResource: "audio_bgm_main", withExtension: "m4a", subdirectory: "Audio")` resolves to a valid URL in a runtime context.
- [ ] `Bundle.main.url(forResource: "sfx_click", withExtension: "m4a", subdirectory: "Audio/SFX")` resolves to a valid URL in a runtime context.
- [ ] All 7 Design Doc asset IDs resolve successfully via the subdirectory-aware `Bundle.main.url` pattern.
- [ ] Alternate SFX files (`sfx_fail_soft`, `sfx_heart_collect`) also resolve via `Bundle.main.url` — they are bundled and accessible even though not mapped to Design Doc events.
- [ ] `AudioManager.shared.preloadAssets()` can create `AVAudioPlayer` instances from the bundled files without error (verified by build and runtime initialization).

**Dependencies:** ASSET_03-S1, ASSET_03-S2
**Completion Signal:** `xcodebuild build` succeeds. Inspecting the built `.app` bundle confirms `Audio/` and `Audio/SFX/` directories contain all 9 `.m4a` files.

---

### Story 4: Validate build, Copy Bundle Resources, and governance compliance

**Acceptance Criteria:**

- [ ] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0 and zero warnings.
- [ ] `python3 scripts/audit.py --all` passes with zero violations.
- [ ] No Protocol Zero violations in any new or modified file.
- [ ] No plaintext secret patterns in any audio file name, directory, or metadata.
- [ ] Total audio bundle size is reasonable:
  - BGM: `audio_bgm_main.m4a` (~1.0MB) + `audio_bgm_finale.m4a` (~1.8MB) = ~2.8MB.
  - SFX: 7 files totaling ~200KB.
  - Total audio: ~3MB (well within Design Doc §7.1 "100-300MB" total bundle target).
- [ ] No `.gitkeep` files remain in `Audio/` or `Audio/SFX/` directories.
- [ ] Source files at `/Users/Dinesh/Desktop/assets/audio/` are intact and unmodified (all 9 files present with original sizes).
- [ ] Git diff shows only file additions (audio files) and `.gitkeep` removals — no unrelated modifications.

**Dependencies:** ASSET_03-S1, ASSET_03-S2, ASSET_03-S3
**Completion Signal:** Clean build with zero errors. Audit passes 7/7 checks. `Audio/` and `Audio/SFX/` contain exactly the expected files with no placeholders.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| Folder reference does not automatically include new files in Copy Bundle Resources | 4 | 1 | 4 | PH-01 created `Audio/` and `Haptics/` as folder references (blue folders in Xcode). Folder references include all nested files by design. Verify by inspecting Copy Bundle Resources phase in `project.pbxproj` — the folder reference entry covers the entire directory tree. | iOS Engineer |
| Audio file sample rate or codec incompatible with `AVAudioPlayer` on target device | 3 | 1 | 3 | Source files verified as AAC/ALAC `.m4a` — Apple's native codec. `AVAudioPlayer` supports all AAC variants on iOS. Hardware-decoded via AudioToolbox on A19 Pro. No compatibility risk on the target device. | iOS Engineer |
| `Bundle.main.url(forResource:withExtension:subdirectory:)` subdirectory resolution differs between simulator and device | 3 | 2 | 6 | Folder references maintain directory hierarchy in the built bundle on both simulator and device. The `subdirectory` parameter matches the on-disk path relative to the bundle root. Test resolution on simulator build; device validation in PH-16. | iOS Engineer |
| Alternate SFX files create confusion about which files are canonical Design Doc assets | 2 | 3 | 6 | Alternate files are named distinctly (`sfx_fail_soft`, `sfx_heart_collect`) and do not collide with any Design Doc §7.4 identifier. The epic explicitly documents them as alternates not mapped to chapter events. | iOS Engineer |
| Large audio files increase app bundle size beyond TestFlight limits | 2 | 1 | 2 | Total audio is ~3MB. Design Doc §7.1 budgets 100-300MB total bundle. TestFlight allows up to 4GB. No size risk. | iOS Engineer |

---

## Definition of Done

- [ ] All 4 stories completed and individually verified.
- [ ] 2 BGM tracks in `StarlightSync/Audio/` with correct file names.
- [ ] 7 SFX files (5 Design Doc + 2 alternate) in `StarlightSync/Audio/SFX/` with correct file names.
- [ ] All 9 files included in Copy Bundle Resources via folder reference.
- [ ] All 7 Design Doc audio identifiers resolvable via `Bundle.main.url(forResource:withExtension:subdirectory:)`.
- [ ] No `.gitkeep` placeholder files remain in `Audio/` or `Audio/SFX/`.
- [ ] `xcodebuild build` succeeds with zero errors.
- [ ] `scripts/audit.py --all` passes with zero violations.
- [ ] No Protocol Zero violations.
- [ ] Source files at `/Users/Dinesh/Desktop/assets/audio/` unmodified.

## Exit Criteria

- [ ] All Definition of Done conditions satisfied.
- [ ] ASSET_02 (pre-load coordinator) is unblocked — `AudioManager.preloadAssets()` can create and prepare all `AVAudioPlayer` instances from bundled files.
- [ ] PH-06 (GameConstants) is unblocked — `audio_bgm_main.m4a` is in-bundle for beat map authoring.
- [ ] PH-07 through PH-13 (chapter implementations) are unblocked — all BGM and SFX files are bundled and accessible.
- [ ] PH-14 (cross-chapter transitions) is unblocked — BGM cross-fade has actual audio files to play.
- [ ] Epic ID `ASSET_03` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
