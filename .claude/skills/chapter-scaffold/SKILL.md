---
name: chapter-scaffold
description: Generate deterministic chapter implementations (SwiftUI views or SpriteKit scene wrappers) conforming to the FlowCoordinator pattern, chapter isolation rules, Auto-Assist specification, and coordinator integration boundaries. Use when a new chapter is requested, a chapter scaffold is needed, game mechanics or chapter scenes are implemented, or SwiftUI chapter views are generated. Triggers on chapter creation, chapter scaffold, chapter implementation, game mechanic implementation, or scene generation requests.
---

# Chapter Scaffold

Generate chapter implementations that enforce the Flow Coordinator architecture, chapter isolation boundaries, Auto-Assist compliance, and win condition encoding defined in `Design-Doc.md`.

## Pre-Scaffold Verification

Before generating any chapter code, verify:

1. The requested chapter number (1–6) exists in `Design-Doc.md` §3.
2. The chapter type (SwiftUI or SpriteKit) matches the design doc specification.
3. No existing implementation conflicts with the scaffold target.

If any verification fails, **HALT** and cite the specific conflict.

## Chapter Type Matrix

| Chapter | Name          | Type      | View File                | Scene File             | Auto-Assist |
| ------- | ------------- | --------- | ------------------------ | ---------------------- | ----------- |
| 1       | Handshake     | SwiftUI   | `HandshakeView.swift`    | —                      | No          |
| 2       | Packet Run    | SpriteKit | `PacketRunView.swift`    | `PacketRunScene.swift` | Yes         |
| 3       | Cipher        | SwiftUI   | `CipherView.swift`       | —                      | Yes         |
| 4       | Firewall      | SpriteKit | `FirewallView.swift`     | `FirewallScene.swift`  | Yes         |
| 5       | Blueprint     | SwiftUI   | `BlueprintView.swift`    | —                      | Yes         |
| 6       | Event Horizon | SwiftUI   | `EventHorizonView.swift` | —                      | No          |

## Workflow

### Step 1: Determine Chapter Type

Identify whether the target chapter requires:

- **SwiftUI-only scaffold** (Chapters 1, 3, 5, 6) — use [assets/swiftui-chapter-template.md](assets/swiftui-chapter-template.md)
- **SpriteKit + SwiftUI wrapper scaffold** (Chapters 2, 4) — use [assets/spritekit-chapter-template.md](assets/spritekit-chapter-template.md)

### Step 2: Apply Coordinator Integration Rules

Every chapter implementation MUST follow these integration constraints:

**State access:** Chapter reads state from `FlowCoordinator` only. No direct `UserDefaults` access. No direct service calls.

**Completion reporting:** Chapter reports completion exclusively through `FlowCoordinator.completeChapter(_:)`. No alternative completion paths.

**Manager access:** Audio and haptic feedback triggered via `AudioManager` and `HapticManager` singletons. Chapter views do not instantiate or configure these managers.

**Boundary matrix enforcement:**

| Component    | May Access                                        | MUST NOT Access                                 |
| ------------ | ------------------------------------------------- | ----------------------------------------------- |
| Chapter View | `FlowCoordinator` (read state, report completion) | `UserDefaults`, `URLSession`, other chapters    |
| `SKScene`    | `FlowCoordinator` (report completion only)        | `UserDefaults`, `URLSession`, managers directly |

### Step 3: Encode Win Condition

Each chapter MUST encode its win condition as a deterministic state transition. Reference [references/architecture-rules.md](references/architecture-rules.md) for the complete win condition table.

| Chapter | Win Condition                                       |
| ------- | --------------------------------------------------- |
| 1       | 3-second long-press completed                       |
| 2       | Survive 60 seconds OR collect 20 hearts             |
| 3       | All three cipher wheels aligned to correct segments |
| 4       | Survive song verse duration (~45s)                  |
| 5       | All 12 nodes connected completing the heart shape   |
| 6       | Friction slider reaches 100%                        |

Win condition evaluation MUST:

- Use named constants from `GameConstants` (no magic numbers)
- Trigger coordinator completion callback on satisfaction
- Be testable in isolation (pure logic, no framework dependencies)

### Step 4: Implement Auto-Assist (If Applicable)

Chapters 2, 3, 4, and 5 require Auto-Assist. Chapters 1 and 6 do not.

Auto-Assist MUST implement the exact trigger/mechanism/effect tuple:

| Chapter | Trigger              | Mechanism                         | Effect                         |
| ------- | -------------------- | --------------------------------- | ------------------------------ |
| 2       | 3 deaths             | Reduce obstacle speed, widen gaps | Speed -20%, Gap width +20%     |
| 3       | 3 incorrect attempts | Highlight correct wheel segment   | Subtle glow on correct segment |
| 4       | 5 misses             | Widen hit window                  | +/-150ms -> +/-300ms           |
| 5       | 10s idle             | Pulse next correct node           | Glow animation on target node  |

