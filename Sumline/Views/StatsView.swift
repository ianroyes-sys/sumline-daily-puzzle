import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            StatChip(value: "\(store.stats.currentStreak)", caption: "Streak", tint: Theme.amber)
                            StatChip(value: "\(store.stats.maxStreak)", caption: "Best streak", tint: Theme.amber)
                            StatChip(value: "\(store.stats.perfectDays)", caption: "Perfect days", tint: Theme.magenta)
                        }
                        HStack(spacing: 10) {
                            StatChip(value: "\(store.stats.solvedCount)", caption: "Solved")
                            StatChip(value: averageAttemptsText, caption: "Avg tries")
                            StatChip(value: bestTimeText, caption: "Best time", tint: Theme.teal)
                        }
                        HStack(spacing: 10) {
                            StatChip(value: store.blitzBest > 0 ? "\(store.blitzBest)" : "—", caption: "Blitz best", tint: Theme.amber)
                            StatChip(value: store.zenSolves > 0 ? "\(store.zenSolves)" : "—", caption: "Zen solves", tint: Theme.teal)
                        }
                        HStack(spacing: 10) {
                            ForEach(MiniGame.allCases) { game in
                                StatChip(value: "\(store.miniSolveCount(game))",
                                         caption: game.name,
                                         tint: miniTint(game))
                            }
                        }

                        distributionCard

                        insightsCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.label(15))
                }
            }
        }
    }

    // MARK: - Insights (Sumline+)

    @ViewBuilder
    private var insightsCard: some View {
        if store.plusActive {
            VStack(alignment: .leading, spacing: 14) {
                Text("Insights")
                    .font(Theme.label(13, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .textCase(.uppercase)
                    .kerning(1.4)

                insightRow(icon: "calendar", tint: Theme.indigo,
                           label: "Sharpest day", value: bestWeekday)
                insightRow(icon: "gauge.with.needle", tint: Theme.teal,
                           label: "Average solve", value: averageTime)
                insightRow(icon: "star.circle.fill", tint: Theme.amber,
                           label: "Favorite game", value: favoriteGame)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 20)
        } else {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.indigo)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.indigo.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Insights")
                            .font(Theme.label(16, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("Weekday trends, solve speeds, and your sharpest game — with Sumline+")
                            .font(Theme.label(13, weight: .medium))
                            .foregroundStyle(Theme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Theme.inkFaint)
                }
                .padding(16)
                .glassCard(cornerRadius: 20)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func insightRow(icon: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30)
            Text(label)
                .font(Theme.label(14, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
            Spacer()
            Text(value)
                .font(Theme.label(15, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
    }

    private var bestWeekday: String {
        let results = store.results.values
        guard !results.isEmpty else { return "—" }
        var seconds: [Int: (total: Int, count: Int)] = [:]
        for result in results {
            let weekday = (result.day + 4) % 7
            seconds[weekday, default: (0, 0)].total += result.seconds
            seconds[weekday, default: (0, 0)].count += 1
        }
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let best = seconds.min { Double($0.value.total) / Double(max($0.value.count, 1)) <
                                 Double($1.value.total) / Double(max($1.value.count, 1)) }
        return best.map { names[$0.key] } ?? "—"
    }

    private var averageTime: String {
        let results = store.results.values
        guard !results.isEmpty else { return "—" }
        let avg = results.map(\.seconds).reduce(0, +) / results.count
        return GameStore.format(seconds: avg)
    }

    private var favoriteGame: String {
        var counts: [String: Int] = ["Sumline": 0]
        for key in store.results.keys {
            if let game = MiniGame.allCases.first(where: { key.hasPrefix("\($0.rawValue)-") }) {
                counts[game.name, default: 0] += 1
            } else {
                counts["Sumline", default: 0] += 1
            }
        }
        return counts.max { $0.value < $1.value }?.key ?? "—"
    }

    private var averageAttemptsText: String {
        store.stats.solvedCount == 0 ? "—" : String(format: "%.1f", store.stats.averageAttempts)
    }

    private var bestTimeText: String {
        guard let best = store.stats.bestSeconds else { return "—" }
        return GameStore.format(seconds: best)
    }

    private var distributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tries per solve")
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .textCase(.uppercase)
                .kerning(1.4)

            let distribution = store.stats.distribution
            let peak = max(distribution.max() ?? 1, 1)
            ForEach(0..<5, id: \.self) { bucket in
                HStack(spacing: 10) {
                    Text(bucket == 4 ? "5+" : "\(bucket + 1)")
                        .font(Theme.number(15))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 26, alignment: .trailing)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.glass)
                            Capsule()
                                .fill(Theme.pathGradient)
                                .frame(width: max(distribution[bucket] == 0 ? 0 : 24,
                                                  geo.size.width * CGFloat(distribution[bucket]) / CGFloat(peak)))
                        }
                    }
                    .frame(height: 20)
                    Text("\(distribution[bucket])")
                        .font(Theme.number(14))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(width: 30, alignment: .leading)
                        .monospacedDigit()
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20)
    }
}
