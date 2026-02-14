# SwiftUI Chapter Template

Deterministic output structure for SwiftUI-based chapters (1, 3, 5, 6).

## File: `{Name}View.swift`

```swift
import SwiftUI

struct {Name}View: View {

    // MARK: - Dependencies

    var coordinator: FlowCoordinator

    // MARK: - Local State

    @State private var {chapterSpecificState}: {Type} = {defaultValue}
    @State private var autoAssistActive = false      // Chapters 2-5 only
    @State private var failureCount = 0               // Auto-Assist trigger tracking

    // MARK: - Accessibility

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        // <= 80 lines. Extract sub-views if approaching limit.
        ZStack {
            // Background layer
            {backgroundContent}

            // Interactive layer
            {interactionContent}

            // Feedback layer (haptic/audio triggers)
            {feedbackOverlay}
        }
        .onAppear {
            // Preload chapter-specific assets if needed
        }
    }

    // MARK: - Sub-Views (extracted to keep body <= 80 lines)

    private var {backgroundContent}: some View {
        // Chapter-specific background
    }

    private var {interactionContent}: some View {
        // Core mechanic interaction surface
    }

    // MARK: - Win Condition

    private func evaluateWinCondition() {
        // Check against GameConstants threshold
        // guard {condition} else { return }
        // coordinator.completeChapter({N})
    }

    // MARK: - Auto-Assist (Chapters 2-5 only)

    private func recordFailure() {
        failureCount += 1
        if failureCount >= GameConstants.Chapter{N}.autoAssistThreshold {
            activateAutoAssist()
        }
    }

    private func activateAutoAssist() {
        guard !autoAssistActive else { return }
        autoAssistActive = true
        // Apply mechanism silently — no user-facing indication
    }

    // MARK: - Animation Helpers

    private func animateWithMotionCheck(
        _ animation: Animation?,
        body: @escaping () -> Void
    ) {
        if reduceMotion {
            body()
        } else {
            withAnimation(animation) {
                body()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    {Name}View(coordinator: FlowCoordinator())
}
```

## Structural Rules

1. **Single responsibility.** One primary view per file. File name matches type name.
2. **Body limit.** If `body` approaches 80 lines, extract computed view properties.
3. **State flow.** `FlowCoordinator` injected as a parameter. No environment injection of coordinator.
4. **No cross-chapter imports.** Only import `SwiftUI` and project-level shared modules.
5. **Named constants.** All numeric thresholds reference `GameConstants.Chapter{N}.*`.
6. **Reduce Motion.** Every `withAnimation` call must have a `reduceMotion` guard.

## Sub-Component Files

If a chapter requires extracted sub-views (e.g., `CipherWheelView`, `FrictionSlider`, `HeartNodeLayout`):

```swift
import SwiftUI

struct {SubComponent}View: View {

    // Minimal state — data flows down from parent
    let {inputProp}: {Type}
    var on{Event}: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // <= 80 lines
    }
}

#Preview {
    {SubComponent}View({inputProp}: {previewValue})
}
```

Sub-components:

- Live in the same chapter directory as the parent view
- Accept data via `let` properties (read-only flow)
- Report events via closures (not by mutating coordinator directly)
- Include their own `#Preview` macro
