import SwiftUI

struct TypewriterView: View {
    @Environment(FlowCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Configuration

    // swiftlint:disable line_length
    private let messageContent = """
    My love,

    I don't think you realize how quietly and completely you stole my heart.

    It wasn't one big moment. It was a hundred small ones. The way you laugh when something catches you off guard. The way you listen, really listen, when I talk. The way you make ordinary days feel warm and meaningful just by being in them.

    Somewhere along the way, without asking permission, you became home to me.

    My heart feels safe with you. It feels understood, seen, and cared for in a way I didn't even know I needed before you came into my life. You didn't just take my heart. You changed it. You made it softer, braver, and fuller than it's ever been.

    And the truth is, I don't want it back.

    My heart is yours. Not for a moment, not for a season, but for as long as we keep choosing each other. I carry you with me in everything I do, and loving you has become one of the most natural parts of who I am.

    You didn't just win a game tonight. You won me a long time ago.
    """
    // swiftlint:enable line_length

    // MARK: - State

    @State private var displayedText: String = ""
    @State private var isTyping = false
    @State private var isComplete = false
    @State private var cursorVisible = true
    @State private var showContinueButton = false

    // MARK: - Constants

    private let typingSpeed: UInt64 = 45_000_000
    private let textTint = Color(red: 0.0, green: 0.95, blue: 0.85)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                    Text("SECURE CHANNEL ESTABLISHED")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                    Spacer()
                }
                .foregroundStyle(textTint.opacity(0.6))
                .padding(.bottom, 10)

                // Typewriter text
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text(displayedText + (cursorVisible ? "\u{2588}" : ""))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(textTint)
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("typingText")

                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.bottom, 60)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: displayedText) {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: showContinueButton) {
                        if showContinueButton {
                            withAnimation(.easeOut(duration: 0.5)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }

                // Continue button
                if showContinueButton {
                    Button(action: advance) {
                        HStack {
                            Text("DECODE")
                                .font(.system(.title3, design: .monospaced).weight(.bold))
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(textTint)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(24)
            .padding(.top, 40)
        }
        .onAppear {
            if reduceMotion {
                displayedText = messageContent
                isComplete = true
                showContinueButton = true
            } else {
                startTyping()
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
            Task { @MainActor in
                while !isComplete {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    cursorVisible.toggle()
                }
                cursorVisible = false
            }

            for char in messageContent {
                if !isTyping { break }

                displayedText.append(char)

                if !char.isWhitespace {
                    playTypingFeedback()
                }

                let delay = typingSpeed + UInt64.random(in: 0 ... 10_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }

            completeTyping()
        }
    }

    private func completeTyping() {
        isTyping = false
        isComplete = true
        displayedText = messageContent
        cursorVisible = false
        withAnimation(.easeIn(duration: 0.5)) {
            showContinueButton = true
        }
    }

    private func advance() {
        HapticManager.shared.playTransientEvent(intensity: 0.8, sharpness: 0.5)
        coordinator.completeCurrentChapter()
    }

    private func playTypingFeedback() {
        HapticManager.shared.playTransientEvent(intensity: 0.1, sharpness: 0.5)
        AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxClick.rawValue, volume: 0.05)
    }
}

#Preview {
    TypewriterView()
        .environment(FlowCoordinator())
}
