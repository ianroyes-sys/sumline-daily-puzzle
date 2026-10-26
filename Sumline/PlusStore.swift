import Foundation
import StoreKit

/// Sumline+ — StoreKit 2. The philosophy: every puzzle is free forever.
/// Plus buys strategic power (streak shield, unlimited hints, insights),
/// never access to the games themselves.
@MainActor
final class PlusStore: ObservableObject {

    static let monthlyID = "com.ianroyz.sumline.plus.monthly"
    static let yearlyID = "com.ianroyz.sumline.plus.yearly"
    static let lifetimeID = "com.ianroyz.sumline.plus.lifetime"
    static let allIDs = [monthlyID, yearlyID, lifetimeID]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPlus: Bool
    @Published private(set) var purchaseInFlight = false

    private var updatesTask: Task<Void, Never>?
    private let cacheKey = "sumline.plus.cached"

    init() {
        isPlus = UserDefaults.standard.bool(forKey: cacheKey)
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        guard products.isEmpty else { return }
        products = ((try? await Product.products(for: Self.allIDs)) ?? [])
            .sorted { $0.price < $1.price }
    }

    func refreshEntitlement() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Self.allIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPlus = active
        UserDefaults.standard.set(active, forKey: cacheKey)
    }

    func purchase(_ product: Product) async {
        guard !purchaseInFlight else { return }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
            await refreshEntitlement()
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }
}
