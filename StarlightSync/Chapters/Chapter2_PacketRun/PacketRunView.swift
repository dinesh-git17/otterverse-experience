import SwiftUI

struct PacketRunView: View {
    @Environment(FlowCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Chapter 2")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("The Packet Run")
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
    PacketRunView()
        .environment(FlowCoordinator())
}
