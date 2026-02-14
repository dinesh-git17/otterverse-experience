import SwiftUI

struct BlueprintView: View {
    @Environment(FlowCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Chapter 5")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("The Blueprint")
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
    BlueprintView()
        .environment(FlowCoordinator())
}
