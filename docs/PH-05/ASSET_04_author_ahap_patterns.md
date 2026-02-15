# Epic: ASSET_04 — Author and Integrate AHAP Haptic Patterns

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | ASSET_04                       |
| **Epic Name** | author_ahap_patterns           |
| **Phase**     | PH-05                          |
| **Domain**    | ASSET                          |
| **Owner**     | iOS Engineer                   |
| **Status**    | Draft                          |

---

## Problem Statement

`HapticManager` (PH-04) exposes a `preloadPatterns()` method that resolves AHAP files from the bundle via `Bundle.main.url(forResource:withExtension:)`, parses them via `CHHapticPattern(contentsOf:)`, and caches the results in a `[String: CHHapticPattern]` dictionary keyed by three identifiers: `"heartbeat"`, `"capacitor_charge"`, and `"thud"`. However, the `Haptics/` bundle directory contains only a `.gitkeep` placeholder from PH-01 (INFRA_01 S6). Without actual `.ahap` files, `preloadPatterns()` logs debug-level failures for each missing file and the pattern cache remains empty — every subsequent `play(_:)` call is a silent no-op.

Design Doc §7.6 defines the three required haptic patterns with specific behavioral descriptions: `heartbeat.ahap` ("Pulsing heartbeat with rising intensity and sharpness"), `capacitor_charge.ahap` ("Continuous intensity ramp with sharp snap event"), and `thud.ahap` ("Single heavy transient event"). These descriptions are sufficient to author the AHAP JSON files conforming to Apple's `CHHapticPattern` specification. The patterns are consumed across multiple chapters: `capacitor_charge` in Chapter 1's long-press, `thud` in Chapter 3's cipher lock, and `heartbeat` in Chapter 6's progressive slider.

This epic authors the three AHAP files from the Design Doc specifications and places them in the `Haptics/` bundle directory. Once integrated, `HapticManager.preloadPatterns()` will successfully parse and cache all three patterns, and `play(_:)` calls from chapter views will produce tangible haptic feedback on supported hardware.

---

## Goals

- Author `heartbeat.ahap` implementing a pulsing haptic pattern with configurable rising intensity and sharpness per Design Doc §7.6.
- Author `capacitor_charge.ahap` implementing a continuous intensity ramp over ~3 seconds culminating in a sharp transient snap event per Design Doc §7.6.
- Author `thud.ahap` implementing a single heavy transient haptic event per Design Doc §7.6.
- Place all 3 AHAP files in `StarlightSync/Haptics/` bundle directory.
- Verify `HapticManager.shared.preloadPatterns()` successfully parses all 3 files into cached `CHHapticPattern` instances.
- Ensure all AHAP files conform to Apple's AHAP JSON schema and are parseable by `CHHapticPattern(contentsOf:)`.
- Achieve a clean `xcodebuild build` with AHAP files included in Copy Bundle Resources.

## Non-Goals

- **No HapticManager code modifications.** `HapticManager` (PH-04) already handles AHAP parsing, caching, engine lifecycle, and graceful degradation. This epic creates the data files it consumes.
- **No chapter-level haptic wiring.** Triggering specific patterns at chapter events (capacitor snap on long-press completion, thud on cipher lock, heartbeat during slider drag) is PH-07, PH-09, and PH-13 scope.
- **No on-device haptic tuning.** Subjective feel evaluation (intensity too strong/weak, sharpness too sharp/soft, timing adjustments) is PH-16 scope (on-device QA). The patterns authored here are initial implementations matching the Design Doc descriptions. Tuning parameters are accessible for adjustment.
- **No additional haptic patterns beyond the Design Doc §7.6 manifest.** Inline transient events (cipher wheel click detents, tap confirmations) are handled by `HapticManager.playTransientEvent(intensity:sharpness:)` at runtime and do not require AHAP files.

---

## Technical Approach

AHAP (Apple Haptic Audio Pattern) is a JSON-based format interpreted by CoreHaptics at runtime. Each `.ahap` file defines a `Pattern` array containing `Event` objects with typed parameters. The two event types used are:

- **`HapticTransient`** — A brief, sharp impulse (tap/thud). Parameters: `HapticIntensity` (0.0-1.0) and `HapticSharpness` (0.0-1.0). Duration is implicit (instantaneous).
- **`HapticContinuous`** — A sustained vibration over a specified duration. Parameters: `HapticIntensity` and `HapticSharpness`. Supports `ParameterCurve` for dynamic modulation over time.

