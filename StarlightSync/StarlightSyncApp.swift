import SwiftUI

@main
struct StarlightSyncApp: App {
    @State private var coordinator = FlowCoordinator()

    var body: some Scene {
        WindowGroup {
            ChapterRouterView()
                .environment(coordinator)
                .task {
                    await AssetPreloadCoordinator.shared.preloadAllAssets()
                }
        }
    }
}

struct ChapterRouterView: View {
    @Environment(FlowCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            switch coordinator.currentChapter {
            case .handshake:
                HandshakeView()
            case .packetRun:
                PacketRunView()
            case .message:
                TypewriterView()
            case .cipher:
                CipherView()
            case .partnerInCrime:
                PartnerInCrimeView()
            case .firewall:
                FirewallView()
            case .blueprint:
                BlueprintView()
            case .eventHorizon:
                EventHorizonView()
            }
        }
        .id(coordinator.currentChapter)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.2)),
                removal: .opacity.combined(with: .scale(scale: 0.8))
            )
        )
        .animation(.easeInOut(duration: 0.6), value: coordinator.currentChapter)
    }
}

#Preview {
    ChapterRouterView()
        .environment(FlowCoordinator())
}
