import SpriteKit
import SwiftUI

struct PacketRunView: View {
    @Environment(FlowCoordinator.self) private var coordinator

    @State private var scene: PacketRunScene?

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
            let newScene = PacketRunScene()
            newScene.scaleMode = .resizeFill
            newScene.coordinator = coordinator
            scene = newScene
        }
        .onDisappear {
            scene = nil
        }
    }
}

#Preview {
    PacketRunView()
        .environment(FlowCoordinator())
}
