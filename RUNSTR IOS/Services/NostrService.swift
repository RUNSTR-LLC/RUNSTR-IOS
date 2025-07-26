import Foundation
import Combine
import NostrSDK

/// Service responsible for managing Nostr protocol interactions
/// Handles key management, relay connections, and event publishing/subscribing
@MainActor
class NostrService: ObservableObject, EventCreating {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectedRelays: [String] = []
    @Published var userKeyPair: NostrKeyPair?
    @Published var mainNostrPublicKey: String?
    @Published var isDelegatedSigning = false
    @Published var errorMessage: String?
    @Published var recentEvents: [NostrWorkoutEvent] = []
    
    // MARK: - Private Properties
    private var relayPool: RelayPool?
    private let defaultRelays = [
        "wss://relay.nostr.band",
        "wss://nos.lol", 
        "wss://relay.damus.io",
        "wss://nostr.wine"
    ]
    
    // MARK: - Initialization
    init() {
        loadStoredKeys()
    }
    
    // MARK: - Key Management
    
    /// Generate new Nostr key pair for RUNSTR identity
    func generateRunstrKeys() -> NostrKeyPair {
        guard let keyPair = Keypair() else {
            print("❌ Failed to generate Nostr keys")
            errorMessage = "Failed to generate keys"
            
            // Fallback to mock for development
            return NostrKeyPair(
                privateKey: "nsec1runstr" + generateRandomString(50),
                publicKey: "npub1runstr" + generateRandomString(50)
            )
        }
        
        let publicKey = keyPair.publicKey.npub
        let privateKey = keyPair.privateKey.nsec
        
        return NostrKeyPair(
            privateKey: privateKey,
            publicKey: publicKey
        )
    }
    
