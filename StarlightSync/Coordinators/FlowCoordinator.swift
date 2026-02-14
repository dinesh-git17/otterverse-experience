import Foundation

@Observable
@MainActor
final class FlowCoordinator {
    // MARK: - Chapter Definition

    enum Chapter: Int, CaseIterable {
        case handshake = 0
        case packetRun = 1
        case cipher = 2
        case firewall = 3
        case blueprint = 4
        case eventHorizon = 5
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

        let persistedValue = defaults.integer(forKey: Self.highestUnlockedChapterKey)
        let clampedValue = max(0, min(persistedValue, Chapter.allCases.count - 1))
        currentChapter = Chapter(rawValue: clampedValue) ?? .handshake
    }
}
