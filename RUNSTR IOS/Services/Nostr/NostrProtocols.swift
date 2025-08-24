import Foundation
import NostrSDK
import CoreLocation

// MARK: - Key Management Protocol

protocol NostrKeyManagerProtocol: AnyObject {
    /// Generate new Nostr key pair
    func generateKeyPair() -> NostrKeyPair?
    
    /// Store key pair securely in iOS Keychain
    func storeKeyPair(_ keyPair: NostrKeyPair) throws
    
    /// Load stored key pair from Keychain
    func loadStoredKeyPair() -> NostrKeyPair?
    
    /// Get current key pair
    var currentKeyPair: NostrKeyPair? { get }
    
    /// Get NostrSDK keypair for signing
    var nostrSDKKeypair: Keypair? { get }
    
    /// Ensure keys are available, generating and storing new ones if needed
    func ensureKeysAvailable() throws -> NostrKeyPair
}

// MARK: - Connection Management Protocol

protocol NostrConnectionManagerProtocol: AnyObject {
    /// Connection state
    var isConnected: Bool { get }
    
    /// Connect to Nostr relays
    func connect() async
    
    /// Disconnect from relays
    func disconnect() async
    
    /// Get relay pool for publishing/subscribing
    var relayPool: RelayPool? { get }
}

// MARK: - Event Publishing Protocol

protocol NostrEventPublisherProtocol: AnyObject {
    /// Publish workout event (Kind 1301)
    func publishWorkoutEvent(_ workout: Workout, using keyManager: NostrKeyManagerProtocol) async -> Bool
    
    /// Publish workout record (Kind 1301)
    func publishWorkoutRecord(_ workout: Workout, using keyManager: NostrKeyManagerProtocol) async -> Bool
    
    /// Publish text note (Kind 1)
    func publishTextNote(_ content: String, using keyManager: NostrKeyManagerProtocol) async -> Bool
    
    /// Publish profile metadata (Kind 0)
    func publishProfile(name: String, about: String?, picture: String?, using keyManager: NostrKeyManagerProtocol) async -> Bool
}

// MARK: - Profile Management Protocol

protocol NostrProfileServiceProtocol: AnyObject {
    /// Fetch profile metadata from Nostr relays
    func fetchProfile(pubkey: String) async -> NostrProfile?
    
    /// Fetch user's own profile
    func fetchOwnProfile(using keyManager: NostrKeyManagerProtocol) async -> Bool
    
    /// Update user profile and publish to Nostr
    func updateUserProfile(name: String, about: String?, picture: String?, using keyManager: NostrKeyManagerProtocol) async -> Bool
}

// MARK: - Cache Management Protocol

protocol NostrCacheManagerProtocol: AnyObject {
    /// Cache profile data locally
    func cacheProfile(pubkey: String, profile: NostrProfile) async
    
    /// Get cached profile if not expired
    func getCachedProfile(pubkey: String) -> NostrProfile?
    
    /// Clear all cached profile data
    func clearAllCache() async
    
    /// Clear cache for specific pubkey
    func clearCache(for pubkey: String) async
    
    /// Start background profile updates
    func startBackgroundUpdates(profileService: NostrProfileServiceProtocol) async
    
    /// Stop background profile updates
    func stopBackgroundUpdates() async
}

// MARK: - Workout Service Protocol

protocol NostrWorkoutServiceProtocol: AnyObject {
    /// Fetch user's workout history from Nostr relays
    func fetchUserWorkouts(limit: Int, since: Date?, using keyManager: NostrKeyManagerProtocol) async -> [Workout]
    
    /// Parse a Nostr event into a Workout object
    func parseWorkoutFromNostrEvent(_ event: NostrEvent) -> Workout?
}

// MARK: - Error Types

enum NostrServiceError: LocalizedError {
    case keyGenerationFailed
    case keyStorageFailed
    case keyNotFound
    case connectionFailed
    case publishingFailed
    case profileFetchFailed
    case invalidEvent
    case missingKeypair
    case missingRelayPool
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate Nostr keypair"
        case .keyStorageFailed:
            return "Failed to store keys securely"
        case .keyNotFound:
            return "No stored Nostr keys found"
        case .connectionFailed:
            return "Failed to connect to Nostr relays"
        case .publishingFailed:
            return "Failed to publish event to Nostr"
        case .profileFetchFailed:
            return "Failed to fetch profile from Nostr"
        case .invalidEvent:
            return "Invalid Nostr event format"
        case .missingKeypair:
            return "Keypair not available"
        case .missingRelayPool:
            return "Relay pool not initialized"
        }
    }
}

// MARK: - Cached Profile Type

struct CachedProfile: Codable {
    let profile: NostrProfile
    let timestamp: Date
}