**Frozen thresholds.** These values are immutable. Do not parameterize or make configurable. Define as named constants in `GameConstants`.

Auto-Assist activation MUST:

- Track the trigger count as `@Observable` state
- Apply the mechanism silently (no user-facing "assist activated" message)
- Preserve the illusion of skill — lower difficulty without breaking immersion

### Step 5: Apply SwiftUI Structural Constraints

Every SwiftUI view in the scaffold MUST satisfy:

1. **View body <= 80 lines.** Extract sub-views into separate computed properties or child views.
2. **`#Preview` macro.** Every SwiftUI view file includes a `#Preview` block. No `PreviewProvider` structs.
3. **`@Observable` only.** No `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject`.
4. **No Combine.** No `import Combine`. No `Publisher`. No `sink`.
5. **No GCD.** No `DispatchQueue`. Use `async/await` and `@MainActor`.
6. **Reduce Motion.** All animations MUST check `UIAccessibility.isReduceMotionEnabled` and provide a non-animated fallback.
7. **No force unwraps.** Use `guard let` or `if let` for all optionals.
8. **No magic numbers.** All tuning values defined in `GameConstants`.
9. **No print statements.** Use `os.Logger` gated behind `#if DEBUG` if needed.

### Step 6: Apply SpriteKit Constraints (Chapters 2, 4 Only)

SpriteKit scenes MUST satisfy:

1. **`willMove(from:)` cleanup.** Call `removeAllChildren()`, `removeAllActions()`, invalidate timers.
2. **Physics via bitmasks.** Use `SKPhysicsBody` category bitmasks. No frame-by-frame distance checks.
3. **120fps target.** Set `preferredFramesPerSecond = 120`.
4. **Memory safety.** When `SpriteView` leaves the hierarchy, set scene reference to `nil`.
5. **SpriteView wrapper.** The SwiftUI wrapper uses `SpriteView(scene:)` and manages scene lifecycle via `.onDisappear`.

### Step 7: Enforce Isolation

**File placement:**

```
Chapters/
  Chapter{N}_{Name}/
    {Name}View.swift          # SwiftUI view (all chapters)
    {Name}Scene.swift         # SKScene subclass (chapters 2, 4 only)
    {SubComponent}View.swift  # Extracted sub-views (if body exceeds 80 lines)
```

**Import rules:**

- Chapter files MUST NOT import from other chapter directories
- Shared components used by 2+ chapters live in `Components/`
- Only approved shared modules: `GameConstants`, `AudioManager`, `HapticManager`, `FlowCoordinator`

### Step 8: Generate Output

Produce the chapter files following the appropriate template. Every generated file MUST include:

- File-level `import` statements (only required frameworks)
- Type declaration matching file name
- Coordinator integration points
- Win condition logic
- Auto-Assist logic (if applicable)
- `#Preview` macro (SwiftUI files)
- Scene cleanup (SpriteKit files)

### Step 9: Post-Generation Validation

After generating chapter code, verify against the checklist:

- [ ] File placed in `Chapters/Chapter{N}_{Name}/`
- [ ] No imports from other chapter directories
- [ ] `FlowCoordinator` is the sole external state dependency
- [ ] Win condition uses `GameConstants` named constants
- [ ] Auto-Assist thresholds match frozen values exactly
- [ ] View body does not exceed 80 lines
- [ ] `#Preview` macro present on all SwiftUI views
- [ ] `willMove(from:)` cleanup present on all `SKScene` subclasses
- [ ] No force unwraps, no Combine, no GCD, no print statements
- [ ] Reduce Motion accessibility respected in all animations
- [ ] No third-party dependencies
- [ ] No deprecated APIs (`ObservableObject`, `@Published`, `PreviewProvider`)

If any check fails, fix before declaring the scaffold complete.

## Anti-Patterns (Reject These)

- **Direct UserDefaults access from chapter views.** State flows through `FlowCoordinator` only.
- **Cross-chapter imports.** Chapter directories are isolated silos.
- **Hardcoded thresholds.** All numeric values belong in `GameConstants`.
- **Skip buttons or explicit assist UI.** Auto-Assist is invisible to the player.
- **ObservableObject or @Published.** Use `@Observable` exclusively.
- **View body exceeding 80 lines.** Extract sub-views.
- **Missing #Preview.** Every SwiftUI file must be previewable.
- **Missing scene cleanup.** `SKScene` must clean up in `willMove(from:)`.
- **Timer or DispatchQueue for audio timing.** Use `CACurrentMediaTime()`.
- **Combine publishers for state.** Use Observation framework.

## Resources

- **SwiftUI Template**: See [assets/swiftui-chapter-template.md](assets/swiftui-chapter-template.md) for the deterministic SwiftUI chapter structure
- **SpriteKit Template**: See [assets/spritekit-chapter-template.md](assets/spritekit-chapter-template.md) for the deterministic SpriteKit chapter structure
- **Architecture Rules**: See [references/architecture-rules.md](references/architecture-rules.md) for the complete boundary matrix and frozen thresholds
