import Foundation

/// Deterministic puzzle generation. Same seed -> same puzzle for every
/// player on every device, with no backend.
enum PuzzleEngine {

    /// Day 1 = July 18, 2026 (launch). Computed against the local calendar
    /// so puzzles flip at the player's midnight, Wordle-style.
    static var epoch: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 17
        return Calendar.current.date(from: components) ?? Date()
    }

    static func todayNumber(now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: epoch)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return max(1, days)
    }

    /// Seconds until the local midnight rollover.
    static func secondsUntilTomorrow(now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return 0 }
        return max(0, Int(tomorrow.timeIntervalSince(now)))
    }

    static func date(forDay day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day,
                              to: Calendar.current.startOfDay(for: epoch)) ?? Date()
    }

    // MARK: - Generation

    /// One of the day's trio. Quick warms up, Classic ramps across the
    /// week (day 0 of the epoch was a Friday), Expert goes long.
    static func daily(_ day: Int, slot: DailySlot, diagonal: Bool = false) -> Puzzle {
        var rng = SplitMix64(seed: 0x51AB_10CF
            &+ UInt64(day) &* 0x9E37_79B9_7F4A_7C15
            &+ UInt64(slot.rawValue &+ 1) &* 0xD1B5_4A32_D192_ED03)
        let length: Int
        switch slot {
        case .quick:
            length = 4
        case .classic:
            let weekday = (day + 4) % 7 // 0 = Monday ... 6 = Sunday
            length = [5, 5, 5, 5, 6, 6, 6][weekday]
        case .expert:
            length = 7
        }
        return generate(day: day, pathLength: length, diagonal: diagonal, rng: &rng)
    }

    static func zen(seed: UInt64, diagonal: Bool = false) -> Puzzle {
        var rng = SplitMix64(seed: seed)
        let length = 4 + Int(rng.next() % 3) // 4...6
        return generate(day: nil, pathLength: length, diagonal: diagonal, rng: &rng)
    }

    /// Blitz boards are short and snappy: 3-4 cells, made to be chained.
    static func blitz(seed: UInt64, diagonal: Bool = false) -> Puzzle {
        var rng = SplitMix64(seed: seed &* 0xA24B_1741_9DDE_92B1 &+ 7)
        let length = 3 + Int(rng.next() % 2) // 3...4
        return generate(day: nil, pathLength: length, diagonal: diagonal, rng: &rng)
    }

    /// Duel boards: mid-length, seeded purely by the shared code. The
    /// diagonal rule travels with the invite so both rivals match.
    static func duel(code: String, diagonal: Bool = false) -> Puzzle {
        var rng = SplitMix64(seed: DuelCode.seed(for: code))
        let length = 5 + Int(rng.next() % 2) // 5...6
        return generate(day: nil, pathLength: length, diagonal: diagonal, rng: &rng)
    }

    private static func generate(day: Int?, pathLength: Int, diagonal: Bool = false,
                                 rng: inout SplitMix64) -> Puzzle {
        let count = Puzzle.gridSize * Puzzle.gridSize
        var values = (0..<count).map { _ in 1 + Int(rng.next() % 9) }
        let path = selfAvoidingWalk(length: pathLength, diagonal: diagonal, rng: &rng)
        let target = path.reduce(0) { $0 + values[$1] }
        // Keep targets in a satisfying range; nudge a cell if the walk came out trivial.
        if target < 10, let first = path.first {
            values[first] = min(9, values[first] + (10 - target))
        }
        let finalTarget = path.reduce(0) { $0 + values[$1] }
        return Puzzle(day: day, values: values, target: finalTarget,
                      solution: path, diagonal: diagonal)
    }

    private static func selfAvoidingWalk(length: Int, diagonal: Bool, rng: inout SplitMix64) -> [Int] {
        let size = Puzzle.gridSize
        for _ in 0..<500 {
            var path = [Int(rng.next() % UInt64(size * size))]
            var visited = Set(path)
            while path.count < length {
                let current = path[path.count - 1]
                let (row, col) = (current / size, current % size)
                var options: [Int] = []
                for dr in -1...1 {
                    for dc in -1...1 where (dr, dc) != (0, 0) {
                        if !diagonal && dr != 0 && dc != 0 { continue }
                        let (nr, nc) = (row + dr, col + dc)
                        if (0..<size).contains(nr), (0..<size).contains(nc) {
                            options.append(nr * size + nc)
                        }
                    }
                }
                options.removeAll { visited.contains($0) }
                guard !options.isEmpty else { break }
                let next = options[Int(rng.next() % UInt64(options.count))]
                path.append(next)
                visited.insert(next)
            }
            if path.count == length { return path }
        }
        // Unreachable in practice: fall back to a straight row.
        return Array(0..<length)
    }
}

/// SplitMix64 — tiny, fast, deterministic across platforms.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
