import SwiftUI

// MARK: - Wheel Layout Constants

private enum WheelLayout {
    static let segmentHeight: CGFloat = 64
    static let visibleCount: Int = 3
    static let viewportHeight: CGFloat = segmentHeight * CGFloat(visibleCount)
    static let wheelWidth: CGFloat = 220
    static let segmentCornerRadius: CGFloat = 6
    static let segmentInternalPadding: CGFloat = 4
}

// MARK: - Wheel Animation Constants

private enum WheelAnim {
    static let springResponse: Double = 0.3
    static let springDamping: Double = 0.7
    static let reducedMotionDuration: Double = 0.15
    static let hintPulseDuration: Double = 1.2
}

// MARK: - Wheel Visual Constants

private enum WheelVisual {
    static let adjacentOpacityFalloff: Double = 0.6
    static let maxRotationDegrees: Double = 45.0
    static let hintGlowOpacity: Double = 0.25
    static let hintGlowRadiusFraction: CGFloat = 0.45
    static let hintProximityRange: CGFloat = 1.2
    static let hintPulseMinFactor: Double = 0.35
    static let centerThreshold: CGFloat = 0.5
}

// MARK: - Wheel Haptic Constants

private enum WheelHaptic {
    static let tickIntensity: Float = 0.5
    static let tickSharpness: Float = 0.8
}

// MARK: - Wheel Colors

private enum WheelColor {
    static let segmentText = Color(red: 0.88, green: 0.90, blue: 0.94)
    static let segmentFill = Color(red: 0.18, green: 0.20, blue: 0.25)
    static let centerFill = Color(red: 0.28, green: 0.31, blue: 0.37)
    static let hintGlow = Color(red: 0.30, green: 0.68, blue: 1.0)
}

// MARK: - CipherWheelView

struct CipherWheelView: View {
    let segments: [String]
    let correctIndex: Int
    @Binding var selectedIndex: Int
    var showHint: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var basePosition: CGFloat
    @State private var dragOffset: CGFloat = 0
    @State private var previousTickIndex: Int
    @State private var isLockedIn: Bool = false

    init(
        segments: [String],
        correctIndex: Int,
        selectedIndex: Binding<Int>,
        showHint: Bool = false
    ) {
        self.segments = segments
        self.correctIndex = correctIndex
        _selectedIndex = selectedIndex
        self.showHint = showHint
        _basePosition = State(initialValue: CGFloat(selectedIndex.wrappedValue))
        _previousTickIndex = State(initialValue: selectedIndex.wrappedValue)
    }

    private var segmentCount: Int {
        segments.count
    }

    private var effectivePosition: CGFloat {
        basePosition - dragOffset / WheelLayout.segmentHeight
    }

