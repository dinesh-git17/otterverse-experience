import SwiftUI

struct HandshakeView: View {
    @Environment(FlowCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Chapter 1")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("The Handshake")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Button("Complete Chapter") {
                    coordinator.completeCurrentChapter()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    HandshakeView()
        .environment(FlowCoordinator())
}
