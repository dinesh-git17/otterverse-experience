import SwiftUI

// MARK: - HoldLatchView

struct HoldLatchView: View {
    let isLocked: Bool
    let onUnlock: () -> Void

    @State private var isPressing = false
    @State private var progress: CGFloat = 0.0
    @State private var hapticTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Ch3Layout.latchCornerRadius)
                .fill(Ch3Color.latchFace)
                .overlay(
                    RoundedRectangle(cornerRadius: Ch3Layout.latchCornerRadius)
                        .strokeBorder(Ch3Color.latchHighlight, lineWidth: Ch3Layout.latchStrokeWidth)
                )

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: Ch3Layout.latchCornerRadius)
                    .fill(isLocked ? Ch3Color.errorFlash : Ch3Color.latchActiveFill)
                    .frame(width: geo.size.width * progress)
                    .animation(
                        isPressing
                            ? .linear(duration: Ch3Physics.latchHoldDuration)
                            : .easeOut(duration: 0.2),
                        value: progress
                    )
            }

            HStack(spacing: 8) {
                Image(systemName: isLocked ? "lock.slash.fill" : "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(isLocked ? "LOCKED" : "HOLD TO UNLOCK")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .tracking(2)
            }
            .foregroundStyle(isPressing || isLocked ? Ch3Color.steelDeep : Ch3Color.latchLockedText)
            .frame(maxWidth: .infinity)
        }
        .frame(width: Ch3Layout.latchWidth, height: Ch3Layout.latchHeight)
        .scaleEffect(isPressing ? 0.96 : 1.0)
        .shadow(color: .black.opacity(0.3), radius: isPressing ? 2 : 4, x: 0, y: isPressing ? 1 : 2)
        .offset(y: isPressing ? Ch3Layout.latchDepressOffset : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
        .onLongPressGesture(minimumDuration: Ch3Physics.latchHoldDuration, pressing: { pressing in
            isPressing = pressing
            if pressing {
                startHaptics()
                progress = 1.0
            } else {
                stopHaptics()
                progress = 0.0
            }
        }, perform: {
            stopHaptics()
            onUnlock()
            progress = 0.0
        })
    }

    private func startHaptics() {
        hapticTask?.cancel()
        hapticTask = Task {
            HapticManager.shared.playTransientEvent(intensity: 0.4, sharpness: 0.4)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Ch3Physics.latchHapticInterval))
                HapticManager.shared.playTransientEvent(intensity: 0.3, sharpness: 0.5)
            }
        }
    }

    private func stopHaptics() {
        hapticTask?.cancel()
        hapticTask = nil
    }
}
