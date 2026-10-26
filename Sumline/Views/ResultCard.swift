import SwiftUI

/// Bottom sheet shown after solving (or when reopening a solved puzzle).
struct ResultCard: View {
    @EnvironmentObject private var store: GameStore
    let kind: GameScreen.Kind
    let puzzle: Puzzle
    let playerPath: [Int]
    let attempts: Int
    let seconds: Int
    var onNextZen: (() -> Void)?
    let onDismiss: () -> Void

    @State private var shareImage: Image?

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Theme.glassStroke)
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            Text(headline)
                .font(Theme.number(30))
                .foregroundStyle(Theme.ink)

            statRow

            shareButtons

            if let onNextZen {
                Button {
                    onNextZen()
                } label: {
                    Label("Next puzzle", systemImage: "sparkles")
                }
                .buttonStyle(PillButtonStyle(prominent: true))
            }

            if case .daily = kind {
                countdown
            }

            Button("Close") { onDismiss() }
                .font(Theme.label(15))
                .foregroundStyle(Theme.inkFaint)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Theme.glass)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Theme.glassStroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 28, y: -6)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onAppear { renderShareImage() }
    }

    private var headline: String {
        if case .duel = kind { return "Duel solved!" }
        if let daySlot, store.isPerfect(day: daySlot.day) { return "Perfect day! 👑" }
        return "Solved!"
    }

    private var daySlot: (day: Int, slot: DailySlot)? {
        switch kind {
        case .daily(let d, let s), .archive(let d, let s): return (d, s)
        case .zen, .duel: return nil
        }
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            StatChip(value: "\(attempts)", caption: attempts == 1 ? "Try" : "Tries")
            StatChip(value: GameStore.format(seconds: seconds), caption: "Time")
            switch kind {
            case .daily, .archive:
                StatChip(value: "\(store.stats.currentStreak)", caption: "Streak", tint: Theme.amber)
            case .zen:
                StatChip(value: "\(store.zenSolves)", caption: "Zen solves", tint: Theme.teal)
            case .duel:
                StatChip(value: "⚔️", caption: "Duel", tint: Theme.magenta)
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Sharing

    private var shareButtons: some View {
        HStack(spacing: 12) {
            if let shareImage {
                ShareLink(item: shareImage,
                          preview: SharePreview("Sumline", image: shareImage)) {
                    Label("Share card", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(PillButtonStyle(prominent: true))
            }

            ShareLink(item: shareText) {
                Label("Text", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PillButtonStyle())
        }
    }

    private var shareText: String {
        switch kind {
        case .daily(let day, let slot), .archive(let day, let slot):
            return store.shareText(day: day, slot: slot, diagonal: puzzle.diagonal)
        case .zen:
            return "🧘 Zen solve #\(store.zenSolves) in Sumline"
        case .duel(let code, let diagonal):
            let time = GameStore.format(seconds: seconds)
            return "⚔️ I cleared duel \(code)\(diagonal ? " (diagonals)" : "") in \(time) (\(attempts) \(attempts == 1 ? "try" : "tries")). Your move: \(DuelCode.link(for: code, diagonal: diagonal))"
        }
    }

    private func renderShareImage() {
        let (title, subtitle, footer): (String, String, String)
        switch kind {
        case .daily(let day, let slot), .archive(let day, let slot):
            title = "Daily \(slot.name) · No. \(day)"
            subtitle = PuzzleEngine.date(forDay: day).formatted(date: .abbreviated, time: .omitted)
            footer = "Can you trace it faster? · Sumline"
        case .zen:
            title = "Zen solve"
            subtitle = "No clock. Just flow."
            footer = "Sumline — one line, one number"
        case .duel(let code, let diagonal):
            title = "Duel \(code)\(diagonal ? " ↗︎" : "")"
            subtitle = "Same board. Different nerves."
            footer = "Play this exact board · \(DuelCode.link(for: code, diagonal: diagonal))"
        }
        let statLine = "\(attempts) \(attempts == 1 ? "try" : "tries") · \(GameStore.format(seconds: seconds))"
        shareImage = ShareCardRenderer.render(title: title, subtitle: subtitle,
                                              path: playerPath.isEmpty ? puzzle.solution : playerPath,
                                              statLine: statLine, footer: footer)
    }

    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let remaining = PuzzleEngine.secondsUntilTomorrow()
            let formatted = String(format: "%02d:%02d:%02d",
                                   remaining / 3600, (remaining % 3600) / 60, remaining % 60)
            VStack(spacing: 2) {
                Text("Next trio in")
                    .font(Theme.label(12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .textCase(.uppercase)
                    .kerning(1.2)
                Text(formatted)
                    .font(Theme.number(22))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}
