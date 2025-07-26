import Foundation
import StoreKit
import Combine

// MARK: - Mock Product Protocol for Development
protocol MockProductProtocol {
    var id: String { get }
    var displayName: String { get }
    var displayPrice: String { get }
    var price: Double { get }
}

@MainActor
class SubscriptionService: ObservableObject {
    @Published var availableProducts: [MockProductProtocol] = []
    @Published var purchasedSubscriptions: [MockProductProtocol] = []
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
            
            // Mock products for development - replace with real StoreKit in production
            availableProducts = createMockProducts()
            print("✅ Loaded \(availableProducts.count) subscription products")
            
        } catch {
            errorMessage = "Failed to load subscription products: \(error.localizedDescription)"
            print("❌ Failed to load products: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Handling
    func purchase(_ product: MockProductProtocol, paymentMethod: PaymentMethod = .applePay) async -> Bool {
        do {
            isLoading = true
            errorMessage = nil
            
            // Mock purchase for development
            let mockPurchase = await mockPurchaseFlow(product: product, paymentMethod: paymentMethod)
            
            if mockPurchase {
                await updateSubscriptionStatus()
                print("✅ Successfully purchased: \(product.displayName)")
                return true
            } else {
                errorMessage = "Purchase was cancelled or failed"
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
        
        // Mock restore for development
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Check for existing subscription in UserDefaults (mock)
        if let savedTier = UserDefaults.standard.string(forKey: "subscription_tier"),
           let tier = SubscriptionTier(rawValue: savedTier) {
            
            let status = SubscriptionStatus(
                tier: tier,
                isActive: true,
                expirationDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
                autoRenew: true,
                paymentMethod: .applePay,
                purchaseDate: Date().addingTimeInterval(-86400 * 15) // 15 days ago
            )
            
            subscriptionStatus = status
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
    
    // MARK: - Mock Implementations (Remove in Production)
    private func createMockProducts() -> [MockProductProtocol] {
        return [
            MockProduct(
                id: SubscriptionTier.member.productID,
                displayName: SubscriptionTier.member.displayName,
                price: SubscriptionTier.member.monthlyPrice
            ),
            MockProduct(
                id: SubscriptionTier.captain.productID,
                displayName: SubscriptionTier.captain.displayName,
                price: SubscriptionTier.captain.monthlyPrice
            ),
            MockProduct(
                id: SubscriptionTier.organization.productID,
                displayName: SubscriptionTier.organization.displayName,
                price: SubscriptionTier.organization.monthlyPrice
            )
        ]
    }
    
    private func mockPurchaseFlow(product: MockProductProtocol, paymentMethod: PaymentMethod) async -> Bool {
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
        
        let success = true // Always succeed in mock
        
        if success {
            // Save to UserDefaults for persistence
            if let tier = SubscriptionTier.allCases.first(where: { $0.productID == product.id }) {
                UserDefaults.standard.set(tier.rawValue, forKey: "subscription_tier")
            }
        }
        
        return success
    }
}

// MARK: - Mock Product (Remove in Production)
struct MockProduct: MockProductProtocol {
    let id: String
    let displayName: String
    let price: Double
    
    var displayPrice: String { String(format: "$%.2f", price) }
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