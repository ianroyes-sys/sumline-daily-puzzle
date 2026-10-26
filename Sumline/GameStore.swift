import Foundation
import SwiftUI

/// App-wide persistence: results, streaks, settings. Fully local.
final class GameStore: ObservableObject {

    @Published private(set) var results: [String: DayResult]
    @Published private(set) var zenSolves: Int
    @Published private(set) var blitzBest: Int
    @Published var hapticsOn: Bool {
        didSet {
            defaults.set(hapticsOn, forKey: Keys.haptics)
            Haptics.enabled = hapticsOn
        }
    }
    @Published var hasSeenHowTo: Bool {
        didSet { defaults.set(hasSeenHowTo, forKey: Keys.howTo) }
    }
    /// A duel invite arriving via deep link or the Duel sheet, waiting to be played.
    @Published var pendingDuel: DuelInvite?
    /// Mirrored from PlusStore so gameplay logic can gate on it.
    @Published var plusActive: Bool {
        didSet { defaults.set(plusActive, forKey: Keys.plusMirror) }
    }
    @Published private(set) var hintsUsedToday: Int
    /// Global option: allow diagonal moves in every Sumline mode.
    @Published var diagonalMoves: Bool {
        didSet { defaults.set(diagonalMoves, forKey: Self.diagonalKey) }
    }

    static let diagonalKey = "sumline.diagonal.moves"

    private let defaults = UserDefaults.standard
    private var firstOpened: [String: Date]

    private enum Keys {
        static let results = "sumline.results.v2"
        static let haptics = "sumline.haptics"
        static let howTo = "sumline.howto.v2"
        static let zen = "sumline.zen"
        static let blitz = "sumline.blitzbest"
        static let opened = "sumline.opened.v2"
        static let plusMirror = "sumline.plus.mirror"
        static let hintCount = "sumline.hints.count"
        static let hintDay = "sumline.hints.day"
    }

