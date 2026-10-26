import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var plus: PlusStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if plus.isPlus {
                        Label {
                            Text("Sumline+ active — thank you!")
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.mint)
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Get Sumline+")
                                        .font(Theme.label(15, weight: .bold))
                                    Text("Streak Shield, unlimited hints, Insights")
                                        .font(Theme.label(12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "plus.diamond.fill")
                                    .foregroundStyle(Theme.magenta)
                            }
                        }
                    }
                    Button("Restore purchases") {
                        Task { await plus.restore() }
                    }
                } header: {
                    Text("Sumline+")
                }

                Section {
                    Toggle(isOn: $store.hapticsOn) {
                        Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .tint(Theme.indigo)
                    Toggle(isOn: $store.diagonalMoves) {
                        Label("Diagonal moves", systemImage: "arrow.up.right.circle")
                    }
                    .tint(Theme.indigo)
                } header: {
                    Text("Feel")
                } footer: {
                    Text("Diagonal moves apply to dailies, Zen, Blitz, and new duels you create.")
                }

                Section {
                    LabeledContent("Version", value: "2.0")
                    LabeledContent("Design", value: "Aurora")
                } header: {
                    Text("About")
                }

                Section {
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Label("Reset all progress", systemImage: "trash")
                    }
                } footer: {
                    Text("Deletes every result, streak, and stat on this device. This can't be undone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AuroraBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.label(15))
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .confirmationDialog("Reset all progress?",
                                isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) {
                    store.resetAllProgress()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your streak and history will be permanently deleted.")
            }
        }
    }
}
