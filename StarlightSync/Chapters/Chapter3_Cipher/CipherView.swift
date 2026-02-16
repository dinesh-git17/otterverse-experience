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
            if showingIntro {
                introCard
                    .transition(.opacity)
            } else {
                VStack(spacing: Ch3Layout.cryptexToUnlockSpacing) {
                    cryptexFrame
                    unlockAction
                }
                .offset(x: shakeOffset)
                .opacity(showVictory ? 0 : 1.0)
                .scaleEffect(victoryScale)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            backgroundImage
                .blur(radius: showingIntro
                    ? Ch3Layout.introBackgroundBlur
                    : Ch3Layout.puzzleBackgroundBlur)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Background

private extension CipherView {
    var backgroundImage: some View {
        Image(GameConstants.BackgroundAsset.cipher.rawValue)
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }
}

// MARK: - Cryptex Frame

private extension CipherView {
    var cryptexFrame: some View {
        VStack(spacing: 0) {
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
        Button(action: handleUnlock) {
            VStack(spacing: Ch3Layout.unlockSpacing) {
                Image(systemName: hasCompleted ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: Ch3Layout.unlockIconSize, weight: .medium))
                    .foregroundStyle(
                        unlockFlash
                            ? AnyShapeStyle(Ch3Color.errorFlash)
                            : AnyShapeStyle(LinearGradient(
                                colors: [Ch3Color.lockGold, Ch3Color.lockGoldDark],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    )

                Text("UNLOCK")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Ch3Color.steelLight)
                    .tracking(Ch3Layout.unlockTracking)
            }
            .frame(minWidth: Ch3Layout.unlockIconSize, minHeight: Ch3Layout.unlockMinTouchHeight)
        }
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
                "Every couple has their inside jokes.\n"
                    + "Crack the code. You know this one.\n\n"
                    + "Britney Spears might jog your memory."
            )
            .font(.system(.subheadline, design: .rounded).weight(.light))
            .foregroundStyle(Ch3Color.introSubtext)
            .tracking(Ch3Layout.introSubtextTracking)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .padding(.top, Ch3Layout.introSubtextTopPadding)

            Button(action: dismissIntro) {
                Text("DECODE")
                    .font(.system(.callout, design: .monospaced).weight(.bold))
                    .foregroundStyle(Ch3Color.introButtonText)
                    .tracking(Ch3Layout.introButtonTracking)
                    .padding(.horizontal, Ch3Layout.introButtonHorizontalPadding)
                    .padding(.vertical, Ch3Layout.introButtonVerticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: Ch3Layout.introButtonCornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [Ch3Color.steelLight, Ch3Color.steelMid],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            }
            .padding(.top, Ch3Layout.introButtonTopPadding)
        }
        .padding(Ch3Layout.introCardPadding)
        .frame(maxWidth: Ch3Layout.introCardMaxWidth)
        .background(
            RoundedRectangle(cornerRadius: Ch3Layout.introCardCornerRadius)
                .fill(Ch3Color.introCardFill.opacity(Ch3Layout.introCardBackgroundOpacity))
                .blur(radius: Ch3Layout.introCardBlurRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Ch3Layout.introCardCornerRadius)
                .strokeBorder(
                    Ch3Color.steelLight.opacity(Ch3Layout.introCardBorderOpacity),
                    lineWidth: Ch3Layout.introCardBorderWidth
                )
        )
    }

    func dismissIntro() {
        let anim: Animation = reduceMotion
            ? .easeOut(duration: Ch3Anim.introReducedFadeDuration)
            : .spring(
                response: Ch3Anim.introFadeResponse,
                dampingFraction: Ch3Anim.introFadeDamping
            )
        withAnimation(anim) {
            showingIntro = false
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
        AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxChime.rawValue)

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
