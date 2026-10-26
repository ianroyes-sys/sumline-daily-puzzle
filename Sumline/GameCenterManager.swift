import Foundation
import GameKit
import UIKit

/// Game Center: real global leaderboards with zero backend.
/// Score submissions are fire-and-forget; failures never disturb play.
@MainActor
final class GameCenterManager: ObservableObject {

    enum Board: String, CaseIterable, Identifiable {
        case blitz = "sumline.blitz.best"
        case streak = "sumline.streak.current"
        case solves = "sumline.solves.total"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .blitz: return "Blitz"
            case .streak: return "Streak"
            case .solves: return "Solves"
            }
        }

        var unit: String {
            switch self {
            case .blitz: return "boards"
            case .streak: return "days"
            case .solves: return "puzzles"
            }
        }
    }

    struct Entry: Identifiable {
        let rank: Int
        let name: String
        let score: Int
        let isLocalPlayer: Bool

        var id: Int { rank }
    }

    @Published private(set) var isAuthenticated = false
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var localEntry: Entry?
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false

    func authenticate() {
        guard !isAuthenticated else { return }
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.rootViewController?.present(viewController, animated: true)
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if error != nil {
                    self.isAuthenticated = false
                }
            }
        }
    }

    // MARK: - Submitting

    func submit(score: Int, to board: Board) {
        guard isAuthenticated, score > 0 else { return }
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0,
                                                 player: GKLocalPlayer.local,
                                                 leaderboardIDs: [board.rawValue])
        }
    }

    /// Push the standing numbers after any solve.
    func syncScores(stats: Stats, blitzBest: Int) {
        submit(score: blitzBest, to: .blitz)
        submit(score: stats.currentStreak, to: .streak)
        submit(score: stats.solvedCount, to: .solves)
    }

    // MARK: - Reading

    func loadBoard(_ board: Board) async {
        guard isAuthenticated else { return }
        isLoading = true
        loadFailed = false
        entries = []
        localEntry = nil
        defer { isLoading = false }
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [board.rawValue])
            guard let leaderboard = boards.first else {
                loadFailed = true
                return
            }
            let (local, loaded, _) = try await leaderboard.loadEntries(
                for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 25))
            entries = loaded.map {
                Entry(rank: $0.rank,
                      name: $0.player.displayName,
                      score: $0.score,
                      isLocalPlayer: $0.player == GKLocalPlayer.local)
            }
            if let local {
                localEntry = Entry(rank: local.rank,
                                   name: local.player.displayName,
                                   score: local.score,
                                   isLocalPlayer: true)
            }
        } catch {
            loadFailed = true
        }
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?.rootViewController
    }
}
