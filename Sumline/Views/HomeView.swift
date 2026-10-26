import SwiftUI

/// Root screen: the day's trio, mode cards, and everything else.
struct HomeView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var gameCenter: GameCenterManager
    @State private var showHowTo = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showDuel = false
    @State private var showLeaderboard = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        topBar

                        streakBanner

                        dailyTrio

                        miniDailies

                        modeRow

                        NavigationLink {
                            ArchiveView()
                        } label: {
                            HStack {
                                Label("Puzzle archive", systemImage: "calendar")
                                    .font(Theme.label(15))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.inkFaint)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 15)
                            .glassCard(cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .tint(Theme.indigo)
        .sheet(isPresented: $showHowTo) { HowToView() }
        .sheet(isPresented: $showStats) { StatsView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showDuel) { DuelView() }
        .sheet(isPresented: $showLeaderboard) { LeaderboardView() }
        .fullScreenCover(item: $store.pendingDuel) { invite in
            NavigationStack {
                GameScreen(kind: .duel(invite.code, invite.diagonal))
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { store.pendingDuel = nil }
                        }
                    }
            }
        }
        .onAppear {
            if !store.hasSeenHowTo {
                showHowTo = true
                store.hasSeenHowTo = true
            }
            gameCenter.authenticate()
        }
        .onChange(of: store.results.count) { _, _ in
            gameCenter.syncScores(stats: store.stats, blitzBest: store.blitzBest)
        }
        .onChange(of: store.blitzBest) { _, best in
            gameCenter.submit(score: best, to: .blitz)
        }
        .onChange(of: gameCenter.isAuthenticated) { _, authed in
            if authed { gameCenter.syncScores(stats: store.stats, blitzBest: store.blitzBest) }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            Wordmark()
            Spacer()
            HStack(spacing: 2) {
                Button { showHowTo = true } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(width: 32, height: 40)
                }
                Button { showLeaderboard = true } label: {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                        .frame(width: 32, height: 40)
                }
                Button { showStats = true } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(width: 32, height: 40)
                }
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Streak banner

    @ViewBuilder
    private var streakBanner: some View {
        let stats = store.stats
        if stats.currentStreak > 0 {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Theme.amber)
                Text("\(stats.currentStreak)-day streak")
                    .font(Theme.label(14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                if store.isPerfect(day: store.today) {
                    Text("· 👑 perfect today")
                        .font(Theme.label(14, weight: .medium))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 30)
        }
    }

    // MARK: - Daily trio

    private var dailyTrio: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today · No. \(store.today)")
                    .font(Theme.label(13, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .textCase(.uppercase)
                    .kerning(1.8)
                HStack(spacing: 5) {
                    Circle()
                        .fill(Theme.palette(forLevel: store.today).gradient)
                        .frame(width: 7, height: 7)
                    Text(Theme.palette(forLevel: store.today).name)
                        .font(Theme.label(11, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .textCase(.uppercase)
                        .kerning(1)
                }
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.label(13, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 4)

            ForEach(DailySlot.allCases) { slot in
                NavigationLink {
                    GameScreen(kind: .daily(store.today, slot))
                        .id("\(store.today)-\(slot.rawValue)")
                } label: {
                    DailySlotRow(slot: slot)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Mini dailies

    private var miniDailies: some View {
        VStack(spacing: 12) {
            HStack {
                Text("More dailies")
                    .font(Theme.label(13, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .textCase(.uppercase)
                    .kerning(1.8)
                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(MiniGame.allCases) { game in
                NavigationLink {
                    miniDestination(game, day: store.today)
                        .id("\(game.rawValue)-\(store.today)")
                } label: {
                    MiniGameRow(game: game)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Modes

    private var modeRow: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Modes")
                    .font(Theme.label(13, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .textCase(.uppercase)
                    .kerning(1.8)
                Spacer()
            }
            .padding(.horizontal, 4)

            HStack(spacing: 12) {
                NavigationLink {
                    BlitzView()
                } label: {
                    ModeCard(icon: "bolt.fill", tint: Theme.amber, name: "Blitz",
                             detail: store.blitzBest > 0 ? "Best \(store.blitzBest)" : "75 seconds")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    GameScreen(kind: .zen)
                } label: {
                    ModeCard(icon: "moon.stars.fill", tint: Theme.teal, name: "Zen",
                             detail: store.zenSolves > 0 ? "\(store.zenSolves) solves" : "Endless calm")
                }
                .buttonStyle(.plain)

                Button { showDuel = true } label: {
                    ModeCard(icon: "person.line.dotted.person.fill", tint: Theme.magenta, name: "Duel",
                             detail: "Challenge")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Shared destination builder

@ViewBuilder
func miniDestination(_ game: MiniGame, day: Int) -> some View {
    switch game {
    case .tens: TensView(day: day)
    case .flip: FlipView(day: day)
    case .order: OrderView(day: day)
    }
}

func miniTint(_ game: MiniGame) -> Color {
    switch game {
    case .tens: return Theme.mint
    case .flip: return Theme.amber
    case .order: return Theme.indigo
    }
}

// MARK: - Components

private struct MiniGameRow: View {
    @EnvironmentObject private var store: GameStore
    let game: MiniGame

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: game.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(miniTint(game))
                .frame(width: 46, height: 46)
                .background(Circle().fill(miniTint(game).opacity(0.15)))
                .shadow(color: miniTint(game).opacity(0.4), radius: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(game.name)
                    .font(Theme.label(17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(game.blurb)
                    .font(Theme.label(13, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer()

            if let result = store.miniResult(game, day: store.today) {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.mint)
                    Text(GameStore.format(seconds: result.seconds))
                        .font(Theme.label(12, weight: .medium))
                        .foregroundStyle(Theme.inkFaint)
                }
            } else {
                Text("Play")
                    .font(Theme.label(14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Theme.pathGradient)
                            .shadow(color: Theme.indigo.opacity(0.5), radius: 8, y: 3)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 22)
    }
}

private struct DailySlotRow: View {
    @EnvironmentObject private var store: GameStore
    let slot: DailySlot

    private var palette: Theme.Palette { Theme.palette(forLevel: store.today) }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: slot.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(
                    Circle().fill(palette.gradient)
                        .shadow(color: palette.a.opacity(0.5), radius: 10, y: 3)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(slot.name)
                        .font(Theme.label(17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 3) {
                        ForEach(0..<3) { dot in
                            Circle()
                                .fill(dot < slot.difficultyDots ? Theme.indigo : Theme.glassStroke)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                Text(slot.blurb)
                    .font(Theme.label(13, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer()

            if let result = store.result(day: store.today, slot: slot) {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.mint)
                    Text("\(result.attempts)x · \(GameStore.format(seconds: result.seconds))")
                        .font(Theme.label(12, weight: .medium))
                        .foregroundStyle(Theme.inkFaint)
                }
            } else {
                Text("Play")
                    .font(Theme.label(14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(palette.gradient)
                            .shadow(color: palette.a.opacity(0.5), radius: 8, y: 3)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 22)
    }
}

private struct ModeCard: View {
    let icon: String
    let tint: Color
    let name: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(tint)
                .frame(height: 26)
                .shadow(color: tint.opacity(0.7), radius: 8)
            Text(name)
                .font(Theme.label(15, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(Theme.label(11, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassCard(cornerRadius: 22)
    }
}