    var body: some View {
        ZStack {
            ForEach(0 ..< segmentCount, id: \.self) { index in
                segmentCell(for: index)
            }

            // Cylinder Shadow (Depth Mask)
            VStack {
                LinearGradient(
                    stops: [
                        .init(color: Ch3Color.cylinderShadow, location: 0.0),
                        .init(color: .clear, location: 0.4) // Extended falloff from 0.3
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.6), // Extended start from 0.7
                        .init(color: Ch3Color.cylinderShadow, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)

            LoupeOverlay()
        }
        .frame(width: WheelLayout.wheelWidth, height: WheelLayout.viewportHeight)
        .clipped()
        .contentShape(Rectangle())
        .gesture(wheelDragGesture)
    }
}

// MARK: - Segment Rendering

private extension CipherWheelView {
    func segmentCell(for index: Int) -> some View {
        let diff = wrappedDifference(to: index)
        // Reduced adjacent opacity falloff slightly since shadow handles depth
        let opacity = max(0, 1.0 - abs(diff) * 0.5)
        let rotation = reduceMotion ? 0 : diff * WheelVisual.maxRotationDegrees
        let isCenter = abs(diff) < WheelVisual.centerThreshold
        let isCorrect = index == correctIndex
        let isNearCenter = abs(diff) < WheelVisual.hintProximityRange
        let showGold = isLockedIn && isCorrect && isCenter

        return ZStack {
            if showHint && isCorrect && isNearCenter {
                hintGlowBackground
            }

            // Removed segment background fill to let shadow/gradient work better
            // Kept only for center to highlight selection slightly
            if isCenter {
                RoundedRectangle(cornerRadius: WheelLayout.segmentCornerRadius)
                    .fill(WheelColor.centerFill.opacity(0.3)) // Subtle highlight
                    .frame(height: WheelLayout.segmentHeight - WheelLayout.segmentInternalPadding)
            }

            Text(segments[index])
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(showGold ? Ch3Color.latchActiveFill : WheelColor.segmentText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .animation(.easeOut(duration: 0.2), value: showGold)
        }
        .frame(width: WheelLayout.wheelWidth, height: WheelLayout.segmentHeight)
        .opacity(opacity)
        .rotation3DEffect(.degrees(rotation), axis: (x: 1, y: 0, z: 0))
        .offset(y: diff * WheelLayout.segmentHeight)
    }

    var hintGlowBackground: some View {
        RoundedRectangle(cornerRadius: WheelLayout.segmentCornerRadius)
            .fill(
                RadialGradient(
                    colors: [WheelColor.hintGlow, .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: WheelLayout.wheelWidth * WheelVisual.hintGlowRadiusFraction
                )
            )
            .frame(height: WheelLayout.segmentHeight)
            .opacity(WheelVisual.hintGlowOpacity)
            .modifier(GlowPulseModifier(
                animate: !reduceMotion,
                duration: WheelAnim.hintPulseDuration
            ))
    }
}

// MARK: - Gesture Handling

private extension CipherWheelView {
    var wheelDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isLockedIn = false
                dragOffset = value.translation.height
                let currentIdx = nearestWrappedIndex(for: effectivePosition)
                if currentIdx != previousTickIndex {
                    fireTickFeedback()
                    previousTickIndex = currentIdx
                }
            }
            .onEnded { value in
                // Inertial Physics
                let velocity = value.velocity.height
                let inertia = velocity * Ch3Physics.scrollInertiaFactor
                let projectedOffset = dragOffset + inertia

                // Calculate target based on projected position
                let projectedPosition = basePosition - projectedOffset / WheelLayout.segmentHeight
                let targetIdx = nearestWrappedIndex(for: projectedPosition)
                let snapTarget = closestSnapPosition(for: targetIdx)

                let snapAnim: Animation = reduceMotion
                    ? .easeOut(duration: WheelAnim.reducedMotionDuration)
                    : .spring(
                        response: WheelAnim.springResponse,
                        dampingFraction: WheelAnim.springDamping
                    )

                withAnimation(snapAnim) {
                    basePosition = snapTarget
                    dragOffset = 0
                }
                selectedIndex = targetIdx
                previousTickIndex = targetIdx

                if targetIdx == correctIndex {
                    isLockedIn = true
                    fireThudFeedback()
                }
            }
    }
}

// MARK: - Loupe Overlay

private struct LoupeOverlay: View {
    var body: some View {
        ZStack {
            // Subtle Glass Shine (Top Half)
            LinearGradient(
                stops: [
                    .init(color: Ch3Color.loupeShine, location: 0.0),
                    .init(color: .clear, location: 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.overlay)
            .clipShape(RoundedRectangle(cornerRadius: Ch3Layout.loupeCornerRadius))

            // Horizontal Rails (Machined Look)
            VStack {
                Rectangle()
                    .fill(Ch3Color.loupeBorder)
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Ch3Color.loupeBorder)
                    .frame(height: 1)
            }
        }
        .frame(width: WheelLayout.wheelWidth, height: Ch3Layout.loupeHeight)
        .allowsHitTesting(false) // Let touches pass through to the wheel
    }
}

// MARK: - Position Calculations

private extension CipherWheelView {
    func wrappedDifference(to index: Int) -> CGFloat {
        let count = CGFloat(segmentCount)
        let diff = CGFloat(index) - effectivePosition
        return diff - count * (diff / count).rounded()
    }

    func nearestWrappedIndex(for position: CGFloat) -> Int {
        let rounded = Int(position.rounded())
        return ((rounded % segmentCount) + segmentCount) % segmentCount
    }

    func closestSnapPosition(for targetIndex: Int) -> CGFloat {
        let count = CGFloat(segmentCount)
        let diff = CGFloat(targetIndex) - effectivePosition
        let wrappedDiff = diff - count * (diff / count).rounded()
        return effectivePosition + wrappedDiff
    }
}

// MARK: - Feedback

private extension CipherWheelView {
    func fireTickFeedback() {
        AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxClick.rawValue)
        HapticManager.shared.playTransientEvent(
            intensity: WheelHaptic.tickIntensity,
            sharpness: WheelHaptic.tickSharpness
        )
    }

    func fireThudFeedback() {
        HapticManager.shared.play(GameConstants.HapticAsset.thud.rawValue)
        AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxThud.rawValue)
    }
}

// MARK: - Glow Pulse Modifier

private struct GlowPulseModifier: ViewModifier {
    let animate: Bool
    let duration: Double

    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .opacity(animate ? (phase ? 1.0 : WheelVisual.hintPulseMinFactor) : 1.0)
            .onAppear {
                guard animate else { return }
                withAnimation(
                    .timingCurve(0.4, 0, 0.6, 1, duration: duration)
                        .repeatForever(autoreverses: true)
                ) {
                    phase = true
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.08, green: 0.09, blue: 0.11).ignoresSafeArea()
        CipherWheelView(
            segments: ["ALPHA", "BETA", "GAMMA", "DELTA", "EPSILON"],
            correctIndex: 2,
            selectedIndex: .constant(0),
            showHint: true
        )
    }
}
