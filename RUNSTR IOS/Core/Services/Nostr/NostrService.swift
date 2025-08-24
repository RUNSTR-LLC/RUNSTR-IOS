import Foundation
import Combine
import NostrSDK
import CoreLocation

/// Main Nostr service orchestrator that coordinates specialized services
@MainActor
class NostrService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var userKeyPair: NostrKeyPair?
    @Published var errorMessage: String?
    
    // MARK: - Specialized Services
    private let keyManager: NostrKeyManager
    private let connectionManager: NostrConnectionManager
    private let eventPublisher: NostrEventPublisher
    private let profileService: NostrProfileService
    private let cacheManager: NostrCacheManager
    private let workoutService: NostrWorkoutService
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        print("📱 NostrService initialized with specialized services architecture")
        
        // Initialize specialized services
        self.keyManager = NostrKeyManager()
        self.connectionManager = NostrConnectionManager()
        self.eventPublisher = NostrEventPublisher(connectionManager: connectionManager)
        self.profileService = NostrProfileService(
            connectionManager: connectionManager,
            eventPublisher: eventPublisher
        )
        self.cacheManager = NostrCacheManager()
        self.workoutService = NostrWorkoutService(connectionManager: connectionManager)
        
        setupBindings()
        
        // Start background services asynchronously
        Task {
            await startBackgroundServices()
        }
    }
    
    // MARK: - Key Management (Delegated)
    
    /// Generate new Nostr key pair
    func generateRunstrKeys() -> NostrKeyPair? {
        return keyManager.generateKeyPair()
    }
    
    /// Store key pair securely
    func storeKeyPair(_ keyPair: NostrKeyPair) {
        do {
            try keyManager.storeKeyPair(keyPair)
            userKeyPair = keyPair
            print("✅ Keys stored and updated in main service")
        } catch {
            errorMessage = "Failed to store keys: \(error.localizedDescription)"
            print("❌ Failed to store keys: \(error)")
        }
    }
    
    // MARK: - Connection Management (Delegated)
    
    /// Connect to Nostr relays
    func connect() async {
        await connectionManager.connect()
    }
    
    /// Disconnect from relays
    func disconnect() async {
        await connectionManager.disconnect()
    }
    
    // MARK: - Event Publishing (Delegated)
    
    /// Publish workout as formatted social post
    func publishWorkoutEvent(_ workout: Workout) async -> Bool {
        return await eventPublisher.publishWorkoutEvent(workout, using: keyManager)
    }
    
    /// Publish structured workout record (Kind 1301)
    func publishWorkoutRecord(_ workout: Workout) async -> Bool {
        return await eventPublisher.publishWorkoutRecord(workout, using: keyManager)
    }
    
    /// Publish text note
    func publishTextNote(_ content: String) async -> Bool {
        return await eventPublisher.publishTextNote(content, using: keyManager)
    }
    
    /// Publish user profile
    func publishProfile(name: String, about: String? = nil, picture: String? = nil) async -> Bool {
        return await eventPublisher.publishProfile(name: name, about: about, picture: picture, using: keyManager)
    }
    
    // MARK: - Profile Management (Delegated)
    
    /// Fetch profile from Nostr relays with caching
    func fetchProfile(pubkey: String) async -> NostrProfile? {
        // Check cache first
        if let cachedProfile = cacheManager.getCachedProfile(pubkey: pubkey) {
            print("✅ Using cached profile for \(pubkey.prefix(16))...")
            return cachedProfile
        }
        
        // Fetch from relays
        if let profile = await profileService.fetchProfile(pubkey: pubkey) {
            // Cache the fetched profile
            await cacheManager.cacheProfile(pubkey: pubkey, profile: profile)
            return profile
        }
        
        return nil
    }
    
    /// Update user profile
    func updateUserProfile(name: String, about: String? = nil, picture: String? = nil) async -> Bool {
        return await profileService.updateUserProfile(name: name, about: about, picture: picture, using: keyManager)
    }
    
    /// Fetch user's own profile
    func fetchOwnProfile() async -> Bool {
        return await profileService.fetchOwnProfile(using: keyManager)
    }
    
    // MARK: - Caching Management (Delegated)
    
    /// Clear all profile cache
    func clearProfileCache() async {
        await cacheManager.clearAllCache()
    }
    
    /// Clear cache for specific pubkey
    func clearProfileCache(for pubkey: String) async {
        await cacheManager.clearCache(for: pubkey)
    }
    
    /// Start background profile updates
    func startBackgroundProfileUpdates() async {
        await cacheManager.startBackgroundUpdates(profileService: profileService)
    }
    
    /// Stop background profile updates
    func stopBackgroundProfileUpdates() async {
        await cacheManager.stopBackgroundUpdates()
    }
    
    // MARK: - Workout Management (Delegated)
    
    /// Fetch user's workout history
    func fetchUserWorkouts(limit: Int = 100, since: Date? = nil) async -> [Workout] {
        return await workoutService.fetchUserWorkouts(limit: limit, since: since, using: keyManager)
    }
    
    /// Parse Nostr event into Workout
    func parseWorkoutFromNostrEvent(_ event: NostrEvent) -> Workout? {
        return workoutService.parseWorkoutFromNostrEvent(event)
    }
    
    // MARK: - Service Management
    
    /// Get service health status
    func getServiceStatus() -> ServiceStatus {
        let keyStatus = keyManager.hasKeys
        let connectionStatus = connectionManager.isConnected
        let cacheStats = cacheManager.getCacheStatistics()
        
        return ServiceStatus(
            hasKeys: keyStatus,
            isConnected: connectionStatus,
            cachedProfiles: cacheStats.total,
            freshProfiles: cacheStats.fresh,
            staleProfiles: cacheStats.stale
        )
    }
    
    /// Force refresh all services
    func refreshAllServices() async {
        print("🔄 Refreshing all Nostr services...")
        
        // Reconnect to relays
        await connectionManager.reconnect()
        
        // Clean up expired cache
        cacheManager.cleanupExpiredCache()
        
        // Fetch own profile if keys are available
        if keyManager.hasKeys {
            _ = await fetchOwnProfile()
        }
        
        print("✅ All Nostr services refreshed")
    }
    
    // MARK: - Private Helper Methods
    
    /// Setup reactive bindings between services
    private func setupBindings() {
        // Bind key manager's key pair to published property
        keyManager.$currentKeyPair
            .receive(on: DispatchQueue.main)
            .assign(to: \.userKeyPair, on: self)
            .store(in: &cancellables)
        
        // Bind connection manager's connection state
        connectionManager.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
        
        // Bind error messages from all services
        connectionManager.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        eventPublisher.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        profileService.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        workoutService.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        print("✅ Service bindings configured")
    }
    
    /// Start background services
    private func startBackgroundServices() async {
        // Start background profile updates
        await startBackgroundProfileUpdates()
        
        print("✅ Background services started")
    }
    
    // MARK: - Cleanup
    deinit {
        // Note: Cannot call @MainActor methods from deinit
        // Background updates will be stopped when cacheManager is deinitialized
        cancellables.removeAll()
        print("🧹 NostrService cleaned up")
    }
}

// MARK: - Supporting Types

struct ServiceStatus {
    let hasKeys: Bool
    let isConnected: Bool
    let cachedProfiles: Int
    let freshProfiles: Int
    let staleProfiles: Int
    
    var isHealthy: Bool {
        return hasKeys && isConnected
    }
    
    var description: String {
        var status = "Nostr Service Status:\n"
        status += "🔑 Keys: \(hasKeys ? "✅" : "❌")\n"
        status += "🌐 Connected: \(isConnected ? "✅" : "❌")\n"
        status += "💾 Cached Profiles: \(cachedProfiles) (fresh: \(freshProfiles), stale: \(staleProfiles))"
        return status
    }
}