**Pattern design:**

**`heartbeat.ahap`** — Simulates a biological heartbeat with the characteristic "lub-dub" double-beat pattern. Each cycle consists of two `HapticTransient` events separated by ~150ms (the systolic-diastolic interval), followed by a longer pause (~600ms) before the next cycle. The pattern spans multiple cycles with progressively increasing intensity (0.3 → 0.8) and sharpness (0.2 → 0.6) to create the "rising" sensation described in the Design Doc. This pattern is used during Chapter 1's capacitor charge (3-second hold) and Chapter 6's progressive slider drag, where rising intensity mirrors the user's approach to completion.

**`capacitor_charge.ahap`** — Simulates an electrical capacitor charging to full capacity. Uses a `HapticContinuous` event with a `ParameterCurve` that ramps `HapticIntensity` from 0.1 to 0.9 over ~2.5 seconds, paired with a parallel sharpness curve from 0.1 to 0.7. At the ~2.8 second mark, a high-intensity `HapticTransient` event (intensity 1.0, sharpness 1.0) fires as the "snap" — the moment the capacitor discharges. This terminal snap is the tactile confirmation that the Chapter 1 long-press has completed. The continuous ramp creates anticipation; the snap provides resolution.

**`thud.ahap`** — The simplest pattern: a single `HapticTransient` event at high intensity (0.9) and moderate sharpness (0.4). The low sharpness creates a deep, bass-heavy impact feel rather than a sharp click. This is the confirmation feedback when a cipher wheel segment locks into the correct position in Chapter 3. Designed to feel weighty and definitive.

**File placement:** AHAP files are placed directly in `StarlightSync/Haptics/`. This directory is a folder reference (blue folder) in Xcode, established in PH-01 (INFRA_01 S6). Files placed within it are automatically included in the Copy Bundle Resources build phase. The `.gitkeep` placeholder is removed after AHAP files are placed.

**Validation:** Each AHAP file is validated by (1) JSON syntax check via `python3 -m json.tool`, (2) schema conformance check (required keys: `Version`, `Pattern`, event `Time` values, `EventType`, `EventParameters`), and (3) build verification confirming `CHHapticPattern(contentsOf:)` would accept the file (verified indirectly via `xcodebuild build` — the file must be valid JSON to be bundled, and `HapticManager.preloadPatterns()` parses it at runtime). Full on-device validation occurs in PH-16.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| `Haptics/` folder reference in Copy Bundle Resources | INFRA_01 (PH-01) | Complete | iOS Engineer |
| `HapticManager` singleton with `preloadPatterns()` API | HAPTIC_01 (PH-04) | Complete | iOS Engineer |
| Pattern specifications (behavioral descriptions) | Design Doc §7.6 | Approved | Staff Architect |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| `heartbeat.ahap` in bundle | ASSET_02 (PH-05) | Pre-load coordinator calls `HapticManager.preloadPatterns()` which parses and caches the pattern |
| `capacitor_charge.ahap` in bundle | PH-07 | Chapter 1 long-press triggers `play("capacitor_charge")` for rising intensity feedback |
| `heartbeat.ahap` in bundle | PH-07 | Chapter 1 may use heartbeat pattern as alternative/complement to capacitor charge |
| `thud.ahap` in bundle | PH-09 | Chapter 3 correct cipher segment alignment triggers `play("thud")` |
| `heartbeat.ahap` in bundle | PH-13 | Chapter 6 progressive slider drag triggers `play("heartbeat")` |
| All patterns cached in HapticManager | PH-14 | Cross-chapter transitions verify multi-sensory redundancy with cached patterns |

---

## Stories

### Story 1: Author heartbeat.ahap with pulsing lub-dub pattern and rising intensity

**Acceptance Criteria:**

- [ ] File created at `StarlightSync/Haptics/heartbeat.ahap`.
- [ ] AHAP JSON contains `"Version": 1.0` at the root level.
- [ ] Pattern implements the "lub-dub" double-beat heartbeat cycle: two `HapticTransient` events per cycle separated by ~150ms, with ~600ms pause between cycles.
- [ ] Pattern spans at least 4 heartbeat cycles (~3 seconds total duration) to cover Chapter 1's long-press window and Chapter 6's slider drag.
- [ ] Intensity rises progressively across cycles: starting at ~0.3, ending at ~0.8.
- [ ] Sharpness rises progressively across cycles: starting at ~0.2, ending at ~0.6.
- [ ] All `Time` values are in seconds, monotonically increasing, and non-negative.
- [ ] All `HapticIntensity` and `HapticSharpness` values are within [0.0, 1.0] range.
- [ ] File is syntactically valid JSON (parseable by `python3 -m json.tool`).
- [ ] No AI attribution in the JSON metadata or comments (Protocol Zero).

