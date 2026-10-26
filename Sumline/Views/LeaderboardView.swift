import SwiftUI

/// Global rankings, Aurora style. Your row is pinned up top so you always
/// know exactly where you stand.
struct LeaderboardView: View {
    @EnvironmentObject private var gameCenter: GameCenterManager
    @Environment(\.dismiss) private var dismiss

    @State private var board: GameCenterManager.Board = .blitz

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                VStack(spacing: 16) {
                    boardPicker

                    if !gameCenter.isAuthenticated {
                        signInCard
                    } else if gameCenter.isLoading {
                        ProgressView()
                            .tint(Theme.indigo)
                            .frame(maxHeight: .infinity)
                    } else if gameCenter.loadFailed || gameCenter.entries.isEmpty {
                        emptyCard
                    } else {
                        rankings
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.label(15))
                }
            }
        }
        .task { await gameCenter.loadBoard(board) }
        .onChange(of: board) { _, newBoard in
            Task { await gameCenter.loadBoard(newBoard) }
        }
    }

    private var boardPicker: some View {
        HStack(spacing: 8) {
            ForEach(GameCenterManager.Board.allCases) { candidate in
                Button {
                    board = candidate
                    Haptics.tick()
                } label: {
                    Text(candidate.title)
                        .font(Theme.label(14, weight: .bold))
                        .foregroundStyle(board == candidate ? .white : Theme.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background {
                            if board == candidate {
                                Capsule().fill(Theme.pathGradient)
                                    .shadow(color: Theme.indigo.opacity(0.5), radius: 8, y: 2)
                            } else {
                                Capsule().fill(Theme.glass)
                                    .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rankings: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let you = gameCenter.localEntry {
                    row(you, pinned: true)
                }
                ForEach(gameCenter.entries) { entry in
                    row(entry, pinned: false)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private func row(_ entry: GameCenterManager.Entry, pinned: Bool) -> some View {
        HStack(spacing: 14) {
            Text("#\(entry.rank)")
                .font(Theme.number(16))
                .foregroundStyle(entry.rank <= 3 ? Theme.amber : Theme.inkFaint)
                .frame(width: 48, alignment: .leading)
                .monospacedDigit()

            Text(pinned ? "You" : entry.name)
                .font(Theme.label(15, weight: entry.isLocalPlayer ? .heavy : .semibold))
                .foregroundStyle(entry.isLocalPlayer && !pinned ? Theme.indigo : Theme.ink)
                .lineLimit(1)

            Spacer()

            Text("\(entry.score)")
                .font(Theme.number(17))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
            Text(board.unit)
                .font(Theme.label(11, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if pinned {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.pathGradient.opacity(0.25))
            }
        }
        .glassCard(cornerRadius: 16, bright: pinned)
    }

    private var signInCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .shadow(color: Theme.amber.opacity(0.7), radius: 12)
            Text("See where you stand")
                .font(Theme.number(22))
                .foregroundStyle(Theme.ink)
            Text("Sign in to Game Center to join the global rankings for Blitz, streaks, and total solves.")
                .font(Theme.label(14, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
            Button {
                gameCenter.authenticate()
            } label: {
                Label("Sign in", systemImage: "person.crop.circle.badge.checkmark")
            }
            .buttonStyle(PillButtonStyle(prominent: true))
        }
        .padding(26)
        .glassCard(cornerRadius: 26)
        .padding(.horizontal, 24)
        .padding(.top, 30)
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.teal)
            Text("No entries yet")
                .font(Theme.number(20))
                .foregroundStyle(Theme.ink)
            Text("Rankings appear once players start posting scores — be the first.")
                .font(Theme.label(14, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .padding(26)
        .glassCard(cornerRadius: 26)
        .padding(.horizontal, 24)
        .padding(.top, 30)
    }
}
