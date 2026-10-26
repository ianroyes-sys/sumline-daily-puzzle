import SwiftUI

/// One playable puzzle: a daily-trio slot, an archive day, zen, or a duel.
struct GameScreen: View {
    enum Kind: Equatable {
        case daily(Int, DailySlot)
        case archive(Int, DailySlot)
        case zen
        case duel(String, Bool) // code, diagonal
    }

    @EnvironmentObject private var store: GameStore
    let kind: Kind

    @State private var puzzle: Puzzle
    @State private var path: [Int] = []
    @State private var attempts = 0
    @State private var solved = false
    @State private var failedFlash = false
    @State private var shakes = 0
    @State private var hintCells: [Int] = []
    @State private var showResult = false
    @State private var showPaywall = false
    @State private var confettiTrigger = 0
    @State private var startedAt = Date()
    @State private var solveSeconds = 0
    @State private var zenSeed = SplitMix64(seed: UInt64(Date().timeIntervalSince1970))

    init(kind: Kind) {
        self.kind = kind
        let diagonal = UserDefaults.standard.bool(forKey: GameStore.diagonalKey)
        switch kind {
        case .daily(let day, let slot), .archive(let day, let slot):
            _puzzle = State(initialValue: PuzzleEngine.daily(day, slot: slot, diagonal: diagonal))
        case .zen:
            var rng = SplitMix64(seed: UInt64(Date().timeIntervalSince1970) &* 31)
            _puzzle = State(initialValue: PuzzleEngine.zen(seed: rng.next(), diagonal: diagonal))
            _zenSeed = State(initialValue: rng)
        case .duel(let code, let duelDiagonal):
            _puzzle = State(initialValue: PuzzleEngine.duel(code: code, diagonal: duelDiagonal))
        }
    }

    private var daySlot: (day: Int, slot: DailySlot)? {
        switch kind {
        case .daily(let d, let s), .archive(let d, let s): return (d, s)
        case .zen, .duel: return nil
        }
    }

    private var alreadySolvedResult: DayResult? {
        guard let daySlot else { return nil }
        return store.result(day: daySlot.day, slot: daySlot.slot)
    }

    /// The color era: shifts every 10 daily levels (and every 10 Zen
    /// solves). Each duel code gets its own era from its seed.
    private var palette: Theme.Palette {
        switch kind {
        case .daily(let day, _), .archive(let day, _):
            return Theme.palette(forLevel: day)
        case .zen:
            return Theme.palette(forLevel: store.zenSolves + 1)
        case .duel(let code, _):
            return Theme.palettes[Int(DuelCode.seed(for: code) % UInt64(Theme.palettes.count))]
        }
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 18) {
                header

                targetBar

                ZStack {
                    BoardView(puzzle: puzzle,
                              path: $path,
                              solved: solved,
                              failedFlash: failedFlash,
                              hintCells: hintCells,
                              palette: palette,
                              onPathChanged: { Haptics.tick() },
                              onRelease: handleRelease)
                        .modifier(ShakeEffect(shakes: CGFloat(shakes)))
                        .padding(.horizontal, 20)
                        .allowsHitTesting(!solved && alreadySolvedResult == nil)

                    ConfettiBurst(trigger: confettiTrigger)
                        .allowsHitTesting(false)
                }

                controls

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if showResult {
                ResultCard(kind: kind,
                           puzzle: puzzle,
                           playerPath: path,
                           attempts: attempts,
                           seconds: resultSeconds,
                           onNextZen: kind == .zen ? nextZen : nil,
                           onDismiss: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showResult = false } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            startedAt = Date()
            if let daySlot { store.markOpened(day: daySlot.day, slot: daySlot.slot) }
            if let result = alreadySolvedResult {
                // Reopening a solved puzzle: show the known solution, locked.
                // Display the orthodox board — the variant the day is scored on.
                if puzzle.diagonal, let daySlot {
                    puzzle = PuzzleEngine.daily(daySlot.day, slot: daySlot.slot)
                }
                solved = true
                attempts = result.attempts
                solveSeconds = result.seconds
                path = puzzle.solution
            }
        }
    }

