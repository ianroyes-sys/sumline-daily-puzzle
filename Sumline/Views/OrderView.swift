import SwiftUI

/// Order: a mini Latin square. Fill the 4x4 grid so every row and column
/// holds 1-4 exactly once. Wrong entries bounce — mistakes are counted.
struct OrderView: View {
    @EnvironmentObject private var store: GameStore
    let day: Int

    @State private var puzzle: OrderPuzzle
    @State private var entries: [Int]
    @State private var selected: Int?
    @State private var mistakes = 0
    @State private var flashCell: Int?
    @State private var solved = false
    @State private var showResult = false
    @State private var confettiTrigger = 0
    @State private var startedAt = Date()
    @State private var finalSeconds = 0

    init(day: Int) {
        self.day = day
        let puzzle = OrderEngine.daily(day)
        _puzzle = State(initialValue: puzzle)
        _entries = State(initialValue: (0..<OrderPuzzle.count).map {
            puzzle.givens[$0] ? puzzle.solution[$0] : 0
        })
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 16) {
                header

                statusBar

                ZStack {
                    board
                    ConfettiBurst(trigger: confettiTrigger)
                        .allowsHitTesting(false)
                }

                numberRow

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if showResult {
                MiniResultCard(
                    headline: mistakes == 0 ? "Flawless!" : "Solved!",
                    chips: [
                        .init(value: GameStore.format(seconds: finalSeconds), caption: "Time"),
                        .init(value: "\(mistakes)", caption: mistakes == 1 ? "Miss" : "Misses",
                              tint: mistakes == 0 ? Theme.mint : Theme.coral),
                        .init(value: "\(store.stats.currentStreak)", caption: "Streak", tint: Theme.amber),
                    ],
                    shareText: "🔢 Order #\(day) · \(GameStore.format(seconds: finalSeconds)) · \(mistakes) \(mistakes == 1 ? "miss" : "misses")",
                    onClose: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showResult = false } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startedAt = Date()
            if let result = store.miniResult(.order, day: day) {
                solved = true
                entries = puzzle.solution
                mistakes = result.pathLength
                finalSeconds = result.seconds
            }
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("Order · No. \(day)")
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .textCase(.uppercase)
                .kerning(2.2)
            Text("Every row and column: 1 to 4, exactly once")
                .font(Theme.label(13, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.fill")
                .foregroundStyle(Theme.indigo)
            Text("\(entries.filter { $0 == 0 }.count) to fill")
                .font(Theme.number(18))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            if mistakes > 0 {
                Text("· \(mistakes) \(mistakes == 1 ? "miss" : "misses")")
                    .font(Theme.label(14, weight: .medium))
                    .foregroundStyle(Theme.coral)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 30, bright: true)
    }

    private var board: some View {
        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(OrderPuzzle.size)

            ZStack {
                ForEach(0..<OrderPuzzle.count, id: \.self) { index in
                    let isGiven = puzzle.givens[index]
                    let value = entries[index]
                    let isSelected = selected == index
                    let isFlashing = flashCell == index

                    Text(value == 0 ? "" : "\(value)")
                        .font(Theme.number(cell * 0.42, weight: isGiven ? .heavy : .semibold))
                        .foregroundStyle(isFlashing ? .white : (isGiven ? Theme.ink : Theme.indigo))
                        .frame(width: cell - 10, height: cell - 10)
                        .background(
                            RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                                .fill(cellFill(given: isGiven, selected: isSelected, flashing: isFlashing))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cell * 0.2, style: .continuous)
                                .strokeBorder(isSelected ? Theme.indigo : Theme.glassStroke,
                                              lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: isSelected ? Theme.indigo.opacity(0.5) : .black.opacity(0.14),
                                radius: isSelected ? 10 : 5, y: 3)
                        .position(x: (CGFloat(index % OrderPuzzle.size) + 0.5) * cell,
                                  y: (CGFloat(index / OrderPuzzle.size) + 0.5) * cell)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
                        .onTapGesture {
                            guard !solved, !isGiven, value == 0 else { return }
                            selected = index
                            Haptics.tick()
                        }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 52)
    }

    private func cellFill(given: Bool, selected: Bool, flashing: Bool) -> AnyShapeStyle {
        if flashing { return AnyShapeStyle(Theme.coral) }
        if selected { return AnyShapeStyle(Theme.glassBright) }
        if given { return AnyShapeStyle(Theme.glassBright) }
        return AnyShapeStyle(Theme.glass)
    }

    private var numberRow: some View {
        HStack(spacing: 14) {
            ForEach(1...4, id: \.self) { value in
                Button {
                    enter(value)
                } label: {
                    Text("\(value)")
                        .font(Theme.number(24))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 58, height: 58)
                        .glassCard(cornerRadius: 18, bright: true)
                }
                .buttonStyle(.plain)
                .disabled(solved)
            }
        }
        .padding(.top, 4)
    }

    private func enter(_ value: Int) {
        guard !solved, let cell = selected, entries[cell] == 0 else { return }
        if puzzle.solution[cell] == value {
            entries[cell] = value
            selected = nil
            Haptics.tick()
            if entries == puzzle.solution { win() }
        } else {
            mistakes += 1
            Haptics.error()
            flashCell = cell
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                flashCell = nil
            }
        }
    }

    private func win() {
        solved = true
        finalSeconds = min(3600, max(0, Int(Date().timeIntervalSince(startedAt))))
        store.recordMiniWin(.order, day: day, detail: mistakes, seconds: finalSeconds)
        Haptics.success()
        confettiTrigger += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showResult = true }
        }
    }
}
