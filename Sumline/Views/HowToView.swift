import SwiftUI

struct HowToView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        miniBoard
                            .padding(.top, 6)

                        ruleCard(icon: "hand.draw.fill", tint: Theme.indigo,
                                 title: "Draw one line",
                                 text: "Drag your finger across neighboring tiles — up, down, left, or right. No revisiting a tile. (Zen has an option to allow diagonals.)")

                        ruleCard(icon: "target", tint: Theme.teal,
                                 title: "Hit the target exactly",
                                 text: "The numbers along your line add up as you go. Lift your finger when the sum matches the target.")

                        ruleCard(icon: "square.stack.3d.up.fill", tint: Theme.magenta,
                                 title: "Six dailies, every day",
                                 text: "The Quick / Classic / Expert trio plus Tens, Flip, and Order. Any solve keeps your streak alive — clear the trio for a Perfect Day crown.")

                        ruleCard(icon: "bolt.fill", tint: Theme.amber,
                                 title: "Blitz, Zen & Duels",
                                 text: "Race the clock in Blitz, unwind in endless Zen, or send a duel code so a friend plays your exact board.")

                        Button {
                            dismiss()
                        } label: {
                            Text("Let's play")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PillButtonStyle(prominent: true))
                        .padding(.top, 6)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { dismiss() }
                        .font(Theme.label(15))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
    }

    /// A tiny 3x3 worked example: 7 -> 1 -> 4 sums to 12.
    private var miniBoard: some View {
        VStack(spacing: 10) {
            Text("Make 12")
                .font(Theme.number(22))
                .foregroundStyle(Theme.ink)

            let values = [3, 7, 5, 8, 1, 2, 6, 4, 9]
            let pathCells = [1, 4, 7]
            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { col in
                            let index = row * 3 + col
                            let inPath = pathCells.contains(index)
                            Text("\(values[index])")
                                .font(Theme.number(24))
                                .foregroundStyle(inPath ? .white : Theme.ink)
                                .frame(width: 58, height: 58)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(inPath ? AnyShapeStyle(Theme.pathGradient) : AnyShapeStyle(Theme.glass))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Theme.glassStroke, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            Text("7 + 1 + 4 = 12  ✓")
                .font(Theme.label(14, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard(cornerRadius: 24)
    }

    private func ruleCard(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(tint.opacity(0.14)))
                .shadow(color: tint.opacity(0.4), radius: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.label(16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(Theme.label(14, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
}
