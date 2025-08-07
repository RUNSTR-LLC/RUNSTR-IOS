import Foundation
import StoreKit
import Security
import Combine

/// Manages subscription state synchronization between SubscriptionService and User model
/// Handles secure persistence of subscription data to iOS Keychain
@MainActor
class SubscriptionManager: ObservableObject {
    @Published var currentSubscription: SubscriptionStatus?
    
    private let authService: AuthenticationService
    private let subscriptionService: SubscriptionService
    
    // Keychain constants
    private let keychainService = "com.runstr.ios.subscription"
    private let subscriptionStatusKey = "subscription_status"
    
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthenticationService, subscriptionService: SubscriptionService) {
        self.authService = authService
        self.subscriptionService = subscriptionService
        
        // Load persisted subscription state
        loadPersistedSubscriptionStatus()
        
        // Observe subscription service changes
        subscriptionService.$subscriptionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                self?.handleSubscriptionStatusChange(newStatus)
            }
            .store(in: &cancellables)
        
        // Observe user changes
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.handleUserChange(user)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Sync subscription status from SubscriptionService to User model
    func syncSubscriptionToUser() async {
        guard var currentUser = authService.currentUser,
              let subscriptionStatus = subscriptionService.subscriptionStatus else {
            return
        }
        
        // Update user model with latest subscription status
        currentUser.updateSubscriptionStatus(subscriptionStatus)
        
        // Update auth service with modified user
        await authService.updateCurrentUser(currentUser)
        
        // Persist to keychain
        persistSubscriptionStatus(subscriptionStatus)
        
        // Update local state
        currentSubscription = subscriptionStatus
    }
    
    /// Sync subscription status from User model to SubscriptionService
    func syncSubscriptionFromUser() async {
        guard let currentUser = authService.currentUser else { return }
        
        // Update subscription service with user's status
        subscriptionService.subscriptionStatus = currentUser.subscriptionStatus
        
        // Update local state
        currentSubscription = currentUser.subscriptionStatus
    }
    
    /// Handle successful subscription purchase
    func handleSuccessfulPurchase(_ product: Product, transaction: Transaction) async -> Bool {
        guard let subscriptionTier = SubscriptionTier.allCases.first(where: { $0.productID == product.id }),
              var currentUser = authService.currentUser else {
            return false
        }
        
        // Create new subscription status
        let newStatus = SubscriptionStatus(
            tier: subscriptionTier,
            isActive: true,
            expirationDate: transaction.expirationDate,
            autoRenew: transaction.isUpgraded == false,
            paymentMethod: .applePay,
            purchaseDate: transaction.purchaseDate
        )
        
        // Update user model
        currentUser.updateSubscriptionStatus(newStatus)
        
        // Update auth service
        await authService.updateCurrentUser(currentUser)
        
        // Update subscription service
        subscriptionService.subscriptionStatus = newStatus
        
        // Persist to keychain
        persistSubscriptionStatus(newStatus)
        
        // Update local state
        currentSubscription = newStatus
        
        print("✅ Successfully processed subscription purchase: \(subscriptionTier.displayName)")
        return true
    }
    
    /// Handle subscription cancellation
    func handleSubscriptionCancellation() async -> Bool {
        guard var currentUser = authService.currentUser else { return false }
        
        // Cancel subscription (keeps active until expiration)
        currentUser.cancelSubscription()
        
        // Update auth service
        await authService.updateCurrentUser(currentUser)
        
        // Update subscription service
        subscriptionService.subscriptionStatus = currentUser.subscriptionStatus
        
        // Persist to keychain
        persistSubscriptionStatus(currentUser.subscriptionStatus)
        
        // Update local state
        currentSubscription = currentUser.subscriptionStatus
        
        print("✅ Successfully cancelled subscription")
        return true
    }
    
    /// Check if user can access specific features
    func canAccessFeature(requiredTier: SubscriptionTier) -> Bool {
        guard let currentUser = authService.currentUser else { return false }
        return currentUser.canAccessFeature(requiredTier: requiredTier)
    }
    
    /// Get current subscription tier
    var currentTier: SubscriptionTier {
        return currentSubscription?.tier ?? .none
    }
    
    /// Check if subscription is active and not expired
    var hasActiveSubscription: Bool {
        guard let subscription = currentSubscription else { return false }
        return subscription.isActive && !subscription.isExpired
    }
    
    // MARK: - Private Methods
    
    private func handleSubscriptionStatusChange(_ newStatus: SubscriptionStatus?) {
        guard let newStatus = newStatus else { return }
        
        Task {
            // Update user model if different
            if authService.currentUser?.subscriptionStatus.tier != newStatus.tier ||
               authService.currentUser?.subscriptionStatus.isActive != newStatus.isActive {
                await syncSubscriptionToUser()
            }
        }
    }
    
    private func handleUserChange(_ user: User?) {
        guard let user = user else {
            currentSubscription = nil
            return
        }
        
        // Update local subscription state from user
        currentSubscription = user.subscriptionStatus
        
        // Sync to subscription service if different
        if subscriptionService.subscriptionStatus?.tier != user.subscriptionStatus.tier {
            Task {
                await syncSubscriptionFromUser()
            }
        }
    }
    
    // MARK: - Keychain Persistence
    
    private func persistSubscriptionStatus(_ status: SubscriptionStatus) {
        do {
            let data = try JSONEncoder().encode(status)
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: subscriptionStatusKey,
                kSecValueData as String: data
            ]
            
            // Delete existing item
            SecItemDelete(query as CFDictionary)
            
            // Add new item
            let status = SecItemAdd(query as CFDictionary, nil)
            
            if status == errSecSuccess {
                print("✅ Successfully persisted subscription status to keychain")
            } else {
                print("❌ Failed to persist subscription status: \(status)")
            }
            
        } catch {
            print("❌ Failed to encode subscription status: \(error)")
        }
    }
    
    private func loadPersistedSubscriptionStatus() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: subscriptionStatusKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data {
            
            do {
                let subscriptionStatus = try JSONDecoder().decode(SubscriptionStatus.self, from: data)
                currentSubscription = subscriptionStatus
                print("✅ Loaded subscription status from keychain: \(subscriptionStatus.tier.displayName)")
            } catch {
                print("❌ Failed to decode subscription status: \(error)")
                removePersistedSubscriptionStatus()
            }
        } else if status != errSecItemNotFound {
            print("❌ Failed to load subscription status from keychain: \(status)")
        }
    }
    
    private func removePersistedSubscriptionStatus() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: subscriptionStatusKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ Cleared subscription status from keychain")
        } else {
            print("❌ Failed to clear subscription status from keychain: \(status)")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - Extensions

extension AuthenticationService {
    /// Update current user (helper method for SubscriptionManager)
    func updateCurrentUser(_ user: User) async {
        // This would typically involve saving to persistent storage
        // For now, just update the in-memory user
        currentUser = user
        
        // In a production app, this would also:
        // 1. Save to Core Data or CloudKit
        // 2. Sync with backend API
        // 3. Update any other relevant services
        
        print("✅ Updated current user with new subscription status")
    }
}