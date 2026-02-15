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
        switch coordinator.currentChapter {
        case .handshake:
            HandshakeView()
        case .packetRun:
            PacketRunView()
        case .cipher:
            CipherView()
        case .firewall:
            FirewallView()
        case .blueprint:
            BlueprintView()
        case .eventHorizon:
            EventHorizonView()
        }
    }
}

#Preview {
    ChapterRouterView()
        .environment(FlowCoordinator())
}