    init() {
        if let data = defaults.data(forKey: Keys.results),
           let decoded = try? JSONDecoder().decode([String: DayResult].self, from: data) {
            results = decoded
        } else {
            results = [:]
        }
        if let data = defaults.data(forKey: Keys.opened),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            firstOpened = decoded
        } else {
            firstOpened = [:]
        }
        hapticsOn = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        hasSeenHowTo = defaults.bool(forKey: Keys.howTo)
        zenSolves = defaults.integer(forKey: Keys.zen)
        blitzBest = defaults.integer(forKey: Keys.blitz)
        plusActive = defaults.bool(forKey: Keys.plusMirror)
        diagonalMoves = defaults.bool(forKey: Self.diagonalKey)
        let today = PuzzleEngine.todayNumber()
        hintsUsedToday = defaults.integer(forKey: Keys.hintDay) == today
            ? defaults.integer(forKey: Keys.hintCount) : 0
        Haptics.enabled = hapticsOn
    }

    // MARK: - Hints (free: 1/day, Plus: unlimited)

    var canUseHint: Bool { plusActive || hintsUsedToday < 1 }

    func consumeHint() {
        guard !plusActive else { return }
        let today = PuzzleEngine.todayNumber()
        if defaults.integer(forKey: Keys.hintDay) != today {
            hintsUsedToday = 0
        }
        hintsUsedToday += 1
        defaults.set(today, forKey: Keys.hintDay)
        defaults.set(hintsUsedToday, forKey: Keys.hintCount)
    }

    // MARK: - Play tracking

    var today: Int { PuzzleEngine.todayNumber() }

    func result(day: Int, slot: DailySlot) -> DayResult? {
        results[DayResult.key(day: day, slot: slot)]
    }

    func solvedSlots(day: Int) -> Int {
        DailySlot.allCases.filter { result(day: day, slot: $0) != nil }.count
    }

    func isPerfect(day: Int) -> Bool { solvedSlots(day: day) == DailySlot.allCases.count }

    /// Stamp the first time a puzzle is opened; solve time counts from here.
    func markOpened(day: Int, slot: DailySlot) {
        let key = DayResult.key(day: day, slot: slot)
        guard firstOpened[key] == nil else { return }
        firstOpened[key] = Date()
        if let data = try? JSONEncoder().encode(firstOpened) {
            defaults.set(data, forKey: Keys.opened)
        }
    }

    func elapsedSeconds(day: Int, slot: DailySlot) -> Int {
        guard let opened = firstOpened[DayResult.key(day: day, slot: slot)] else { return 0 }
        return min(3600, max(0, Int(Date().timeIntervalSince(opened))))
    }

    func recordWin(day: Int, slot: DailySlot, attempts: Int, pathLength: Int) {
        let result = DayResult(day: day,
                               slot: slot.rawValue,
                               attempts: attempts,
                               seconds: elapsedSeconds(day: day, slot: slot),
                               pathLength: pathLength,
                               solvedAt: Date())
        results[DayResult.key(day: day, slot: slot)] = result
        persistResults()
    }

    // MARK: - Mini games (Tens / Flip / Order)

    private func miniKey(_ game: MiniGame, day: Int) -> String { "\(game.rawValue)-\(day)" }

    func miniResult(_ game: MiniGame, day: Int) -> DayResult? {
        results[miniKey(game, day: day)]
    }

    /// `detail` is per-game: mistakes for Tens/Order, moves for Flip.
    func recordMiniWin(_ game: MiniGame, day: Int, detail: Int, seconds: Int) {
        let key = miniKey(game, day: day)
        guard results[key] == nil else { return }
        results[key] = DayResult(day: day,
                                 slot: 0,
                                 attempts: 1,
                                 seconds: seconds,
                                 pathLength: detail,
                                 solvedAt: Date())
        persistResults()
    }

    func miniSolveCount(_ game: MiniGame) -> Int {
        results.keys.filter { $0.hasPrefix("\(game.rawValue)-") }.count
    }

    func recordZenSolve() {
        zenSolves += 1
        defaults.set(zenSolves, forKey: Keys.zen)
    }

    func recordBlitz(score: Int) {
        guard score > blitzBest else { return }
        blitzBest = score
        defaults.set(blitzBest, forKey: Keys.blitz)
    }

    private func persistResults() {
        if let data = try? JSONEncoder().encode(results) {
            defaults.set(data, forKey: Keys.results)
        }
    }

    // MARK: - Streaks & stats

    private var solvedDays: Set<Int> { Set(results.values.map(\.day)) }

    var stats: Stats {
        var stats = Stats()
        stats.solvedCount = results.count
        let days = solvedDays
        stats.daysPlayed = days.count
        guard !results.isEmpty else { return stats }

        stats.perfectDays = days.filter { isPerfect(day: $0) }.count

        // Current streak: consecutive played days ending today (or yesterday
        // if today hasn't been played yet). With Plus, the Streak Shield
        // bridges a single missed day per run.
        var cursor = days.contains(today) ? today : today - 1
        var shieldAvailable = plusActive
        while cursor >= 1 {
            if days.contains(cursor) {
                stats.currentStreak += 1
                cursor -= 1
            } else if shieldAvailable, cursor > 1, days.contains(cursor - 1) {
                shieldAvailable = false
                cursor -= 1 // the shield absorbs this gap
            } else {
                break
            }
        }

        // Max streak across all history.
        var best = 0, run = 0
        for day in days.sorted() {
            run = days.contains(day - 1) ? run + 1 : 1
            best = max(best, run)
        }
        stats.maxStreak = best

        let attempts = results.values.map(\.attempts)
        stats.averageAttempts = Double(attempts.reduce(0, +)) / Double(attempts.count)
        stats.bestSeconds = results.values.map(\.seconds).min()
        for a in attempts {
            stats.distribution[min(a, 5) - 1] += 1
        }
        return stats
    }

    // MARK: - Sharing

    func shareText(day: Int, slot: DailySlot, diagonal: Bool = false) -> String {
        guard let result = result(day: day, slot: slot) else { return "Sumline #\(day)" }
        let squares = String(repeating: "🟨", count: min(result.attempts - 1, 4)) + "🟩"
        let time = Self.format(seconds: result.seconds)
        var lines = ["Sumline #\(day) · \(slot.name)\(diagonal ? " · ↗︎ diagonals" : "")",
                     "\(squares) \(result.attempts == 1 ? "1 try" : "\(result.attempts) tries") · \(time)"]
        if isPerfect(day: day) {
            lines.append("👑 Perfect day")
        }
        let streak = stats.currentStreak
        if streak > 1 { lines.append("🔥 \(streak)-day streak") }
        return lines.joined(separator: "\n")
    }

    static func format(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Danger zone

    func resetAllProgress() {
        results = [:]
        firstOpened = [:]
        zenSolves = 0
        blitzBest = 0
        defaults.removeObject(forKey: Keys.results)
        defaults.removeObject(forKey: Keys.opened)
        defaults.removeObject(forKey: Keys.zen)
        defaults.removeObject(forKey: Keys.blitz)
    }
}