**Dependencies:** None
**Completion Signal:** `python3 -m json.tool StarlightSync/Haptics/heartbeat.ahap` exits 0. File contains at least 8 `HapticTransient` events across 4+ cycles.

---

### Story 2: Author capacitor_charge.ahap with continuous ramp and terminal snap

**Acceptance Criteria:**

- [ ] File created at `StarlightSync/Haptics/capacitor_charge.ahap`.
- [ ] AHAP JSON contains `"Version": 1.0` at the root level.
- [ ] Pattern contains a `HapticContinuous` event starting at `Time: 0.0` with duration of ~2.5-2.8 seconds.
- [ ] `HapticContinuous` event includes a `ParameterCurve` for `HapticIntensity` ramping from ~0.1 to ~0.9 over the event duration.
- [ ] `HapticContinuous` event includes a `ParameterCurve` for `HapticSharpness` ramping from ~0.1 to ~0.7 over the event duration.
- [ ] A terminal `HapticTransient` event fires at ~2.8-3.0 seconds with intensity 1.0 and sharpness 1.0 — the "snap" discharge.
- [ ] The snap event is timed to occur at or just after the continuous ramp ends, creating a seamless charge → discharge transition.
- [ ] Total pattern duration is ~3 seconds, matching Chapter 1's minimum long-press hold time.
- [ ] All `Time` values are in seconds, monotonically increasing, and non-negative.
- [ ] All parameter values are within [0.0, 1.0] range.
- [ ] File is syntactically valid JSON (parseable by `python3 -m json.tool`).
- [ ] No AI attribution in the JSON metadata or comments (Protocol Zero).

**Dependencies:** None (parallel with S1)
**Completion Signal:** `python3 -m json.tool StarlightSync/Haptics/capacitor_charge.ahap` exits 0. File contains at least one `HapticContinuous` event with `ParameterCurve` entries and one terminal `HapticTransient` event.

---

### Story 3: Author thud.ahap with single heavy transient impact

**Acceptance Criteria:**

- [ ] File created at `StarlightSync/Haptics/thud.ahap`.
- [ ] AHAP JSON contains `"Version": 1.0` at the root level.
- [ ] Pattern contains exactly one `HapticTransient` event at `Time: 0.0`.
- [ ] Event intensity is high (~0.9) for a strong, forceful impact.
- [ ] Event sharpness is moderate (~0.4) for a deep, bass-heavy feel rather than a sharp click.
- [ ] Pattern is minimal — no continuous events, no parameter curves, no additional transients.
- [ ] All parameter values are within [0.0, 1.0] range.
- [ ] File is syntactically valid JSON (parseable by `python3 -m json.tool`).
- [ ] No AI attribution in the JSON metadata or comments (Protocol Zero).

**Dependencies:** None (parallel with S1, S2)
**Completion Signal:** `python3 -m json.tool StarlightSync/Haptics/thud.ahap` exits 0. File contains exactly one `HapticTransient` event.

---

### Story 4: Integrate AHAP files into Haptics/ bundle and validate

**Acceptance Criteria:**

- [ ] All 3 AHAP files exist at `StarlightSync/Haptics/`: `heartbeat.ahap`, `capacitor_charge.ahap`, `thud.ahap`.
- [ ] `.gitkeep` in `StarlightSync/Haptics/` removed — directory is no longer empty.
- [ ] All 3 files are included in the Copy Bundle Resources build phase automatically via the folder reference mechanism.
- [ ] `Bundle.main.url(forResource: "heartbeat", withExtension: "ahap", subdirectory: "Haptics")` resolves to a valid URL (verified by build and folder reference inclusion).
- [ ] `Bundle.main.url(forResource: "capacitor_charge", withExtension: "ahap", subdirectory: "Haptics")` resolves to a valid URL.
- [ ] `Bundle.main.url(forResource: "thud", withExtension: "ahap", subdirectory: "Haptics")` resolves to a valid URL.
- [ ] `HapticManager.shared.preloadPatterns()` would successfully parse all 3 files into `CHHapticPattern` instances and cache them (verified indirectly: files are valid JSON with correct AHAP schema, and `HapticManager` uses `CHHapticPattern(contentsOf:)` which requires valid AHAP).
- [ ] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0 and zero warnings.
- [ ] `python3 scripts/audit.py --all` passes with zero violations.
- [ ] No Protocol Zero violations in any AHAP file or commit message.
- [ ] Source AHAP files are authored assets (not sourced from `/Users/Dinesh/Desktop/assets/` — AHAP files are created in this epic, not copied from an external source).
- [ ] No plaintext secret patterns in any AHAP file content.