    /// Store key pair securely in Keychain
    func storeKeyPair(_ keyPair: NostrKeyPair) {
        // Store in iOS Keychain for security
        let keyData = try? JSONEncoder().encode(keyPair)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "runstr_nostr_keys",
            kSecValueData as String: keyData ?? Data()
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            userKeyPair = keyPair
            print("✅ Nostr keys stored securely")
        } else {
            print("❌ Failed to store Nostr keys: \(status)")
            errorMessage = "Failed to store keys securely"
        }
    }
    
    /// Load stored key pair from Keychain
    private func loadStoredKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "runstr_nostr_keys",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let keyPair = try? JSONDecoder().decode(NostrKeyPair.self, from: data) {
            userKeyPair = keyPair
            print("✅ Loaded stored Nostr keys")
        } else {
            print("ℹ️ No stored Nostr keys found")
        }
    }
    
    /// Link main Nostr identity (npub) for delegation
    func linkMainNostrIdentity(_ npub: String) async -> Bool {
        // TODO: Implement delegation setup with NostrSDK
        // 1. Validate npub format
        // 2. Create delegation event
        // 3. Store delegation proof
        
        // Mock implementation
        guard npub.hasPrefix("npub1") && npub.count > 50 else {
            errorMessage = "Invalid npub format"
            return false
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        mainNostrPublicKey = npub
        isDelegatedSigning = true
        
        print("✅ Linked main Nostr identity: \(npub)")
        return true
    }
    
    // MARK: - Relay Management
    
    /// Connect to default Nostr relays
    func connectToRelays() async {
        isConnected = false
        connectedRelays.removeAll()
        errorMessage = nil
        
        // Create new relay pool instance
        relayPool = RelayPool(relays: [])
        
        // Add default relays to pool
        for relayURL in defaultRelays {
            guard let url = URL(string: relayURL) else {
                print("❌ Invalid relay URL: \(relayURL)")
                continue
            }
            
            do {
                let relay = try Relay(url: url)
                relayPool?.add(relay: relay)
                connectedRelays.append(relayURL)
                print("✅ Added relay: \(relayURL)")
            } catch {
                print("❌ Failed to create relay for \(relayURL): \(error)")
            }
        }
        
        if !connectedRelays.isEmpty {
            isConnected = true
            print("✅ Connected to \(connectedRelays.count) relays")
        } else {
            errorMessage = "Failed to connect to any relays"
        }
    }
    
    /// Disconnect from all relays
    func disconnectFromRelays() async {
        relayPool = nil
        connectedRelays.removeAll()
        isConnected = false
        print("✅ Disconnected from all relays")
    }
    
    // MARK: - Event Publishing
    
    /// Publish workout event to Nostr relays using NIP-101e
    func publishWorkoutEvent(_ workout: Workout, privacyLevel: PrivacyLevel) async -> Bool {
        guard let keyPair = userKeyPair else {
            errorMessage = "No Nostr keys available"
            return false
        }
        
        guard isConnected, let relayPool = relayPool else {
            errorMessage = "Not connected to relays"
            return false
        }
        
        do {
            // Create keypair from stored private key
            guard let keypair = Keypair(nsec: keyPair.privateKey) else {
                errorMessage = "Failed to create keypair from stored private key"
                return false
            }
            
            // Create workout event using NostrSDK
            let workoutEvent = try textNote(withContent: createWorkoutEventContent(workout),
                                          signedBy: keypair)
            
            // Publish event to relays
            relayPool.publishEvent(workoutEvent)
            
            // Create our local event representation
            let localEvent = NostrWorkoutEvent(
                id: workoutEvent.id,
                pubkey: keyPair.publicKey,
                createdAt: Date(timeIntervalSince1970: TimeInterval(workoutEvent.createdAt)),
                kind: 1065,
                content: createWorkoutEventContent(workout),
                tags: [], // Will be converted from NostrSDK format
                workout: workout
            )
            
            // Add to recent events
            recentEvents.insert(localEvent, at: 0)
            
            // Keep only last 20 events
            if recentEvents.count > 20 {
                recentEvents = Array(recentEvents.prefix(20))
            }
            
            print("✅ Published workout event: \(workout.activityType.displayName) - \(workout.distance/1000)km")
            return true
            
        } catch {
            print("❌ Failed to publish workout event: \(error)")
            errorMessage = "Failed to publish event: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Create workout event content following NIP-101e spec
    private func createWorkoutEventContent(_ workout: Workout) -> String {
        let workoutData: [String: Any] = [
            "type": workout.activityType.rawValue,
            "distance": workout.distance, // meters
            "duration": workout.duration, // seconds
            "startTime": ISO8601DateFormatter().string(from: workout.startTime),
            "endTime": ISO8601DateFormatter().string(from: workout.endTime),
            "averagePace": workout.averagePace, // minutes per km
            "calories": workout.calories ?? 0,
            "elevationGain": workout.elevationGain ?? 0,
            "averageHeartRate": workout.averageHeartRate ?? 0
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: workoutData)
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            print("❌ Failed to serialize workout data: \(error)")
            return ""
        }
    }
    
    
    // MARK: - Event Subscription
    
    /// Subscribe to workout events from followed users
    func subscribeToWorkoutEvents() async {
        guard isConnected, let relayPool = relayPool else { return }
        
        // Create filter for workout events (NIP-101e)
        guard let filter = Filter(kinds: [1065]) else {
            print("❌ Failed to create filter for workout events")
            errorMessage = "Failed to create filter"
            return
        }
        
        // Subscribe to events matching the filter
        _ = relayPool.subscribe(with: filter)
        
        print("✅ Subscribed to workout events")
    }
    
    // MARK: - Helper Methods
    
    private func generateRandomString(_ length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
}

// MARK: - Data Models

/// Nostr workout event following NIP-101e
struct NostrWorkoutEvent: Identifiable {
    let id: String
    let pubkey: String
    let createdAt: Date
    let kind: Int // 1065 for workout events
    let content: String
    let tags: [[String]]
    let workout: Workout
    
    var formattedContent: String {
        if let data = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return "\(json["type"] as? String ?? "Workout") - \(json["distance"] as? Double ?? 0)m in \(json["duration"] as? Double ?? 0)s"
        }
        return "Workout Event"
    }
}