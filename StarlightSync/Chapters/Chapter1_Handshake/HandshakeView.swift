import SwiftUI

struct HandshakeView: View {
    @Environment(FlowCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPressing = false
    @State private var pressStartDate: Date?
    @State private var frozenProgress: CGFloat = 0
    @State private var isCompleted = false
    @State private var showCRTTransition = false
    @State private var pulseActive = false
    @State private var instructionRevealed = false
    @State private var instructionGlowActive = false

    private static let ch1NeonPurple = Color(red: 0.58, green: 0.15, blue: 1.0)
    private static let glyphScreenRatio: CGFloat = 0.52
    private static let ringScreenRatio: CGFloat = 0.72
    private static let ringLineWidth: CGFloat = 5
    private static let maxFingerDrift: CGFloat = 60
    private static let glyphMinOpacity: CGFloat = 0.05
    private static let glyphMaxOpacity: CGFloat = 0.12
    private static let pulseMinScale: CGFloat = 0.97
    private static let pulseMaxScale: CGFloat = 1.03
    private static let pulseDuration: TimeInterval = 2.2
    private static let progressResetDuration: TimeInterval = 0.3
    private static let staticGlowOpacity: CGFloat = 0.08
    private static let ringOpacityFactor: CGFloat = 0.7

    private static let instructionDelay: TimeInterval = 1.2
    private static let instructionFadeIn: TimeInterval = 1.0
    private static let instructionDrift: CGFloat = 10
    private static let instructionFontSize: CGFloat = 12
    private static let instructionTracking: CGFloat = 7.0
    private static let instructionDimOpacity: CGFloat = 0.35
    private static let instructionBrightOpacity: CGFloat = 0.7
    private static let instructionGlowDuration: TimeInterval = 2.6
    private static let instructionPressFade: TimeInterval = 0.25
    private static let instructionBottomPadding: CGFloat = 72
    private static let instructionGlowInner: CGFloat = 4
    private static let instructionGlowMid: CGFloat = 12
    private static let instructionGlowOuter: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            ZStack {
                TimelineView(
                    .animation(minimumInterval: nil, paused: !isPressing)
                ) { context in
                    let progress = currentProgress(at: context.date)
                    glyphWithRing(
                        progress: min(progress, 1.0),
                        screenWidth: screenWidth
                    )
                    .onChange(of: progress >= 1.0) { _, reachedEnd in
                        if reachedEnd { handleGestureComplete() }
                    }
                }

                VStack {
                    Spacer()
                    instructionLabel
                        .opacity(isPressing || isCompleted ? 0 : 1)
                        .animation(
                            .easeInOut(duration: Self.instructionPressFade),
                            value: isPressing
                        )
                        .padding(.bottom, Self.instructionBottomPadding)
                }

                if showCRTTransition {
                    CRTTransitionView(
                        isActive: $showCRTTransition,
                        onComplete: handleTransitionComplete
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { backgroundLayer }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in handleDragChanged(value) }
                .onEnded { _ in handleDragEnded() }
        )
        .disabled(isCompleted)
        .onAppear { pulseActive = true }
        .task {
            try? await Task.sleep(for: .seconds(Self.instructionDelay))
            guard !Task.isCancelled else { return }
            withAnimation(
                .timingCurve(0.25, 0.1, 0.25, 1.0, duration: Self.instructionFadeIn)
            ) {
                instructionRevealed = true
            }
            try? await Task.sleep(for: .seconds(Self.instructionFadeIn * 0.6))
            guard !Task.isCancelled else { return }
            instructionGlowActive = true
        }
    }
}

// MARK: - Subviews

private extension HandshakeView {
    var backgroundLayer: some View {
        ZStack {
            Color(red: 0, green: 0, blue: 0)
            Image(GameConstants.BackgroundAsset.intro.rawValue)
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
        .ignoresSafeArea()
    }

    func glyphWithRing(progress: CGFloat, screenWidth: CGFloat) -> some View {
        let glyphSize = screenWidth * Self.glyphScreenRatio
        let ringDiameter = screenWidth * Self.ringScreenRatio

        return ZStack {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Self.ch1NeonPurple.opacity(Self.ringOpacityFactor),
                    style: StrokeStyle(lineWidth: Self.ringLineWidth, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .rotationEffect(.degrees(-90))

            Image(systemName: "touchid")
                .font(.system(size: glyphSize, weight: .ultraLight))
                .foregroundStyle(Self.ch1NeonPurple)
                .opacity(glyphOpacity)
                .scaleEffect(glyphScale)
                .animation(pulseAnimation, value: pulseActive)
        }
    }

    var instructionLabel: some View {
        Text("hold  to  connect")
            .font(.system(size: Self.instructionFontSize, weight: .regular, design: .monospaced))
            .tracking(Self.instructionTracking)
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .opacity(instructionTextOpacity)
            .shadow(color: .white.opacity(0.5), radius: Self.instructionGlowInner)
            .shadow(color: Self.ch1NeonPurple.opacity(0.6), radius: Self.instructionGlowMid)
            .shadow(color: Self.ch1NeonPurple.opacity(0.25), radius: Self.instructionGlowOuter)
            .offset(y: instructionRevealed ? 0 : Self.instructionDrift)
            .animation(instructionGlowAnimation, value: instructionGlowActive)
    }

    var instructionTextOpacity: CGFloat {
        guard instructionRevealed else { return 0 }
        if reduceMotion { return Self.instructionBrightOpacity }
        return instructionGlowActive ? Self.instructionBrightOpacity : Self.instructionDimOpacity
    }

    var instructionGlowAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return .timingCurve(0.4, 0, 0.6, 1, duration: Self.instructionGlowDuration)
            .repeatForever(autoreverses: true)
    }

    var glyphOpacity: CGFloat {
        reduceMotion
            ? Self.staticGlowOpacity
            : (pulseActive ? Self.glyphMaxOpacity : Self.glyphMinOpacity)
    }

    var glyphScale: CGFloat {
        reduceMotion
            ? 1.0
            : (pulseActive ? Self.pulseMaxScale : Self.pulseMinScale)
    }

    var pulseAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return .timingCurve(0.35, 0, 0.35, 1, duration: Self.pulseDuration)
            .repeatForever(autoreverses: true)
    }
}

// MARK: - Interaction Logic

private extension HandshakeView {
    func currentProgress(at date: Date) -> CGFloat {
        if isPressing, let start = pressStartDate {
            let elapsed = date.timeIntervalSince(start)
            return min(
                CGFloat(elapsed / GameConstants.Timing.handshakeHoldDuration),
                1.0
            )
        }
        return frozenProgress
    }

