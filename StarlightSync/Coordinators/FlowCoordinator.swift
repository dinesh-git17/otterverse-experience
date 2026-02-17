import Foundation

@Observable
@MainActor
final class FlowCoordinator {
    // MARK: - Chapter Definition

    enum Chapter: Int, CaseIterable {
        case handshake = 0
        case packetRun = 1
        case message = 2
        case cipher = 3
        case partnerInCrime = 4
        case firewall = 5
        case blueprint = 6
        case eventHorizon = 7
    }

    // MARK: - Constants

    private static let highestUnlockedChapterKey = "highestUnlockedChapter"

    // MARK: - State

    private(set) var currentChapter: Chapter

    private let defaults: UserDefaults

    // MARK: - Progression

    func completeCurrentChapter() {
        let nextRawValue = currentChapter.rawValue + 1
        guard let nextChapter = Chapter(rawValue: nextRawValue) else { return }
        currentChapter = nextChapter
        defaults.set(nextChapter.rawValue, forKey: Self.highestUnlockedChapterKey)
    }

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currentChapter = .handshake
    }
}
