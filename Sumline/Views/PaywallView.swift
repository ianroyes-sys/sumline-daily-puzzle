import SwiftUI
import StoreKit

/// The Sumline+ paywall. Honest by design: it says out loud that every
/// puzzle is free forever — Plus is strategy, not access.
struct PaywallView: View {
    @EnvironmentObject private var plus: PlusStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        hero

                        features

                        purchaseButtons

                        Button("Restore purchases") {
                            Task { await plus.restore() }
                        }
                        .font(Theme.label(14, weight: .medium))
                        .foregroundStyle(Theme.inkFaint)

                        Text("Every puzzle, every mode, every day — free forever.\nPlus is for power players, not a toll booth.")
                            .font(Theme.label(12, weight: .medium))
                            .foregroundStyle(Theme.inkFaint)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 20)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(Theme.label(15))
                }
            }
        }
        .onChange(of: plus.isPlus) { _, active in
            if active { dismiss() }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Wordmark(size: 22)
            Text("PLUS")
                .font(Theme.label(15, weight: .heavy))
                .kerning(6)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.heroGradient))
                .shadow(color: Theme.magenta.opacity(0.5), radius: 12)
            Text("Play smarter, never pay to play")
                .font(Theme.label(15, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.top, 16)
    }

    private var features: some View {
        VStack(spacing: 12) {
            feature(icon: "shield.checkered", tint: Theme.teal,
                    title: "Streak Shield",
                    text: "Life happens. Your streak survives one missed day — automatically.")
            feature(icon: "lightbulb.max.fill", tint: Theme.amber,
                    title: "Unlimited hints",
                    text: "Free players get one hint a day. Plus thinkers get as many nudges as they need.")
            feature(icon: "chart.line.uptrend.xyaxis", tint: Theme.indigo,
                    title: "Insights",
                    text: "Your solve times by weekday, your sharpest game, your trends over time.")
            feature(icon: "heart.fill", tint: Theme.magenta,
                    title: "Support an indie game",
                    text: "No ads sold on your attention. Plus keeps the dailies coming.")
        }
    }

    private func feature(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(tint.opacity(0.14)))
                .shadow(color: tint.opacity(0.4), radius: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.label(16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(Theme.label(13, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    @ViewBuilder
    private var purchaseButtons: some View {
        if plus.products.isEmpty {
            VStack(spacing: 6) {
                Text("Purchases unavailable right now")
                    .font(Theme.label(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Check your connection and try again.")
                    .font(Theme.label(12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
        } else {
            VStack(spacing: 10) {
                ForEach(plus.products, id: \.id) { product in
                    Button {
                        Task { await plus.purchase(product) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.displayName)
                                    .font(Theme.label(15, weight: .bold))
                                Text(product.description)
                                    .font(Theme.label(11, weight: .medium))
                                    .opacity(0.7)
                            }
                            Spacer()
                            Text(product.displayPrice)
                                .font(Theme.number(17))
                        }
                        .foregroundStyle(product.id == PlusStore.yearlyID ? .white : Theme.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background {
                            if product.id == PlusStore.yearlyID {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Theme.pathGradient)
                                    .shadow(color: Theme.indigo.opacity(0.5), radius: 12, y: 4)
                            } else {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Theme.glass)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(Theme.glassStroke, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(plus.purchaseInFlight)
                }
            }
        }
    }
}
