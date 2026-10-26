import Foundation

/// The other daily games. Every engine here is Foundation-only,
/// deterministic per day, and verified solvable at generation time.
enum MiniGame: String, CaseIterable, Identifiable {
    case tens, flip, order

    var id: String { rawValue }

    var name: String {
        switch self {
        case .tens: return "Tens"
        case .flip: return "Flip"
        case .order: return "Order"
        }
    }

    var icon: String {
        switch self {
        case .tens: return "10.square.fill"
        case .flip: return "sun.max.fill"
        case .order: return "square.grid.3x3.fill"
        }
    }

    var blurb: String {
        switch self {
        case .tens: return "Pair tiles that make ten"
        case .flip: return "Light every tile"
        case .order: return "Each row and column, once"
        }
    }
}

// MARK: - Tens

struct TensPuzzle: Equatable {
    let day: Int
    /// 24 values (1-9) on a 6-row x 4-column board, row-major.
    let values: [Int]

    static let rows = 6
    static let cols = 4
    static let count = rows * cols
}

enum TensEngine {

    static func daily(_ day: Int) -> TensPuzzle {
        var rng = SplitMix64(seed: 0x7E4A_11C3 &+ UInt64(day) &* 0x9E37_79B9_7F4A_7C15)
        for _ in 0..<60 {
            let values = randomBoard(&rng)
            if isSolvable(values) {
                return TensPuzzle(day: day, values: values)
            }
        }
        // Fallback: pairs laid side by side — trivially solvable.
        var values: [Int] = []
        for _ in 0..<12 {
            let a = 1 + Int(rng.next() % 9)
            values.append(contentsOf: [a, 10 - a])
        }
        return TensPuzzle(day: day, values: values)
    }

    private static func randomBoard(_ rng: inout SplitMix64) -> [Int] {
        // 12 complementary pairs, shuffled.
        var values: [Int] = []
        for _ in 0..<12 {
            let a = 1 + Int(rng.next() % 9)
            values.append(contentsOf: [a, 10 - a])
        }
        for i in (1..<values.count).reversed() {
            let j = Int(rng.next() % UInt64(i + 1))
            values.swapAt(i, j)
        }
        return values
    }

    /// Two tiles can pair when they sum to ten AND are neighbors (any of
    /// the 8 directions) or see each other along a fully-cleared row/column.
    static func canPair(_ i: Int, _ j: Int, values: [Int], remaining: UInt32) -> Bool {
        guard i != j, values[i] + values[j] == 10 else { return false }
        let (r1, c1) = (i / TensPuzzle.cols, i % TensPuzzle.cols)
        let (r2, c2) = (j / TensPuzzle.cols, j % TensPuzzle.cols)
        if abs(r1 - r2) <= 1 && abs(c1 - c2) <= 1 { return true }
        if r1 == r2 {
            for c in (min(c1, c2) + 1)..<max(c1, c2) where remaining & (1 << UInt32(r1 * TensPuzzle.cols + c)) != 0 {
                return false
            }
            return true
        }
        if c1 == c2 {
            for r in (min(r1, r2) + 1)..<max(r1, r2) where remaining & (1 << UInt32(r * TensPuzzle.cols + c1)) != 0 {
                return false
            }
            return true
        }
        return false
    }

    static func canPair(_ i: Int, _ j: Int, values: [Int], cleared: Set<Int>) -> Bool {
        var remaining: UInt32 = 0
        for index in 0..<TensPuzzle.count where !cleared.contains(index) {
            remaining |= 1 << UInt32(index)
        }
        return canPair(i, j, values: values, remaining: remaining)
    }

    /// Depth-first search over pairings with failure memoization. The node
    /// cap keeps generation fast; boards that blow the cap are re-rolled.
    static func isSolvable(_ values: [Int]) -> Bool {
        var failed = Set<UInt32>()
        var nodes = 0

        func dfs(_ remaining: UInt32) -> Bool {
            if remaining == 0 { return true }
            if failed.contains(remaining) { return false }
            nodes += 1
            if nodes > 120_000 { return false }
            for i in 0..<TensPuzzle.count where remaining & (1 << UInt32(i)) != 0 {
                for j in (i + 1)..<TensPuzzle.count where remaining & (1 << UInt32(j)) != 0 {
                    if canPair(i, j, values: values, remaining: remaining) {
                        let next = remaining & ~(1 << UInt32(i)) & ~(1 << UInt32(j))
                        if dfs(next) { return true }
                    }
                }
            }
            failed.insert(remaining)
            return false
        }

        return dfs((1 << UInt32(TensPuzzle.count)) - 1)
    }
}