    func handleDragChanged(_ value: DragGesture.Value) {
        guard !isCompleted else { return }
        let distance = hypot(value.translation.width, value.translation.height)
        if distance > Self.maxFingerDrift {
            if isPressing { captureAndResetProgress() }
            return
        }
        guard !isPressing else { return }
        isPressing = true
        pressStartDate = Date()
        HapticManager.shared.play(GameConstants.HapticAsset.capacitorCharge.rawValue)
    }

    func handleDragEnded() {
        guard !isCompleted, isPressing else { return }
        captureAndResetProgress()
    }

    func captureAndResetProgress() {
        let captured: CGFloat
        if let start = pressStartDate {
            let elapsed = Date().timeIntervalSince(start)
            captured = min(
                CGFloat(elapsed / GameConstants.Timing.handshakeHoldDuration),
                1.0
            )
        } else {
            captured = 0
        }
        isPressing = false
        pressStartDate = nil

        HapticManager.shared.stopCurrentPattern()
        if captured > 0.05 {
            HapticManager.shared.playTransientEvent(
                intensity: Float(min(captured + 0.3, 1.0)),
                sharpness: 0.9
            )
        }

        frozenProgress = captured
        withAnimation(.easeOut(duration: Self.progressResetDuration)) {
            frozenProgress = 0
        }
    }

    func handleGestureComplete() {
        guard !isCompleted else { return }
        isCompleted = true
        isPressing = false
        pressStartDate = nil
        frozenProgress = 1.0
        HapticManager.shared.stopCurrentPattern()
        HapticManager.shared.play(GameConstants.HapticAsset.thud.rawValue)
        AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxThud.rawValue)
        showCRTTransition = true
    }

    func handleTransitionComplete() {
        AudioManager.shared.crossFadeToBGM(named: GameConstants.AudioAsset.bgmMain.rawValue)
        coordinator.completeCurrentChapter()
    }
}

#Preview {
    HandshakeView()
        .environment(FlowCoordinator())
}
