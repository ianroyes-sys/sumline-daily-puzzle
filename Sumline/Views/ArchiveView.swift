import SwiftUI

/// Every past day's trio, playable any time. No lockouts.
struct ArchiveView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach((1...store.today).reversed(), id: \.self) { day in
                        ArchiveDayCard(day: day)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ArchiveDayCard: View {
    @EnvironmentObject private var store: GameStore
    let day: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("No. \(day)")
                    .font(Theme.number(17))
                    .foregroundStyle(Theme.ink)
                if day == store.today {
                    Text("TODAY")
                        .font(Theme.label(10, weight: .heavy))
                        .foregroundStyle(Theme.indigo)
                        .kerning(1.2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.indigo.opacity(0.15)))
                }
                Spacer()
                Text(PuzzleEngine.date(forDay: day).formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.label(13, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                if store.isPerfect(day: day) {
                    Text("👑")
                }
            }

            HStack(spacing: 8) {
                ForEach(DailySlot.allCases) { slot in
                    NavigationLink {
                        GameScreen(kind: day == store.today ? .daily(day, slot) : .archive(day, slot))
                            .id("\(day)-\(slot.rawValue)")
                    } label: {
                        SlotPill(day: day, slot: slot)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ForEach(MiniGame.allCases) { game in
                    NavigationLink {
                        miniDestination(game, day: day)
                            .id("\(game.rawValue)-\(day)")
                    } label: {
                        MiniPill(day: day, game: game)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
    }
}

private struct SlotPill: View {
    @EnvironmentObject private var store: GameStore
    let day: Int
    let slot: DailySlot

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: slot.icon)
                .font(.system(size: 11, weight: .semibold))
            if let result = store.result(day: day, slot: slot) {
                Text(GameStore.format(seconds: result.seconds))
                    .font(Theme.label(12, weight: .bold))
            } else {
                Text(slot.name)
                    .font(Theme.label(12, weight: .bold))
            }
        }
        .foregroundStyle(solved ? Color.white : Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background {
            if solved {
                Capsule().fill(Theme.winGradient)
            } else {
                Capsule().fill(Theme.glass)
                    .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
            }
        }
    }

    private var solved: Bool { store.result(day: day, slot: slot) != nil }
}

private struct MiniPill: View {
    @EnvironmentObject private var store: GameStore
    let day: Int
    let game: MiniGame

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: game.icon)
                .font(.system(size: 11, weight: .semibold))
            if let result = store.miniResult(game, day: day) {
                Text(GameStore.format(seconds: result.seconds))
                    .font(Theme.label(12, weight: .bold))
            } else {
                Text(game.name)
                    .font(Theme.label(12, weight: .bold))
            }
        }
        .foregroundStyle(solved ? Color.white : Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background {
            if solved {
                Capsule().fill(Theme.winGradient)
            } else {
                Capsule().fill(Theme.glass)
                    .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
            }
        }
    }

    private var solved: Bool { store.miniResult(game, day: day) != nil }
}
