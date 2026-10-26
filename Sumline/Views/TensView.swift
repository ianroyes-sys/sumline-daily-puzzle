import SwiftUI

/// Tens: clear the board by pairing tiles that sum to ten. Pairs must be
/// neighbors (8 directions) or see each other along a cleared row/column.
struct TensView: View {
    @EnvironmentObject private var store: GameStore
    let day: Int

    @State private var puzzle: TensPuzzle
    @State private var cleared: Set<Int> = []
    @State private var selected: Int?
    @State private var mistakes = 0
    @State private var flashPair: Set<Int> = []
    @State private var solved = false
    @State private var showResult = false
    @State private var confettiTrigger = 0
    @State private var startedAt = Date()
    @State private var finalSeconds = 0

    init(day: Int) {
        self.day = day
        _puzzle = State(initialValue: TensEngine.daily(day))
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 16) {
                header

                progressBar

                ZStack {
                    board
                    ConfettiBurst(trigger: confettiTrigger)
                        .allowsHitTesting(false)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if showResult {
                MiniResultCard(
                    headline: "Cleared!",
                    chips: [
                        .init(value: GameStore.format(seconds: finalSeconds), caption: "Time"),
                        .init(value: "\(mistakes)", caption: mistakes == 1 ? "Miss" : "Misses",
                              tint: mistakes == 0 ? Theme.mint : Theme.coral),
                        .init(value: "\(store.stats.currentStreak)", caption: "Streak", tint: Theme.amber),
                    ],
                    shareText: "🔟 Tens #\(day) cleared in \(GameStore.format(seconds: finalSeconds)) · \(mistakes) \(mistakes == 1 ? "miss" : "misses")",
                    onClose: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showResult = false } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startedAt = Date()
            if let result = store.miniResult(.tens, day: day) {
                solved = true
                cleared = Set(0..<TensPuzzle.count)
                mistakes = result.pathLength
                finalSeconds = result.seconds
            }
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("Tens · No. \(day)")
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .textCase(.uppercase)
                .kerning(2.2)
            Text("Pair tiles that make 10 — neighbors, or across cleared lines")
                .font(Theme.label(13, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private var progressBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "10.square.fill")
                .foregroundStyle(Theme.mint)
            Text("\((TensPuzzle.count - cleared.count) / 2) pairs left")
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
            let cell = geo.size.width / CGFloat(TensPuzzle.cols)

            ZStack {
                ForEach(0..<TensPuzzle.count, id: \.self) { index in
                    tile(index: index, cell: cell)
                }
            }
        }
        .aspectRatio(CGFloat(TensPuzzle.cols) / CGFloat(TensPuzzle.rows), contentMode: .fit)
        .padding(.horizontal, 44)
    }

    @ViewBuilder
    private func tile(index: Int, cell: CGFloat) -> some View {
        let isCleared = cleared.contains(index)
        let isSelected = selected == index
        let isFlashing = flashPair.contains(index)

        Text("\(puzzle.values[index])")
            .font(Theme.number(cell * 0.4))
            .foregroundStyle(isSelected || isFlashing ? .white : Theme.ink)
            .frame(width: cell - 10, height: cell - 10)
            .background(
                RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                    .fill(tileFill(selected: isSelected, flashing: isFlashing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                    .strokeBorder(Theme.glassStroke, lineWidth: 1)
            )
            .shadow(color: isSelected ? Theme.indigo.opacity(0.6) : .black.opacity(0.14),
                    radius: isSelected ? 12 : 5, y: 3)
            .scaleEffect(isCleared ? 0.3 : (isSelected ? 1.08 : 1))
            .opacity(isCleared ? 0 : 1)
            .position(x: (CGFloat(index % TensPuzzle.cols) + 0.5) * cell,
                      y: (CGFloat(index / TensPuzzle.cols) + 0.5) * cell)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCleared)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
            .onTapGesture { tap(index) }
            .allowsHitTesting(!isCleared && !solved)
    }

    private func tileFill(selected: Bool, flashing: Bool) -> AnyShapeStyle {
        if flashing { return AnyShapeStyle(Theme.coral) }
        if selected { return AnyShapeStyle(Theme.pathGradient) }
        return AnyShapeStyle(Theme.glass)
    }

    private func tap(_ index: Int) {
        guard !solved else { return }
        guard let first = selected else {
            selected = index
            Haptics.tick()
            return
        }
        if first == index {
            selected = nil
            return
        }
        if TensEngine.canPair(first, index, values: puzzle.values, cleared: cleared) {
            selected = nil
            cleared.insert(first)
            cleared.insert(index)
            Haptics.tick()
            if cleared.count == TensPuzzle.count { win() }
        } else {
            mistakes += 1
            Haptics.error()
            flashPair = [first, index]
            selected = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                flashPair = []
            }
        }
    }

    private func win() {
        solved = true
        finalSeconds = min(3600, max(0, Int(Date().timeIntervalSince(startedAt))))
        store.recordMiniWin(.tens, day: day, detail: mistakes, seconds: finalSeconds)
        Haptics.success()
        confettiTrigger += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showResult = true }
        }
    }
}
