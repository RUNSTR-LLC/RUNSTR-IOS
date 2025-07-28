import Foundation
import StoreKit
import Combine


@MainActor
class SubscriptionService: ObservableObject {
    @Published var availableProducts: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionStatus: SubscriptionStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        // Listen for transaction updates
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    func loadProducts() async {
        do {
            isLoading = true
            let productIDs = [
                SubscriptionTier.member.productID,
                SubscriptionTier.captain.productID,
                SubscriptionTier.organization.productID
            ]
            
            // Load real StoreKit products in production
            let storeKitProducts = try await Product.products(for: productIDs)
            availableProducts = storeKitProducts
            print("✅ Loaded \(availableProducts.count) real subscription products from App Store")
            
        } catch {
            errorMessage = "Failed to load subscription products: \(error.localizedDescription)"
            print("❌ Failed to load products: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Handling
    func purchase(_ product: Product, paymentMethod: PaymentMethod = .applePay) async -> Bool {
        do {
            isLoading = true
            errorMessage = nil
            
            // Real StoreKit purchase flow
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updateSubscriptionStatus()
                    print("✅ Successfully purchased: \(product.displayName)")
                    return true
                case .unverified:
                    errorMessage = "Purchase verification failed"
                    return false
                }
            case .userCancelled:
                errorMessage = "Purchase was cancelled"
                return false
            case .pending:
                errorMessage = "Purchase is pending approval"
                return false
            @unknown default:
                errorMessage = "Unknown purchase result"
                return false
            }
            
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase failed: \(error)")
            return false
        }
    }
    
    func purchaseWithBitcoin(_ tier: SubscriptionTier) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        // Mock Bitcoin purchase flow
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
        
        let success = Bool.random() // Mock success/failure
        
        if success {
            let newStatus = SubscriptionStatus(
                tier: tier,
                isActive: true,
                expirationDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
                autoRenew: false, // Bitcoin payments don't auto-renew
                paymentMethod: .bitcoin,
                purchaseDate: Date()
            )
            
            subscriptionStatus = newStatus
            print("✅ Bitcoin purchase successful for \(tier.displayName)")
        } else {
            errorMessage = "Bitcoin payment failed or was cancelled"
        }
        
        isLoading = false
        return success
    }
    
    // MARK: - Subscription Management
    func restorePurchases() async {
        isLoading = true
        
        // Real StoreKit restore functionality
        do {
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    if let tier = SubscriptionTier.allCases.first(where: { $0.productID == transaction.productID }) {
                        let status = SubscriptionStatus(
                            tier: tier,
                            isActive: true,
                            expirationDate: transaction.expirationDate,
                            autoRenew: transaction.isUpgraded == false,
                            paymentMethod: .applePay,
                            purchaseDate: transaction.purchaseDate
                        )
                        subscriptionStatus = status
                        break // Only need the first valid subscription
                    }
                case .unverified:
                    continue // Skip unverified transactions
                }
            }
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ Failed to restore purchases: \(error)")
        }
        
        isLoading = false
    }
    
    func cancelSubscription() async -> Bool {
        // In production, this would redirect to App Store subscription management
        // For now, we'll mock the cancellation
        
        guard var currentStatus = subscriptionStatus else { return false }
        
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Update status to reflect cancellation
        subscriptionStatus = SubscriptionStatus(
            tier: currentStatus.tier,
            isActive: currentStatus.isActive,
            expirationDate: currentStatus.expirationDate,
            autoRenew: false, // Cancel auto-renewal
            paymentMethod: currentStatus.paymentMethod,
            purchaseDate: currentStatus.purchaseDate
        )
        
        isLoading = false
        return true
    }
    
    // MARK: - Status Updates
    private func updateSubscriptionStatus() async {
        // Mock subscription status check
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check UserDefaults for mock subscription
        if let savedTier = UserDefaults.standard.string(forKey: "subscription_tier"),
           let tier = SubscriptionTier(rawValue: savedTier) {
            
            let status = SubscriptionStatus(
                tier: tier,
                isActive: true,
                expirationDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
                autoRenew: true,
                paymentMethod: .applePay,
                purchaseDate: Date().addingTimeInterval(-86400 * 7) // 7 days ago
            )
            
            subscriptionStatus = status
        } else {
            subscriptionStatus = SubscriptionStatus(
                tier: .none,
                isActive: false,
                expirationDate: nil,
                autoRenew: false,
                paymentMethod: .applePay,
                purchaseDate: Date()
            )
        }
    }
    
    // MARK: - Transaction Listening
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Mock transaction listener
            for await _ in AsyncStream<Int>.makeStream().stream {
                await self.updateSubscriptionStatus()
            }
        }
    }
}

// MARK: - Helper Extensions
extension SubscriptionTier {
    func isUpgradeFrom(_ currentTier: SubscriptionTier) -> Bool {
        let tierOrder: [SubscriptionTier] = [.none, .member, .captain, .organization]
        guard let currentIndex = tierOrder.firstIndex(of: currentTier),
              let newIndex = tierOrder.firstIndex(of: self) else {
            return false
        }
        return newIndex > currentIndex
    }
}