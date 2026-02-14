import SwiftUI

struct FirewallView: View {
    @Environment(FlowCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Chapter 4")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("The Firewall")
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
    FirewallView()
        .environment(FlowCoordinator())
}
