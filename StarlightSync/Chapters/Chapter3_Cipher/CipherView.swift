import SwiftUI

// MARK: - Validation Logic (Unit-Testable without SwiftUI)

enum CipherValidation {
    static func isAllCorrect(selections: [Int], answers: [Int]) -> Bool {
        guard selections.count == answers.count else { return false }
        return zip(selections, answers).allSatisfy { $0 == $1 }
    }
}

// MARK: - CipherView

struct CipherView: View {
    @Environment(FlowCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var wheel1Selection: Int
    @State private var wheel2Selection: Int
    @State private var wheel3Selection: Int
    @State private var incorrectAttempts = 0
    @State private var hasCompleted = false
    @State private var shakeOffset: CGFloat = 0
    @State private var showVictory = false
    @State private var unlockFlash = false
    @State private var showingIntro = true

    // Transition State
    @State private var introScale: CGFloat = 1.0
    @State private var introOpacity: Double = 1.0
    @State private var puzzleScale: CGFloat = Ch3Anim.puzzleEntryScaleStart
    @State private var puzzleOpacity: Double = 0.0

    init() {
        _wheel1Selection = State(initialValue: Self.randomStart(
            excluding: Ch3Puzzle.wheel1Answer,
            count: Ch3Puzzle.wheel1Segments.count
        ))
        _wheel2Selection = State(initialValue: Self.randomStart(
            excluding: Ch3Puzzle.wheel2Answer,
            count: Ch3Puzzle.wheel2Segments.count
        ))
        _wheel3Selection = State(initialValue: Self.randomStart(
            excluding: Ch3Puzzle.wheel3Answer,
            count: Ch3Puzzle.wheel3Segments.count
        ))
    }

    private var isAutoAssistActive: Bool {
        incorrectAttempts >= GameConstants.AutoAssist.cipherIncorrectThreshold
    }

    private var victoryScale: CGFloat {
        if reduceMotion { return 1.0 }
        return showVictory ? Ch3Layout.victoryExitScale : 1.0
    }

    var body: some View {
        ZStack {
            // Puzzle Layer
            VStack(spacing: Ch3Layout.cryptexToUnlockSpacing) {
                cryptexFrame
                unlockAction
            }
            .offset(x: shakeOffset)
            .scaleEffect(showVictory ? victoryScale : puzzleScale)
            .opacity(showVictory ? 0 : puzzleOpacity)

            // Intro Layer
            if showingIntro {
                introCard
                    .scaleEffect(introScale)
                    .opacity(introOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                backgroundImage
                    .blur(radius: showingIntro ? Ch3Layout.introBackgroundBlur : 0)
                    .animation(.easeOut(duration: Ch3Anim.introExitDuration), value: showingIntro)

                // Vignette
                RadialGradient(
                    colors: [.clear, Ch3Color.vignetteColor],
                    center: .center,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Cryptex Frame

private extension CipherView {
    var backgroundImage: some View {
        Image(GameConstants.BackgroundAsset.cipher.rawValue)
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }

    var cryptexFrame: some View {
        VStack(spacing: showVictory ? 40 : 0) {
            metalEdge
            CipherWheelView(
                segments: Ch3Puzzle.wheel1Segments,
                correctIndex: Ch3Puzzle.wheel1Answer,
                selectedIndex: $wheel1Selection,
                showHint: isAutoAssistActive
            )
            metalDivider
            CipherWheelView(
                segments: Ch3Puzzle.wheel2Segments,
                correctIndex: Ch3Puzzle.wheel2Answer,
                selectedIndex: $wheel2Selection,
                showHint: isAutoAssistActive
            )
            metalDivider
            CipherWheelView(
                segments: Ch3Puzzle.wheel3Segments,
                correctIndex: Ch3Puzzle.wheel3Answer,
                selectedIndex: $wheel3Selection,
                showHint: isAutoAssistActive
            )
            metalEdge
        }
        .frame(width: Ch3Layout.frameWidth)
        .background(frameGradient)
        .clipShape(RoundedRectangle(cornerRadius: Ch3Layout.frameCornerRadius))
        .overlay(frameInnerShadow)
        .overlay(specularLine)
    }

    var metalEdge: some View {
        LinearGradient(
            colors: [Ch3Color.steelLight, Ch3Color.steelMid, Ch3Color.steelDark],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: Ch3Layout.metalEdgeHeight)
    }

    var metalDivider: some View {
        Ch3Color.divider
            .frame(height: Ch3Layout.dividerHeight)
            .padding(.horizontal, Ch3Layout.dividerHorizontalPadding)
            .opacity(showVictory ? 0 : 1)
    }

    var frameGradient: some View {
        LinearGradient(
            colors: [Ch3Color.steelDark, Ch3Color.steelDeep, Ch3Color.steelDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var frameInnerShadow: some View {
        RoundedRectangle(cornerRadius: Ch3Layout.frameCornerRadius)
            .strokeBorder(Ch3Color.innerShadow, lineWidth: Ch3Layout.innerShadowLineWidth)
            .shadow(
                color: Ch3Color.innerShadow.opacity(Ch3Layout.innerShadowOpacity),
                radius: Ch3Layout.innerShadowRadius,
                x: 0,
                y: Ch3Layout.innerShadowYOffset
            )
    }

    var specularLine: some View {
        VStack {
            Ch3Color.specularHighlight.opacity(Ch3Layout.specularOpacity)
                .frame(height: Ch3Layout.specularLineHeight)
                .padding(.horizontal, Ch3Layout.specularHorizontalPadding)
                .padding(.top, Ch3Layout.specularTopPadding)
            Spacer()
        }
        .clipShape(RoundedRectangle(cornerRadius: Ch3Layout.frameCornerRadius))
    }
}

// MARK: - Unlock Action

private extension CipherView {
    var unlockAction: some View {
        HoldLatchView(
            isLocked: incorrectAttempts > 0 && unlockFlash, // Reuse flash state for "locked" feedback
            onUnlock: handleUnlock
        )
        .disabled(hasCompleted)
    }
}

// MARK: - Intro Card

private extension CipherView {
    var introCard: some View {
        VStack(spacing: Ch3Layout.introCardSpacing) {
            Text("We have our own language")
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundStyle(Ch3Color.introHeadline)
                .tracking(Ch3Layout.introHeadlineTracking)
                .multilineTextAlignment(.center)

            Text(
                "Signal stabilized.\n"
                    + "Decrypting secure channel...\n\n"
                    + "Britney Spears might jog your memory."
            )
            .font(.system(.subheadline, design: .rounded).weight(.regular))
            .foregroundStyle(Ch3Color.introSubtext)
            .tracking(Ch3Layout.introSubtextTracking)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .padding(.top, Ch3Layout.introSubtextTopPadding)

            Button(action: dismissIntro) {
                Text("DECODE")
                    .font(.system(.callout, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                    .tracking(Ch3Layout.introButtonTracking)
                    .padding(.horizontal, 40)
                    .padding(.vertical, Ch3Layout.introButtonVerticalPadding)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: Ch3Layout.introButtonCornerRadius)
                                .fill(
                                    LinearGradient(
                                        colors: [Ch3Color.buttonGradientStart, Ch3Color.buttonGradientEnd],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            RoundedRectangle(cornerRadius: Ch3Layout.introButtonCornerRadius)
                                .strokeBorder(Ch3Color.buttonBorder, lineWidth: 1)
                        }
                    )
                    .shadow(color: Ch3Color.buttonGlow, radius: 15)
            }
            .padding(.top, Ch3Layout.introButtonTopPadding)
        }
        .padding(Ch3Layout.introCardPadding)
        .frame(maxWidth: Ch3Layout.introCardMaxWidth)
        .background(
            RoundedRectangle(cornerRadius: Ch3Layout.introCardCornerRadius)
                .fill(Ch3Color.cardGlassFill)
                .background(
                    RoundedRectangle(cornerRadius: Ch3Layout.introCardCornerRadius)
                        .blur(radius: 20) // Deep ambient shadow behind glass
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Ch3Layout.introCardCornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [Ch3Color.cardBorderTop, Ch3Color.cardBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: Ch3Layout.introCardBorderWidth
                )
        )
        .shadow(color: Ch3Color.cardShadow, radius: Ch3Layout.introShadowRadius, y: Ch3Layout.introShadowY)
    }

    func dismissIntro() {
        if reduceMotion {
            // Simple cross-fade for Reduced Motion
            withAnimation(.easeOut(duration: 0.5)) {
                introOpacity = 0
                puzzleOpacity = 1
                showingIntro = false
            }
        } else {
            // Orchestrated Cinematic Transition

            // 1. Intro Exits (Scales UP towards camera + Fades Out)
            withAnimation(.easeIn(duration: Ch3Anim.introExitDuration)) {
                introScale = Ch3Anim.introScaleTarget
                introOpacity = 0
            }

            // 2. Puzzle Enters (Scales UP from distance + Fades In)
            // Uses snappy spring for immediate responsiveness
            withAnimation(.spring(
                response: Ch3Anim.puzzleEntryResponse,
                dampingFraction: Ch3Anim.puzzleEntryDamping
            ).delay(Ch3Anim.puzzleEntryDelay)) {
                puzzleScale = 1.0
                puzzleOpacity = 1.0
            }

            // 3. Cleanup
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Ch3Anim.introExitDuration))
                showingIntro = false
            }
        }
    }
}

// MARK: - Interaction Logic

private extension CipherView {
    func handleUnlock() {
        guard !hasCompleted else { return }

        let selections = [wheel1Selection, wheel2Selection, wheel3Selection]
        let answers = [Ch3Puzzle.wheel1Answer, Ch3Puzzle.wheel2Answer, Ch3Puzzle.wheel3Answer]

        if CipherValidation.isAllCorrect(selections: selections, answers: answers) {
            handleWin()
        } else {
            handleIncorrect()
        }
    }

    func handleWin() {
        hasCompleted = true
        // Use Thud sound (unlock) instead of Chime
        AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxThud.rawValue)

        let anim: Animation = reduceMotion
            ? .easeOut(duration: Ch3Anim.victoryReducedDuration)
            : .easeIn(duration: Ch3Anim.victoryDuration)

        withAnimation(anim) {
            showVictory = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Ch3Timing.victoryTransitionMs))
            coordinator.completeCurrentChapter()
        }
    }

    func handleIncorrect() {
        incorrectAttempts += 1
        AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxError.rawValue)
        HapticManager.shared.playTransientEvent(
            intensity: Ch3Haptic.errorIntensity,
            sharpness: Ch3Haptic.errorSharpness
        )

        if reduceMotion {
            flashUnlockIndicator()
        } else {
            shakeCryptexFrame()
            flashUnlockIndicator()
        }
    }

    func shakeCryptexFrame() {
        withAnimation(.spring(
            response: Ch3Anim.shakeResponse,
            dampingFraction: Ch3Anim.shakeDamping
        )) {
            shakeOffset = Ch3Layout.shakeDistance
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Ch3Timing.shakeResetDelayMs))
            withAnimation(.spring(
                response: Ch3Anim.shakeResponse,
                dampingFraction: Ch3Anim.shakeDamping
            )) {
                shakeOffset = 0
            }
        }
    }

    func flashUnlockIndicator() {
        unlockFlash = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Ch3Timing.flashResetDelayMs))
            unlockFlash = false
        }
    }

    static func randomStart(excluding correctIndex: Int, count: Int) -> Int {
        var index: Int
        repeat {
            index = Int.random(in: 0 ..< count)
        } while index == correctIndex
        return index
    }
}

// MARK: - Preview

#Preview {
    CipherView()
        .environment(FlowCoordinator())
}
