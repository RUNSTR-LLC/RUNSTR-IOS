import Foundation
import StoreKit
import Combine

// MARK: - Timeout Utilities

struct TimeoutError: Error {
    let message: String = "Operation timed out"
}

func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }
        
        // Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        // Return the first completed result
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}


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
    func purchase(_ product: Product, paymentMethod: PaymentMethod = .applePay, retryCount: Int = 0) async -> Bool {
        let maxRetries = 3
        let baseDelay: TimeInterval = 1.0
        
        do {
            isLoading = true
            errorMessage = nil
            
            // Pre-purchase validation
            guard await validatePurchaseEligibility(for: product) else {
                errorMessage = "Purchase not available at this time"
                isLoading = false
                return false
            }
            
            // Attempt purchase with timeout
            let result = try await withTimeout(seconds: 30) {
                try await product.purchase()
            }
            
            switch result {
            case .success(let verification):
                return await handlePurchaseSuccess(verification, product: product)
                
            case .userCancelled:
                errorMessage = nil // Don't show error for user cancellation
                isLoading = false
                return false
                
            case .pending:
                return await handlePendingPurchase(product: product)
                
            @unknown default:
                errorMessage = "Unknown purchase result"
                isLoading = false
                return false
            }
            
        } catch let error as StoreKitError {
            return await handleStoreKitError(error, product: product, retryCount: retryCount, maxRetries: maxRetries, baseDelay: baseDelay)
        } catch is TimeoutError {
            return await handleTimeoutError(product: product, retryCount: retryCount, maxRetries: maxRetries, baseDelay: baseDelay)
        } catch {
            return await handleGeneralError(error, product: product, retryCount: retryCount, maxRetries: maxRetries, baseDelay: baseDelay)
        }
    }
    
    // MARK: - Purchase Flow Helpers
    
    private func validatePurchaseEligibility(for product: Product) async -> Bool {
        // Check if products are loaded
        guard !availableProducts.isEmpty else {
            await loadProducts()
            return !availableProducts.isEmpty
        }
        
        // Check if product is still available
        guard availableProducts.contains(where: { $0.id == product.id }) else {
            print("❌ Product no longer available: \(product.id)")
            return false
        }
        
        // Check for existing active subscription of same or higher tier
        if let currentStatus = subscriptionStatus,
           currentStatus.isActive && !currentStatus.isExpired,
           let currentTier = SubscriptionTier.allCases.first(where: { $0.productID == product.id }),
           let newTier = SubscriptionTier.allCases.first(where: { $0.productID == product.id }) {
            
            if !newTier.isUpgradeFrom(currentTier) {
                print("❌ Cannot downgrade or purchase same tier")
                return false
            }
        }
        
        return true
    }
    
    private func handlePurchaseSuccess(_ verification: VerificationResult<Transaction>, product: Product) async -> Bool {
        switch verification {
        case .verified(let transaction):
            // Additional cryptographic verification
            guard await verifyTransaction(transaction) else {
                errorMessage = "Transaction verification failed"
                isLoading = false
                return false
            }
            
            // Finish transaction
            await transaction.finish()
            
            // Update subscription status
            await updateSubscriptionStatus()
            
            // Log success
            print("✅ Successfully purchased: \(product.displayName)")
            print("✅ Transaction ID: \(transaction.id)")
            print("✅ Expires: \(transaction.expirationDate?.formatted() ?? "N/A")")
            
            isLoading = false
            return true
            
        case .unverified(let transaction, let error):
            print("❌ Transaction verification failed: \(error)")
            errorMessage = "Purchase verification failed. Please try again or contact support."
            
            // Still finish unverified transaction to avoid reprocessing
            await transaction.finish()
            
            isLoading = false
            return false
        }
    }
    
    private func handlePendingPurchase(product: Product) async -> Bool {
        // For pending purchases (like parental approval), we should not show an error
        // Instead, update UI to show pending state and monitor for updates
        errorMessage = nil
        print("⏳ Purchase pending approval for: \(product.displayName)")
        
        // Start monitoring for transaction updates
        Task {
            await monitorPendingTransaction(productID: product.id)
        }
        
        isLoading = false
        return false // Return false for now, will be updated when approved
    }
    
    private func handleStoreKitError(_ error: StoreKitError, product: Product, retryCount: Int, maxRetries: Int, baseDelay: TimeInterval) async -> Bool {
        switch error {
        case .networkError:
            if retryCount < maxRetries {
                let delay = baseDelay * pow(2.0, Double(retryCount)) // Exponential backoff
                print("🔄 Network error, retrying in \(delay)s (attempt \(retryCount + 1)/\(maxRetries + 1))")
                
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return await purchase(product, retryCount: retryCount + 1)
            } else {
                errorMessage = "Network error. Please check your connection and try again."
            }
            
        case .systemError:
            errorMessage = "System error. Please restart the app and try again."
            
        case .notAvailableInStorefront:
            errorMessage = "This subscription is not available in your region."
            
        case .notEntitled:
            errorMessage = "You are not authorized to make this purchase."
            
        @unknown default:
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        
        print("❌ StoreKit error: \(error)")
        isLoading = false
        return false
    }
    
    private func handleTimeoutError(product: Product, retryCount: Int, maxRetries: Int, baseDelay: TimeInterval) async -> Bool {
        if retryCount < maxRetries {
            let delay = baseDelay * pow(2.0, Double(retryCount))
            print("🔄 Purchase timeout, retrying in \(delay)s (attempt \(retryCount + 1)/\(maxRetries + 1))")
            
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return await purchase(product, retryCount: retryCount + 1)
        } else {
            errorMessage = "Purchase timed out. Please try again."
            print("❌ Purchase timed out after \(maxRetries + 1) attempts")
            isLoading = false
            return false
        }
    }
    
    private func handleGeneralError(_ error: Error, product: Product, retryCount: Int, maxRetries: Int, baseDelay: TimeInterval) async -> Bool {
        // For certain recoverable errors, allow retry
        if retryCount < maxRetries && isRecoverableError(error) {
            let delay = baseDelay * pow(2.0, Double(retryCount))
            print("🔄 Recoverable error, retrying in \(delay)s (attempt \(retryCount + 1)/\(maxRetries + 1)): \(error)")
            
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return await purchase(product, retryCount: retryCount + 1)
        } else {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    private func isRecoverableError(_ error: Error) -> Bool {
        // Define which errors are worth retrying
        let nsError = error as NSError
        
        // Network-related errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func verifyTransaction(_ transaction: Transaction) async -> Bool {
        // Additional security verification beyond StoreKit's built-in verification
        
        // Verify transaction timestamp is recent (within 24 hours)
        let twentyFourHoursAgo = Date().addingTimeInterval(-86400)
        guard transaction.purchaseDate > twentyFourHoursAgo else {
            print("❌ Transaction too old: \(transaction.purchaseDate)")
            return false
        }
        
        // Verify product ID matches expected subscription
        guard SubscriptionTier.allCases.contains(where: { $0.productID == transaction.productID }) else {
            print("❌ Unknown product ID: \(transaction.productID)")
            return false
        }
        
        // TODO: Add server-side receipt validation for additional security
        // This would involve sending the transaction to RUNSTR backend for verification
        
        return true
    }
    
    private func monitorPendingTransaction(productID: String) async {
        // Monitor for up to 24 hours for pending transaction approval
        let maxWaitTime: TimeInterval = 24 * 60 * 60 // 24 hours
        let checkInterval: TimeInterval = 30 // Check every 30 seconds
        let maxChecks = Int(maxWaitTime / checkInterval)
        
        for _ in 0..<maxChecks {
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            
            // Check if transaction was approved
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    if transaction.productID == productID {
                        print("✅ Pending purchase approved: \(productID)")
                        await updateSubscriptionStatus()
                        return
                    }
                case .unverified:
                    continue
                }
            }
        }
        
        print("⏰ Stopped monitoring pending transaction: \(productID)")
    }
    
    func purchaseWithBitcoin(_ tier: SubscriptionTier) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // TODO: Integrate with actual Lightning payment processor (Zebedee, Strike, etc.)
            // For now, this will always fail until Bitcoin payment integration is complete
            errorMessage = "Bitcoin payments not yet implemented in production"
            
        } catch {
            errorMessage = "Bitcoin payment failed: \(error.localizedDescription)"
        }
        
        isLoading = false
        return false // Always return false until Bitcoin integration is complete
    }
    
    // MARK: - Subscription Management
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        var restoredSubscriptions: [SubscriptionStatus] = []
        var hasFoundValidSubscription = false
        
        do {
            print("🔄 Starting subscription restore process...")
            
            // Collect all current entitlements
            var entitlements: [Transaction] = []
            
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    // Verify transaction is for a known subscription product
                    if SubscriptionTier.allCases.contains(where: { $0.productID == transaction.productID }) {
                        entitlements.append(transaction)
                        print("✅ Found valid entitlement: \(transaction.productID)")
                    } else {
                        print("⚠️ Unknown product in entitlements: \(transaction.productID)")
                    }
                    
                case .unverified(let transaction, let error):
                    print("❌ Unverified transaction: \(transaction.productID) - \(error)")
                    continue
                }
            }
            
            // Process entitlements and find the highest active tier
            var highestTier: SubscriptionTier = .none
            var newestTransaction: Transaction?
            
            for transaction in entitlements {
                guard let tier = SubscriptionTier.allCases.first(where: { $0.productID == transaction.productID }) else {
                    continue
                }
                
                // Check if this subscription is still valid
                let isActive = !isTransactionExpired(transaction)
                
                if isActive {
                    let status = SubscriptionStatus(
                        tier: tier,
                        isActive: true,
                        expirationDate: transaction.expirationDate,
                        autoRenew: transaction.isUpgraded == false,
                        paymentMethod: .applePay,
                        purchaseDate: transaction.purchaseDate
                    )
                    
                    restoredSubscriptions.append(status)
                    
                    // Track the highest tier subscription
                    let tierOrder: [SubscriptionTier] = [.none, .member, .captain, .organization]
                    if let currentIndex = tierOrder.firstIndex(of: highestTier),
                       let newIndex = tierOrder.firstIndex(of: tier),
                       newIndex > currentIndex {
                        highestTier = tier
                        newestTransaction = transaction
                    }
                    
                    hasFoundValidSubscription = true
                }
            }
            
            // Update subscription status with highest tier found
            if hasFoundValidSubscription, let transaction = newestTransaction {
                subscriptionStatus = SubscriptionStatus(
                    tier: highestTier,
                    isActive: true,
                    expirationDate: transaction.expirationDate,
                    autoRenew: transaction.isUpgraded == false,
                    paymentMethod: .applePay,
                    purchaseDate: transaction.purchaseDate
                )
                
                print("✅ Restored subscription: \(highestTier.displayName)")
                print("✅ Expires: \(transaction.expirationDate?.formatted() ?? "N/A")")
                
            } else {
                // No valid subscriptions found - user is on free tier
                subscriptionStatus = SubscriptionStatus(
                    tier: .none,
                    isActive: false,
                    expirationDate: nil,
                    autoRenew: false,
                    paymentMethod: .applePay,
                    purchaseDate: Date()
                )
                
                print("ℹ️ No active subscriptions found - user on free tier")
            }
            
            // Reconcile with current user state if needed
            await reconcileWithUserState()
            
            isLoading = false
            return hasFoundValidSubscription
            
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ Failed to restore purchases: \(error)")
            
            isLoading = false
            return false
        }
    }
    
    // MARK: - Restore Purchases Helpers
    
    private func isTransactionExpired(_ transaction: Transaction) -> Bool {
        guard let expirationDate = transaction.expirationDate else {
            // Non-subscription products don't expire
            return false
        }
        
        return Date() > expirationDate
    }
    
    private func reconcileWithUserState() async {
        // This method would sync restored subscription state with the User model
        // via the SubscriptionManager when it's integrated
        
        // For now, just log the reconciliation
        if let currentStatus = subscriptionStatus {
            print("🔄 Reconciling subscription state: \(currentStatus.tier.displayName)")
        }
        
        // TODO: Integrate with SubscriptionManager once it's connected
        // await subscriptionManager.syncSubscriptionToUser()
    }
    
    // MARK: - Subscription Upgrade/Downgrade
    
    func upgradeSubscription(to newProduct: Product) async -> Bool {
        // Validate upgrade path
        guard let currentStatus = subscriptionStatus,
              let currentTier = SubscriptionTier.allCases.first(where: { $0.productID == currentStatus.tier.productID }),
              let newTier = SubscriptionTier.allCases.first(where: { $0.productID == newProduct.id }) else {
            errorMessage = "Invalid upgrade configuration"
            return false
        }
        
        guard newTier.isUpgradeFrom(currentTier) else {
            errorMessage = "Cannot downgrade or purchase same tier"
            return false
        }
        
        // Use existing purchase flow with upgrade handling
        return await purchase(newProduct)
    }
    
    func cancelSubscription() async -> Bool {
        // Apple requires users to cancel through App Store settings
        // We can only update our local state to reflect non-renewal
        
        guard var currentStatus = subscriptionStatus,
              currentStatus.isActive else {
            errorMessage = "No active subscription to cancel"
            return false
        }
        
        isLoading = true
        
        // Update local status to show cancellation (still active until expiration)
        subscriptionStatus = SubscriptionStatus(
            tier: currentStatus.tier,
            isActive: currentStatus.isActive,
            expirationDate: currentStatus.expirationDate,
            autoRenew: false, // This is the key change
            paymentMethod: currentStatus.paymentMethod,
            purchaseDate: currentStatus.purchaseDate
        )
        
        print("✅ Subscription set to cancel at expiration: \(currentStatus.expirationDate?.formatted() ?? "N/A")")
        
        // TODO: Notify backend of cancellation for analytics
        
        isLoading = false
        return true
    }
    
    // MARK: - Status Updates
    private func updateSubscriptionStatus() async {
        do {
            // Check current StoreKit entitlements for active subscriptions
            var hasActiveSubscription = false
            
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
                        hasActiveSubscription = true
                        print("✅ Found active subscription: \(tier.displayName)")
                        break
                    }
                case .unverified:
                    continue // Skip unverified transactions
                }
            }
            
            // If no active subscription found, set to free tier
            if !hasActiveSubscription {
                subscriptionStatus = SubscriptionStatus(
                    tier: .none,
                    isActive: false,
                    expirationDate: nil,
                    autoRenew: false,
                    paymentMethod: .applePay,
                    purchaseDate: Date()
                )
            }
            
        } catch {
            print("❌ Failed to update subscription status: \(error)")
            errorMessage = "Failed to check subscription status: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Transaction Listening
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Listen for StoreKit transaction updates
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    print("✅ Transaction update received: \(transaction.productID)")
                    await self.updateSubscriptionStatus()
                    
                    // Finish the transaction
                    await transaction.finish()
                    
                case .unverified:
                    print("❌ Received unverified transaction update")
                }
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