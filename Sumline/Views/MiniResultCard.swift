import SwiftUI

/// Shared result sheet for the mini dailies.
struct MiniResultCard: View {
    struct Chip {
        let value: String
        let caption: String
        var tint: Color = Theme.ink
    }

    let headline: String
    let chips: [Chip]
    let shareText: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Theme.glassStroke)
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            Text(headline)
                .font(Theme.number(30))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    StatChip(value: chip.value, caption: chip.caption, tint: chip.tint)
                }
            }
            .padding(.horizontal, 18)

            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PillButtonStyle(prominent: true))

            countdown

            Button("Close") { onClose() }
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
    }

    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let remaining = PuzzleEngine.secondsUntilTomorrow()
            let formatted = String(format: "%02d:%02d:%02d",
                                   remaining / 3600, (remaining % 3600) / 60, remaining % 60)
            VStack(spacing: 2) {
                Text("Next puzzles in")
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
