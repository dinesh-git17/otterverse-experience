import SwiftUI

struct EventHorizonView: View {
    @Environment(FlowCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Chapter 6")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("The Event Horizon")
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
    EventHorizonView()
        .environment(FlowCoordinator())
}
