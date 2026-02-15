import SwiftUI

struct CRTTransitionView: View {
    @Binding var isActive: Bool
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sweepScale: CGFloat = 0.003
    @State private var contentOpacity: CGFloat = 0
    @State private var scanlineAlpha: CGFloat = 0

    // MARK: - View-Internal Timing

    private let sweepDuration: TimeInterval = 0.6
    private let contentFadeDuration: TimeInterval = 0.4
    private let contentFadeDelay: TimeInterval = 0.1
    private let scanlineFadeDuration: TimeInterval = 0.5
    private let reducedMotionDuration: TimeInterval = 0.4
    private let scanlineSpacing: CGFloat = 3
    private let scanlineBarHeight: CGFloat = 1
    private let scanlineBarOpacity: CGFloat = 0.08

    var body: some View {
        ZStack {
            Color.white
                .opacity(contentOpacity)
                .scaleEffect(y: sweepScale)

            if !reduceMotion {
                scanlineOverlay
                    .opacity(scanlineAlpha)
                    .scaleEffect(y: sweepScale)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: beginTransition)
    }
}

// MARK: - Subviews

private extension CRTTransitionView {
    var scanlineOverlay: some View {
        Canvas { context, size in
            let spacing = scanlineSpacing
            let barHeight = scanlineBarHeight
            let barOpacity = scanlineBarOpacity
            var scanY: CGFloat = 0
            while scanY < size.height {
                let rect = CGRect(x: 0, y: scanY, width: size.width, height: barHeight)
                context.fill(Path(rect), with: .color(.black.opacity(barOpacity)))
                scanY += spacing
            }
        }
        .blendMode(.overlay)
    }
}

// MARK: - Transition Logic

private extension CRTTransitionView {
    func beginTransition() {
        if reduceMotion {
            withAnimation(.easeInOut(duration: reducedMotionDuration)) {
                contentOpacity = 1.0
            } completion: {
                onComplete()
            }
        } else {
            let curve = Animation.timingCurve(0.65, 0, 0.15, 1, duration: sweepDuration)
            withAnimation(curve) {
                sweepScale = 1.0
            } completion: {
                onComplete()
            }
            withAnimation(.easeIn(duration: contentFadeDuration).delay(contentFadeDelay)) {
                contentOpacity = 1.0
            }
            withAnimation(.easeIn(duration: scanlineFadeDuration)) {
                scanlineAlpha = 1.0
            }
        }
    }
}

#Preview("CRT Effect") {
    @Previewable @State var active = false

    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            Text("Content Behind CRT")
                .foregroundStyle(.white)
            Button("Trigger") { active = true }
                .buttonStyle(.borderedProminent)
        }
        if active {
            CRTTransitionView(isActive: $active) { active = false }
        }
    }
}
