import Foundation

// MARK: - Puzzle

struct Puzzle: Equatable {
    /// Daily puzzle number (1 = launch day). Non-daily modes use nil.
    let day: Int?
    /// 25 cell values (1-9), row-major on a 5x5 grid.
    let values: [Int]
    /// The sum the player's path must hit exactly.
    let target: Int
    /// One known valid path (cell indices) — used for hints.
    let solution: [Int]
    /// Whether the line may move diagonally (Zen option; dailies, duels,
    /// and Blitz stay orthogonal so shared boards and scores are fair).
    var diagonal = false

    var isDaily: Bool { day != nil }

    static let gridSize = 5

    static func areAdjacent(_ a: Int, _ b: Int, diagonal: Bool = false) -> Bool {
        let (ar, ac) = (a / gridSize, a % gridSize)
        let (br, bc) = (b / gridSize, b % gridSize)
        if diagonal {
            return a != b && abs(ar - br) <= 1 && abs(ac - bc) <= 1
        }
        return abs(ar - br) + abs(ac - bc) == 1
    }

    func areAdjacent(_ a: Int, _ b: Int) -> Bool {
        Self.areAdjacent(a, b, diagonal: diagonal)
    }

    func sum(of path: [Int]) -> Int {
        path.reduce(0) { $0 + values[$1] }
    }
}

// MARK: - Daily Trio

/// Three puzzles every day: a warm-up, the main event, and a stretch goal.
enum DailySlot: Int, CaseIterable, Codable, Identifiable {
    case quick = 0
    case classic = 1
    case expert = 2

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .quick: return "Quick"
        case .classic: return "Classic"
        case .expert: return "Expert"
        }
    }

    var icon: String {
        switch self {
        case .quick: return "bolt.fill"
        case .classic: return "star.fill"
        case .expert: return "crown.fill"
        }
    }

    var blurb: String {
        switch self {
        case .quick: return "A gentle warm-up"
        case .classic: return "The main event"
        case .expert: return "For the brave"
        }
    }

    var difficultyDots: Int {
        switch self {
        case .quick: return 1
        case .classic: return 2
        case .expert: return 3
        }
    }
}

// MARK: - Results & stats

struct DayResult: Codable, Equatable {
    let day: Int
    let slot: Int
    var attempts: Int
    var seconds: Int
    var pathLength: Int
    var solvedAt: Date

    static func key(day: Int, slot: DailySlot) -> String { "\(day)-\(slot.rawValue)" }
}

struct Stats {
    var solvedCount: Int = 0
    var daysPlayed: Int = 0
    var perfectDays: Int = 0
    var currentStreak: Int = 0
    var maxStreak: Int = 0
    var averageAttempts: Double = 0
    var bestSeconds: Int?
    /// Attempt distribution buckets: 1, 2, 3, 4, 5+
    var distribution: [Int] = [0, 0, 0, 0, 0]
}

// MARK: - Duel codes

/// Any 6-character code deterministically maps to a puzzle, so two players
/// who share a code play the identical board — no server involved.
enum DuelCode {
    /// No 0/O or 1/I — every code survives being read aloud.
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 6

    static func random() -> String {
        String((0..<length).map { _ in alphabet.randomElement() ?? "A" })
    }

    static func normalize(_ raw: String) -> String? {
        let cleaned = raw.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard cleaned.count == length, cleaned.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return cleaned
    }

    /// FNV-1a over the code characters — stable across launches and devices.
    static func seed(for code: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for scalar in code.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    static func link(for code: String, diagonal: Bool = false) -> String {
        "sumline://duel/\(code)" + (diagonal ? "?d=1" : "")
    }
}

/// A duel someone is about to play: the code plus the movement rule, so
/// both rivals face the identical board.
struct DuelInvite: Identifiable, Equatable {
    let code: String
    let diagonal: Bool

    var id: String { "\(code)-\(diagonal)" }
}