**Dependencies:** ASSET_04-S1, ASSET_04-S2, ASSET_04-S3
**Completion Signal:** Clean build with zero errors. Audit passes 7/7. `ls StarlightSync/Haptics/` shows exactly 3 `.ahap` files with no `.gitkeep`. All 3 files pass JSON syntax validation.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| AHAP pattern parameters produce unsatisfying haptic feel on device | 3 | 3 | 9 | Intensity, sharpness, and timing values are initial estimates based on Design Doc descriptions. PH-16 (on-device QA) is explicitly scoped for haptic tuning. All numeric values are easily adjustable in the AHAP JSON without code changes. | iOS Engineer |
| `CHHapticPattern(contentsOf:)` rejects authored AHAP due to schema violation | 4 | 2 | 8 | AHAP schema is well-documented by Apple. Each file is validated against required keys (`Version`, `Pattern`, `Event`, `EventType`, `EventParameters`, `ParameterID`, `ParameterValue`). `ParameterCurve` syntax verified against Apple Developer documentation examples. Runtime validation occurs in PH-16. | iOS Engineer |
| `ParameterCurve` in capacitor_charge.ahap is not supported on iOS 26 SDK | 3 | 1 | 3 | `ParameterCurve` has been part of the AHAP specification since iOS 13 / CoreHaptics 1.0. No deprecation or removal in iOS 26. If issues arise, fall back to discrete `HapticContinuous` events at interval steps. | iOS Engineer |
| Heartbeat pattern duration does not match Chapter 1 hold time or Chapter 6 slider duration | 2 | 2 | 4 | The pattern is authored for ~3 seconds (4 cycles). Chapters can loop the pattern by calling `play("heartbeat")` repeatedly, or `HapticManager` can be extended to support looping playback in chapter implementation phases. The standalone pattern need not match the exact interaction duration. | iOS Engineer |
| Folder reference does not include `.ahap` extension in Copy Bundle Resources | 3 | 1 | 3 | Folder references include ALL files regardless of extension. Xcode does not filter by file type for folder references — only for group-based file inclusion. The `.ahap` extension is a standard file type recognized by Xcode. | iOS Engineer |

---

## Definition of Done

- [ ] All 4 stories completed and individually verified.
- [ ] `heartbeat.ahap` authored with lub-dub pulsing pattern across 4+ cycles with rising intensity (0.3 → 0.8) and sharpness (0.2 → 0.6).
- [ ] `capacitor_charge.ahap` authored with continuous ramp (0.1 → 0.9 intensity over ~2.5s) and terminal snap transient (1.0/1.0).
- [ ] `thud.ahap` authored with single heavy transient (0.9 intensity, 0.4 sharpness).
- [ ] All 3 files are syntactically valid JSON.
- [ ] All 3 files conform to Apple's AHAP schema (Version, Pattern, Event structure).
- [ ] All 3 files placed in `StarlightSync/Haptics/` and included in Copy Bundle Resources.
- [ ] No `.gitkeep` placeholder remains in `Haptics/`.
- [ ] `xcodebuild build` succeeds with zero errors.
- [ ] `scripts/audit.py --all` passes with zero violations.
- [ ] No Protocol Zero violations.

## Exit Criteria

- [ ] All Definition of Done conditions satisfied.
- [ ] ASSET_02 (pre-load coordinator) is unblocked — `HapticManager.preloadPatterns()` can parse and cache all 3 patterns from bundled AHAP files.
- [ ] PH-07 (Chapter 1) is unblocked — `play("capacitor_charge")` fires the ramp + snap pattern during long-press.
- [ ] PH-09 (Chapter 3) is unblocked — `play("thud")` fires the heavy transient on cipher lock.
- [ ] PH-13 (Chapter 6) is unblocked — `play("heartbeat")` fires the pulsing pattern during slider drag.
- [ ] PH-16 (on-device QA) has concrete AHAP files to evaluate and tune.
- [ ] Epic ID `ASSET_04` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
