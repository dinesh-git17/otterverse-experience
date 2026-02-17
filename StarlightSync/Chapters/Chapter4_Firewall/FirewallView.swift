import SpriteKit
import SwiftUI

struct FirewallView: View {
    @Environment(FlowCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene: FirewallScene?

    var body: some View {
        Group {
            if let scene {
                SpriteView(
                    scene: scene,
                    preferredFramesPerSecond: GameConstants.Physics.targetFrameRate,
                    options: [.ignoresSiblingOrder]
                )
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            let newScene = FirewallScene()
            newScene.scaleMode = .resizeFill
            newScene.coordinator = coordinator
            newScene.reduceMotion = reduceMotion
            scene = newScene
        }
        .onDisappear {
            scene = nil
        }
    }
}

#Preview {
    FirewallView()
        .environment(FlowCoordinator())
}

// MARK: - PartnerInCrimeView (Interstitial)

struct PartnerInCrimeView: View {
    @Environment(FlowCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Content

    private let poemContent = """
    This is criminal behaviour, you know
    The way you walked in and stole the show
    No warning, no mask, no grand disguise
    Just one soft smile and those warm eyes

    You took my heart in broad daylight
    Didn’t even try to hide the heist
    Now I’m left here, happily caught
    Serving a life sentence of loving you lots

    And honestly…
    If this is the crime, I plead guilty too.
    """

    // MARK: - State

    @State private var displayedText: String = " " // Initialize with space to prevent collapse
    @State private var isTyping = false
    @State private var isComplete = false
    @State private var showContinueButton = false
    @State private var warningFlash = false

    // MARK: - Constants

    private let typingSpeed: UInt64 = 30_000_000 // Fast! 30ms
    private let textTint = Color(red: 1.0, green: 0.6, blue: 0.0) // Explicit Amber

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(textTint)
                        .opacity(warningFlash ? 1.0 : 0.4)
                    Text("// CASE ID: 22-04-CRIMINAL //")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                    Spacer()
                }
                .foregroundStyle(textTint)
                .padding(.bottom, 10)

                // Poem text
                Text(displayedText + (isTyping ? "█" : ""))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(textTint)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Continue button
                if showContinueButton {
                    Button(action: advance) {
                        HStack {
                            Image(systemName: "shield.fill")
                            Text("ACTIVATE FIREWALL")
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(textTint)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(24)
            .padding(.top, 40)
        }
        .overlay {
            // Scanlines drawn via Canvas (single view, no layout interference)
            Canvas { context, size in
                let lineSpacing: CGFloat = 5
                var scanY: CGFloat = 0
                while scanY < size.height {
                    let rect = CGRect(x: 0, y: scanY, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(.white.opacity(0.05)))
                    scanY += lineSpacing
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onAppear {
            if reduceMotion {
                displayedText = poemContent
                isComplete = true
                showContinueButton = true
            } else {
                startTyping()
                startWarningFlash()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isTyping {
                completeTyping()
            }
        }
    }

    // MARK: - Logic

    private func startTyping() {
        isTyping = true
        Task { @MainActor in
            // Short initial delay to ensure transition settles
            try? await Task.sleep(nanoseconds: 200_000_000)

            // Clear the placeholder space
            if displayedText == " " { displayedText = "" }

            for char in poemContent {
                if !isTyping { break }

                displayedText.append(char)

                if !char.isWhitespace {
                    // Very light, rapid ticking
                    HapticManager.shared.playTransientEvent(intensity: 0.15, sharpness: 0.9)

                    if Int.random(in: 0 ... 2) == 0 { // Only play sound every 3rd char for speed
                        AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxClick.rawValue, volume: 0.03)
                    }
                }

                let delay = typingSpeed + UInt64.random(in: 0 ... 5_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }

            completeTyping()
        }
    }

    private func startWarningFlash() {
        Task { @MainActor in
            while !isComplete {
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation(.easeInOut(duration: 0.4)) {
                    warningFlash.toggle()
                }
            }
            warningFlash = true // Solid on completion
        }
    }

    private func completeTyping() {
        isTyping = false
        isComplete = true
        displayedText = poemContent
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showContinueButton = true
        }
    }

    private func advance() {
        // Heavy mechanical "activate" sound
        HapticManager.shared.playTransientEvent(intensity: 1.0, sharpness: 0.5)
        coordinator.completeCurrentChapter()
    }
}