// MARK: - Flip

struct FlipPuzzle: Equatable {
    let day: Int
    /// Starting lit-state of the 5x5 board. Goal: light everything.
    let lit: [Bool]
    /// Minimum taps the scramble used — the day's par.
    let par: Int

    static let size = 5
    static let count = size * size
}

enum FlipEngine {

    /// Tapping a cell toggles it and its orthogonal neighbors.
    static func toggle(_ index: Int, lit: inout [Bool]) {
        let size = FlipPuzzle.size
        let (row, col) = (index / size, index % size)
        lit[index].toggle()
        if row > 0 { lit[index - size].toggle() }
        if row < size - 1 { lit[index + size].toggle() }
        if col > 0 { lit[index - 1].toggle() }
        if col < size - 1 { lit[index + 1].toggle() }
    }

    static func daily(_ day: Int) -> FlipPuzzle {
        var rng = SplitMix64(seed: 0xF11B_0C4D &+ UInt64(day) &* 0x9E37_79B9_7F4A_7C15)
        let weekday = (day + 4) % 7 // 0 = Monday
        let par = [4, 4, 5, 5, 6, 6, 7][weekday]

        // Start from the solved (all-lit) board and un-tap `par` distinct
        // cells — re-tapping those exact cells always solves it.
        var lit = [Bool](repeating: true, count: FlipPuzzle.count)
        var cells = Array(0..<FlipPuzzle.count)
        for i in (1..<cells.count).reversed() {
            let j = Int(rng.next() % UInt64(i + 1))
            cells.swapAt(i, j)
        }
        for cell in cells.prefix(par) {
            toggle(cell, lit: &lit)
        }
        return FlipPuzzle(day: day, lit: lit, par: par)
    }
}

// MARK: - Order

struct OrderPuzzle: Equatable {
    let day: Int
    /// The full 4x4 Latin square (values 1-4), row-major.
    let solution: [Int]
    /// Which cells start revealed.
    let givens: [Bool]

    static let size = 4
    static let count = size * size
}

enum OrderEngine {

    static func daily(_ day: Int) -> OrderPuzzle {
        var rng = SplitMix64(seed: 0x0BD3_77A1 &+ UInt64(day) &* 0x9E37_79B9_7F4A_7C15)
        let weekday = (day + 4) % 7
        let targetRemovals = [8, 8, 9, 9, 9, 10, 10][weekday]

        let solution = randomLatinSquare(&rng)
        var grid = solution
        var order = Array(0..<OrderPuzzle.count)
        for i in (1..<order.count).reversed() {
            let j = Int(rng.next() % UInt64(i + 1))
            order.swapAt(i, j)
        }

        var removed = 0
        for cell in order where removed < targetRemovals {
            let backup = grid[cell]
            grid[cell] = 0
            if solutionCount(grid) == 1 {
                removed += 1
            } else {
                grid[cell] = backup
            }
        }
        return OrderPuzzle(day: day, solution: solution, givens: grid.map { $0 != 0 })
    }

    private static func randomLatinSquare(_ rng: inout SplitMix64) -> [Int] {
        let size = OrderPuzzle.size
        // Base cyclic square, then shuffle rows, columns, and symbols.
        var rows = Array(0..<size), cols = Array(0..<size), symbols = Array(1...size)
        for array in 0..<3 {
            for i in (1..<size).reversed() {
                let j = Int(rng.next() % UInt64(i + 1))
                switch array {
                case 0: rows.swapAt(i, j)
                case 1: cols.swapAt(i, j)
                default: symbols.swapAt(i, j)
                }
            }
        }
        var square = [Int](repeating: 0, count: OrderPuzzle.count)
        for r in 0..<size {
            for c in 0..<size {
                square[r * size + c] = symbols[(rows[r] + cols[c]) % size]
            }
        }
        return square
    }

    /// Backtracking count, capped at 2 — we only care about uniqueness.
    static func solutionCount(_ grid: [Int]) -> Int {
        var grid = grid
        var count = 0
        let size = OrderPuzzle.size

        func valid(_ cell: Int, _ value: Int) -> Bool {
            let (row, col) = (cell / size, cell % size)
            for i in 0..<size {
                if grid[row * size + i] == value { return false }
                if grid[i * size + col] == value { return false }
            }
            return true
        }

        func solve() {
            guard count < 2 else { return }
            guard let cell = grid.firstIndex(of: 0) else {
                count += 1
                return
            }
            for value in 1...size where valid(cell, value) {
                grid[cell] = value
                solve()
                grid[cell] = 0
            }
        }

        solve()
        return count
    }
}
