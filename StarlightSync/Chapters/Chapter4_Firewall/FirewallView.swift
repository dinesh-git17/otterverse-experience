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
