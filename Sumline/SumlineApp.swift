import SwiftUI

@main
struct SumlineApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var plus = PlusStore()
    @StateObject private var gameCenter = GameCenterManager()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(plus)
                .environmentObject(gameCenter)
                .onOpenURL { url in
                    handle(url: url)
                }
                .onChange(of: plus.isPlus, initial: true) { _, active in
                    store.plusActive = active
                }
        }
    }

    /// sumline://duel/CODE[?d=1] — opens the shared board directly, with
    /// the diagonal rule riding along in the link.
    private func handle(url: URL) {
        guard url.scheme == "sumline" else { return }
        let raw: String?
        if url.host == "duel" {
            raw = url.pathComponents.count > 1 ? url.pathComponents[1] : nil
        } else if url.host != nil, url.pathComponents.count <= 1 {
            raw = url.host
        } else {
            raw = nil
        }
        let diagonal = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.contains { $0.name == "d" && $0.value == "1" } ?? false
        if let raw, let code = DuelCode.normalize(raw) {
            store.pendingDuel = DuelInvite(code: code, diagonal: diagonal)
        }
    }
}
