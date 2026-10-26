import SwiftUI

/// Flip: every tap toggles a plus-shape of tiles. Light the whole board
/// in as few moves as you can — beat the day's par.
struct FlipView: View {
    @EnvironmentObject private var store: GameStore
    let day: Int

    @State private var puzzle: FlipPuzzle
    @State private var lit: [Bool]
    @State private var moves = 0
    @State private var solved = false
    @State private var showResult = false
    @State private var confettiTrigger = 0
    @State private var startedAt = Date()
    @State private var finalSeconds = 0

    init(day: Int) {
        self.day = day
        let puzzle = FlipEngine.daily(day)
        _puzzle = State(initialValue: puzzle)
        _lit = State(initialValue: puzzle.lit)
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 16) {
                header

                movesBar

                ZStack {
                    board
                    ConfettiBurst(trigger: confettiTrigger)
                        .allowsHitTesting(false)
                }

                Button {
                    lit = puzzle.lit
                    moves = 0
                    Haptics.tick()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(PillButtonStyle())
                .opacity(solved ? 0 : 1)

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if showResult {
                MiniResultCard(
                    headline: moves <= puzzle.par ? "Par! ☀️" : "All lit!",
                    chips: [
                        .init(value: "\(moves)", caption: "Moves",
                              tint: moves <= puzzle.par ? Theme.mint : Theme.ink),
                        .init(value: "\(puzzle.par)", caption: "Par"),
                        .init(value: "\(store.stats.currentStreak)", caption: "Streak", tint: Theme.amber),
                    ],
                    shareText: "💡 Flip #\(day): all lit in \(moves) moves (par \(puzzle.par))",
                    onClose: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showResult = false } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startedAt = Date()
            if let result = store.miniResult(.flip, day: day) {
                solved = true
                lit = [Bool](repeating: true, count: FlipPuzzle.count)
                moves = result.pathLength
                finalSeconds = result.seconds
            }
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("Flip · No. \(day)")
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .textCase(.uppercase)
                .kerning(2.2)
            Text("A tap toggles a plus-shape. Light every tile.")
                .font(Theme.label(13, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
        }
    }

    private var movesBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .foregroundStyle(Theme.amber)
            Text("\(moves)")
                .font(Theme.number(22))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text("moves · par \(puzzle.par)")
                .font(Theme.label(14, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
            Text("\(lit.filter { $0 }.count)/\(FlipPuzzle.count) lit")
                .font(Theme.label(14, weight: .medium))
                .foregroundStyle(Theme.teal)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 30, bright: true)
    }

    private var board: some View {
        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(FlipPuzzle.size)

            ZStack {
                ForEach(0..<FlipPuzzle.count, id: \.self) { index in
                    let isLit = lit[index]
                    RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                        .fill(isLit ? AnyShapeStyle(Theme.winGradient) : AnyShapeStyle(Theme.glass))
                        .overlay(
                            RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                                .strokeBorder(Theme.glassStroke, lineWidth: 1)
                        )
                        .shadow(color: isLit ? Theme.teal.opacity(0.55) : .black.opacity(0.14),
                                radius: isLit ? 10 : 5, y: 3)
                        .frame(width: cell - 9, height: cell - 9)
                        .position(x: (CGFloat(index % FlipPuzzle.size) + 0.5) * cell,
                                  y: (CGFloat(index / FlipPuzzle.size) + 0.5) * cell)
                        .animation(.easeOut(duration: 0.18), value: isLit)
                        .onTapGesture { tap(index) }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 24)
    }

    private func tap(_ index: Int) {
        guard !solved else { return }
        FlipEngine.toggle(index, lit: &lit)
        moves += 1
        Haptics.tick()
        if lit.allSatisfy({ $0 }) { win() }
    }

    private func win() {
        solved = true
        finalSeconds = min(3600, max(0, Int(Date().timeIntervalSince(startedAt))))
        store.recordMiniWin(.flip, day: day, detail: moves, seconds: finalSeconds)
        Haptics.success()
        confettiTrigger += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showResult = true }
        }
    }
}