    private var resultSeconds: Int {
        if let daySlot, let result = store.result(day: daySlot.day, slot: daySlot.slot) {
            return result.seconds
        }
        return solveSeconds
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .textCase(.uppercase)
                .kerning(2.2)
            Text(subtitle)
                .font(Theme.label(15, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
            HStack(spacing: 6) {
                Circle()
                    .fill(palette.gradient)
                    .frame(width: 8, height: 8)
                Text("\(palette.name) era")
                    .font(Theme.label(11, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .textCase(.uppercase)
                    .kerning(1.2)
            }
        }
    }

    private var title: String {
        switch kind {
        case .daily(let d, let slot): return "Daily \(slot.name) · No. \(d)"
        case .archive(let d, let slot): return "Archive \(slot.name) · No. \(d)"
        case .zen: return "Zen"
        case .duel(let code, let diagonal): return "Duel · \(code)\(diagonal ? " ↗︎" : "")"
        }
    }

    private var subtitle: String {
        let diagonalTag = puzzle.diagonal ? " · ↗︎ diagonals" : ""
        switch kind {
        case .daily:
            return Date().formatted(date: .abbreviated, time: .omitted) + diagonalTag
        case .archive(let d, _):
            return PuzzleEngine.date(forDay: d).formatted(date: .abbreviated, time: .omitted) + diagonalTag
        case .zen:
            return puzzle.diagonal ? "Endless calm — diagonals on" : "Endless calm — no clock, no streaks"
        case .duel:
            return "Same board as your rival. Go."
        }
    }

    private var currentSum: Int { puzzle.sum(of: path) }

    private var targetBar: some View {
        HStack(spacing: 14) {
            Text("Make")
                .font(Theme.label(17, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
            Text("\(puzzle.target)")
                .font(Theme.number(44))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            sumPill
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 40, bright: true)
    }

    private var sumPill: some View {
        let sum = currentSum
        let state: (Color, String)
        if path.isEmpty {
            state = (Theme.inkFaint.opacity(0.5), "—")
        } else if sum == puzzle.target {
            state = (Theme.mint, "\(sum)")
        } else if sum > puzzle.target {
            state = (Theme.coral, "\(sum)")
        } else {
            state = (palette.a, "\(sum)")
        }
        return Text(state.1)
            .font(Theme.number(22))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(minWidth: 52)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Capsule().fill(state.0))
            .shadow(color: state.0.opacity(0.55), radius: 10)
            .animation(.easeOut(duration: 0.12), value: sum)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            if !solved {
                Button {
                    path = []
                    Haptics.tick()
                } label: {
                    Label("Clear", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(PillButtonStyle())
                .disabled(path.isEmpty)
                .opacity(path.isEmpty ? 0.5 : 1)

                Button {
                    useHint()
                } label: {
                    Label("Hint", systemImage: store.canUseHint ? "lightbulb.fill" : "lock.fill")
                }
                .buttonStyle(PillButtonStyle())
                .disabled(!hintCells.isEmpty)
                .opacity(hintCells.isEmpty ? 1 : 0.5)

                if canToggleDiagonals {
                    Button {
                        toggleDiagonals()
                    } label: {
                        Label("Diagonals", systemImage: puzzle.diagonal
                              ? "arrow.up.right.circle.fill" : "arrow.up.right.circle")
                    }
                    .buttonStyle(PillButtonStyle(prominent: puzzle.diagonal))
                }
            } else {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showResult = true }
                } label: {
                    Label("Results", systemImage: "chart.bar.fill")
                }
                .buttonStyle(PillButtonStyle(prominent: true))
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Game logic

    private func handleRelease() {
        guard !path.isEmpty else { return }
        if currentSum == puzzle.target && path.count >= 2 {
            win()
        } else {
            attempts += 1
            Haptics.error()
            withAnimation(.linear(duration: 0.3)) { shakes += 1 }
            failedFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                failedFlash = false
                withAnimation(.easeOut(duration: 0.2)) { path = [] }
            }
        }
    }

    private func win() {
        solved = true
        attempts += 1
        solveSeconds = min(3600, max(0, Int(Date().timeIntervalSince(startedAt))))
        Haptics.success()
        confettiTrigger += 1
        switch kind {
        case .daily(let day, let slot), .archive(let day, let slot):
            if store.result(day: day, slot: slot) == nil {
                store.recordWin(day: day, slot: slot, attempts: attempts, pathLength: path.count)
            }
        case .zen:
            store.recordZenSolve()
        case .duel:
            break
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showResult = true }
        }
    }

    private func useHint() {
        guard hintCells.isEmpty else { return }
        guard store.canUseHint else {
            showPaywall = true
            return
        }
        store.consumeHint()
        hintCells = Array(puzzle.solution.prefix(2))
        Haptics.tick()
    }

    /// Everywhere except duels — a duel's rule is fixed by the invite.
    private var canToggleDiagonals: Bool {
        if case .duel = kind { return false }
        return true
    }

    private func toggleDiagonals() {
        store.diagonalMoves.toggle()
        Haptics.tick()
        switch kind {
        case .daily(let day, let slot), .archive(let day, let slot):
            puzzle = PuzzleEngine.daily(day, slot: slot, diagonal: store.diagonalMoves)
            path = []
            hintCells = []
        case .zen:
            nextZen()
        case .duel:
            break
        }
    }

    private func nextZen() {
        var rng = zenSeed
        puzzle = PuzzleEngine.zen(seed: rng.next(), diagonal: store.diagonalMoves)
        zenSeed = rng
        path = []
        attempts = 0
        solved = false
        hintCells = []
        startedAt = Date()
        withAnimation { showResult = false }
    }
}

// MARK: - Shake

struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(shakes * .pi * 4) * 7, y: 0))
    }
}

