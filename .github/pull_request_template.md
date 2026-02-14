## Summary

<!-- One-paragraph description of what this PR accomplishes and why. -->

## Design Doc Reference

<!-- Link the specific Design-Doc.md section(s) this change implements or aligns with. -->
<!-- Example: Design-Doc.md §3.3 (Chapter 2 — Packet Run), §7.3 (Sprite Assets) -->

- **Section(s):** `Design-Doc.md §`

## Architectural Impact

<!-- Describe which component boundaries (CLAUDE.md §3.3) this change touches. -->
<!-- If this modifies FlowCoordinator, a Manager, or WebhookService, explain the scope. -->

- **Components modified:**
- **Cross-boundary access introduced:** None / Describe
- **New files created:** None / List with justification

## Changes

<!-- Bulleted list of concrete changes. Be specific — "Add obstacle spawning" not "Update game." -->

-

## Governance Compliance

<!-- Every box must be checked before merge. Reference: CLAUDE.md §10 (Definition of Done). -->

- [ ] Aligns with `Design-Doc.md` architecture
- [ ] Uses `@Observable` — no `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject`
- [ ] No Combine, no GCD (`DispatchQueue`), no `performSelector`
- [ ] No third-party dependencies introduced
- [ ] No force unwraps (`!`) outside Apple-API-required locations
- [ ] No `print` statements — uses `os.Logger` gated behind `#if DEBUG`
- [ ] No magic numbers — all tuning values in `GameConstants`
- [ ] No deprecated APIs (`ObservableObject`, `PreviewProvider`, `UIApplicationDelegate` lifecycle)
- [ ] Protocol Zero: no AI attribution artifacts in code, comments, or commit messages
- [ ] Conventional Commits format: `type(scope): imperative description`

## SwiftUI Compliance

<!-- Check all that apply. Skip if PR contains no SwiftUI changes. -->

- [ ] All SwiftUI view files include `#Preview` macro
- [ ] No view body exceeds 80 lines
- [ ] Animations respect `UIAccessibility.isReduceMotionEnabled` with fallback
- [ ] Chapter-specific colors/curves — no cross-chapter reuse of visual identity
- [ ] No default system colors as primary chapter elements

## SpriteKit Compliance

<!-- Check all that apply. Skip if PR contains no SpriteKit changes. -->

- [ ] `willMove(from:)` overridden with deterministic cleanup order
- [ ] `SpriteView` wrapper uses optional scene pattern with `.onDisappear` nil-out
- [ ] `preferredFramesPerSecond = 120` set in `didMove(to:)` and wrapper
- [ ] Physics uses `SKPhysicsBody` category bitmasks — no frame-by-frame distance checks
- [ ] All `SKAction.run` closures capture `[weak self]`
- [ ] Delta time from `update(_:)` used for movement/spawning — no frame-count binding

## Engine Lifecycle Compliance

<!-- Check all that apply. Skip if PR does not touch AudioManager or HapticManager. -->

- [ ] `CHHapticEngine` implements `stoppedHandler` and `resetHandler`
- [ ] Haptic/audio failure does not propagate to UI or block chapter progression
- [ ] `AVAudioSession` category is `.playback` — set once at launch
- [ ] Interruption handlers registered and pause/resume game state
- [ ] `CACurrentMediaTime()` used for timing — no `Timer`, `Task.sleep`, or `DispatchQueue`

## Security

<!-- Check all that apply. Skip if PR has no network or secret-adjacent changes. -->

- [ ] No plaintext webhook URLs in source, comments, tests, or docs
- [ ] Webhook URL stored as XOR-encoded `[UInt8]` byte array
- [ ] Webhook execution is fire-and-forget — does not block UI or gate Chapter 6
- [ ] No `.env` files, provisioning profiles, or plaintext secrets introduced
- [ ] `scripts/audit.py --staged` passes with zero violations

## Test Coverage

- [ ] Unit tests added or updated for changed logic
- [ ] Test names follow `test_<unit>_<scenario>_<expectedResult>()` convention
- [ ] No real network calls — `URLProtocol` stubs used
- [ ] No `UserDefaults.standard` — test-scoped suite injected
- [ ] All tests pass: `xcodebuild test` returns 0 failures

## Reviewer Notes

<!-- Anything the reviewer should pay special attention to. -->
<!-- Flag: tuning values that need on-device validation, visual changes needing screenshot review, etc. -->
