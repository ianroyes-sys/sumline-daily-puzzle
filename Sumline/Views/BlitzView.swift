import SwiftUI

/// Time attack: 75 seconds on the clock, short boards, every solve
/// banks +6 seconds. Chase your best.
struct BlitzView: View {
    @EnvironmentObject private var store: GameStore

    private enum Phase: Equatable {
        case ready
        case running
        case finished
    }

    private static let startingSeconds: TimeInterval = 75
    private static let bonusSeconds: TimeInterval = 6

    @State private var phase = Phase.ready
    @State private var endDate = Date()
    @State private var score = 0
    @State private var puzzle = PuzzleEngine.blitz(seed: 1)
    @State private var path: [Int] = []
    @State private var failedFlash = false
    @State private var rng = SplitMix64(seed: UInt64(Date().timeIntervalSince1970) &* 977)
    @State private var bonusFlash = false
    @State private var isNewBest = false

    var body: some View {
        ZStack {
            AuroraBackground()

            switch phase {
            case .ready:
                readyView
            case .running:
                runningView
            case .finished:
                finishedView
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Ready

    private var readyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Theme.amber)
                .shadow(color: Theme.amber.opacity(0.8), radius: 18)

            Text("Blitz")
                .font(Theme.number(38))
                .foregroundStyle(Theme.ink)

            VStack(spacing: 8) {
                Text("75 seconds. Short boards.")
                Text("Every solve banks +6 seconds.")
            }
            .font(Theme.label(16, weight: .medium))
            .foregroundStyle(Theme.inkFaint)

            if store.blitzBest > 0 {
                Text("Best: \(store.blitzBest)")
                    .font(Theme.label(15, weight: .bold))
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .glassCard(cornerRadius: 20)
            }

            Button {
                store.diagonalMoves.toggle()
                Haptics.tick()
            } label: {
                Label("Diagonals", systemImage: store.diagonalMoves
                      ? "arrow.up.right.circle.fill" : "arrow.up.right.circle")
            }
            .buttonStyle(PillButtonStyle(prominent: store.diagonalMoves))

            Button {
                start()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .frame(minWidth: 120)
            }
            .buttonStyle(PillButtonStyle(prominent: true))
        }
        .padding(30)
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                let remaining = max(0, endDate.timeIntervalSince(timeline.date))
                clockBar(remaining: remaining)
                    .onChange(of: remaining <= 0) { _, expired in
                        if expired { finish() }
                    }
            }

            HStack(spacing: 14) {
                Text("Make")
                    .font(Theme.label(16, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                Text("\(puzzle.target)")
                    .font(Theme.number(40))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("\(puzzle.sum(of: path))")
                    .font(Theme.number(20))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 46)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 9)
                    .background(Capsule().fill(sumColor))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: 36, bright: true)

            BoardView(puzzle: puzzle,
                      path: $path,
                      solved: false,
                      failedFlash: failedFlash,
                      hintCells: [],
                      palette: Theme.palette(forLevel: score + 1),
                      onPathChanged: { Haptics.tick() },
                      onRelease: handleRelease)
                .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var sumColor: Color {
        let sum = puzzle.sum(of: path)
        if path.isEmpty { return Theme.inkFaint.opacity(0.5) }
        if sum == puzzle.target { return Theme.mint }
        return sum > puzzle.target ? Theme.coral : Theme.palette(forLevel: score + 1).a
    }

    private func clockBar(remaining: TimeInterval) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Theme.amber)
                Text("\(score)")
                    .font(Theme.number(24))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.glass)
                    Capsule()
                        .fill(remaining < 10 ? AnyShapeStyle(Theme.coral) : AnyShapeStyle(Theme.pathGradient))
                        .frame(width: geo.size.width * min(1, remaining / Self.startingSeconds))
                        .animation(.linear(duration: 0.1), value: remaining)
                }
            }
            .frame(height: 14)

            Text(String(format: "%.0f", remaining.rounded(.up)))
                .font(Theme.number(24))
                .monospacedDigit()
                .foregroundStyle(remaining < 10 ? Theme.coral : Theme.ink)
                .frame(width: 44, alignment: .trailing)
                .scaleEffect(bonusFlash ? 1.25 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: bonusFlash)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(spacing: 22) {
            Text(isNewBest ? "New best! ⚡️" : "Time!")
                .font(Theme.number(34))
                .foregroundStyle(Theme.ink)

            Text("\(score)")
                .font(Theme.number(80))
                .foregroundStyle(Theme.heroGradient)
                .shadow(color: Theme.indigo.opacity(0.6), radius: 20)

            Text(score == 1 ? "board cleared" : "boards cleared")
                .font(Theme.label(15, weight: .medium))
                .foregroundStyle(Theme.inkFaint)

            HStack(spacing: 10) {
                StatChip(value: "\(store.blitzBest)", caption: "Best", tint: Theme.amber)
            }
            .frame(width: 140)

            ShareLink(item: "⚡️ \(score) boards in 75s of Sumline Blitz. Beat that.") {
                Label("Challenge friends", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PillButtonStyle(prominent: true))

            Button {
                start()
            } label: {
                Label("Run it back", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(30)
    }

    // MARK: - Logic

    private func start() {
        score = 0
        isNewBest = false
        path = []
        nextPuzzle()
        endDate = Date().addingTimeInterval(Self.startingSeconds)
        phase = .running
        Haptics.tick()
    }

    private func finish() {
        guard phase == .running else { return }
        isNewBest = score > store.blitzBest && score > 0
        store.recordBlitz(score: score)
        phase = .finished
        Haptics.success()
    }

    private func nextPuzzle() {
        var generator = rng
        puzzle = PuzzleEngine.blitz(seed: generator.next(), diagonal: store.diagonalMoves)
        rng = generator
        path = []
    }

    private func handleRelease() {
        guard !path.isEmpty else { return }
        if puzzle.sum(of: path) == puzzle.target && path.count >= 2 {
            score += 1
            endDate = endDate.addingTimeInterval(Self.bonusSeconds)
            Haptics.success()
            bonusFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { bonusFlash = false }
            nextPuzzle()
        } else {
            Haptics.error()
            failedFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                failedFlash = false
                path = []
            }
        }
    }
}