// MARK: - Confetti

struct ConfettiBurst: View {
    let trigger: Int
    @State private var startDate: Date?

    private struct Particle {
        let angle: Double
        let speed: Double
        let size: Double
        let colorIndex: Int
        let spin: Double
    }

    private static let colors: [Color] = [Theme.indigo, Theme.teal, Theme.amber, Theme.coral, Theme.mint, Theme.magenta]

    private static func particles(seed: Int) -> [Particle] {
        var rng = SplitMix64(seed: UInt64(truncatingIfNeeded: seed &+ 99))
        return (0..<40).map { _ in
            Particle(angle: Double(rng.next() % 360) * .pi / 180,
                     speed: 140 + Double(rng.next() % 220),
                     size: 5 + Double(rng.next() % 7),
                     colorIndex: Int(rng.next() % 6),
                     spin: Double(rng.next() % 10) - 5)
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: startDate == nil)) { timeline in
            Canvas { context, canvasSize in
                guard let start = startDate else { return }
                let t = timeline.date.timeIntervalSince(start)
                guard t < 1.4 else { return }
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                for particle in Self.particles(seed: trigger) {
                    let distance = particle.speed * t
                    let x = center.x + cos(particle.angle) * distance
                    let y = center.y + sin(particle.angle) * distance + 180 * t * t
                    let opacity = max(0, 1 - t / 1.3)
                    var layer = context
                    layer.opacity = opacity
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(particle.spin * t))
                    let shape = CGRect(x: -particle.size / 2, y: -particle.size / 2,
                                       width: particle.size, height: particle.size * 0.6)
                    layer.fill(Path(roundedRect: shape, cornerRadius: 1.5),
                               with: .color(Self.colors[particle.colorIndex]))
                }
            }
        }
        .onChange(of: trigger) { _, _ in
            startDate = Date()
        }
    }
}
