import SwiftUI

/// Create or join a duel: any 6-letter code maps to the same board for
/// everyone, so a code IS the challenge. No accounts, no server.
struct DuelView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var createdCode = DuelCode.random()
    @State private var enteredCode = ""
    @State private var codeInvalid = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        createCard
                        joinCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Duel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.label(15))
                }
            }
        }
    }

    // MARK: - Create

    private var createCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.line.dotted.person.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.magenta)
                .shadow(color: Theme.magenta.opacity(0.7), radius: 12)

            Text("Start a duel")
                .font(Theme.number(24))
                .foregroundStyle(Theme.ink)

            Text("You and a rival play the exact same board. Share the code, then race.")
                .font(Theme.label(14, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                ForEach(Array(createdCode.enumerated()), id: \.offset) { _, character in
                    Text(String(character))
                        .font(Theme.number(26))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 52)
                        .glassCard(cornerRadius: 12, bright: true)
                }
            }

            Toggle(isOn: $store.diagonalMoves) {
                Label("Diagonal board", systemImage: "arrow.up.right.circle")
                    .font(Theme.label(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .tint(Theme.indigo)
            .padding(.horizontal, 6)

            HStack(spacing: 12) {
                ShareLink(item: "⚔️ Sumline duel: same board, fastest line wins.\(store.diagonalMoves ? " Diagonals on." : "") Code \(createdCode) — \(DuelCode.link(for: createdCode, diagonal: store.diagonalMoves))") {
                    Label("Invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PillButtonStyle(prominent: true))

                Button {
                    createdCode = DuelCode.random()
                    Haptics.tick()
                } label: {
                    Label("New code", systemImage: "dice.fill")
                }
                .buttonStyle(PillButtonStyle())
            }

            Button {
                play(code: createdCode)
            } label: {
                Label("Play this board", systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 28)
    }

    // MARK: - Join

    private var joinCard: some View {
        VStack(spacing: 14) {
            Text("Got a code?")
                .font(Theme.number(20))
                .foregroundStyle(Theme.ink)

            TextField("ABC123", text: $enteredCode)
                .font(Theme.number(24))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 14, bright: true)
                .onChange(of: enteredCode) { _, _ in codeInvalid = false }

            if codeInvalid {
                Text("Codes are 6 letters or digits — no O, I, 0, or 1.")
                    .font(Theme.label(13, weight: .medium))
                    .foregroundStyle(Theme.coral)
            }

            Button {
                if let code = DuelCode.normalize(enteredCode) {
                    play(code: code)
                } else {
                    codeInvalid = true
                    Haptics.error()
                }
            } label: {
                Label("Join duel", systemImage: "flag.checkered")
            }
            .buttonStyle(PillButtonStyle(prominent: true))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 28)
    }

    private func play(code: String) {
        let invite = DuelInvite(code: code, diagonal: store.diagonalMoves)
        dismiss()
        // Present after the sheet dismisses so the cover isn't swallowed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            store.pendingDuel = invite
        }
    }
}
