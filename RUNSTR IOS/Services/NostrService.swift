import Foundation
import Combine
import NostrSDK

/// Simplified Nostr service for RUNSTR - minimal implementation
@MainActor
class NostrService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var userKeyPair: NostrKeyPair?
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var relayPool: RelayPool?
    private let relayUrls = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.snort.social",
        "wss://relay.primal.net"
    ]
    
    // MARK: - Initialization
    init() {
        loadStoredKeys()
        // Auto-connect on init
        Task {
            await connect()
        }
    }
    
    // MARK: - Key Management
    
    /// Generate new Nostr key pair for RUNSTR identity
    func generateRunstrKeys() -> NostrKeyPair {
        return NostrKeyPair.generate()
    }
    
    /// Store key pair securely in iOS Keychain
    func storeKeyPair(_ keyPair: NostrKeyPair) {
        let keyData = try? JSONEncoder().encode(keyPair)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "app.runstr.keychain",
            kSecAttrAccount as String: "nostrPrivateKey",
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
            kSecAttrService as String: "app.runstr.keychain",
            kSecAttrAccount as String: "nostrPrivateKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let keyData = result as? Data,
           let keyPair = try? JSONDecoder().decode(NostrKeyPair.self, from: keyData) {
            userKeyPair = keyPair
            print("✅ Loaded stored Nostr keys")
        } else {
            print("⚠️ No stored Nostr keys found - will generate on first use")
        }
    }
    
    // MARK: - Connection Management (Simplified)
    
    /// Connect to actual Nostr relays
    func connect() async {
        do {
            // Create relay connections
            var relays = Set<Relay>()
            
            for urlString in relayUrls {
                if let url = URL(string: urlString) {
                    do {
                        let relay = try Relay(url: url)
                        relays.insert(relay)
                    } catch {
                        print("Failed to create relay for \(url): \(error)")
                    }
                }
            }
            
            guard !relays.isEmpty else {
                await MainActor.run {
                    errorMessage = "Failed to create relay connections"
                }
                return
            }
            
            relayPool = RelayPool(relays: relays)
            
            // Attempt to connect
            relayPool?.connect()
            
            await MainActor.run {
                isConnected = true
                print("✅ Connected to Nostr relays")
            }
        } catch {
            await MainActor.run {
                isConnected = false
                errorMessage = "Failed to connect to relays: \(error.localizedDescription)"
                print("❌ Failed to connect to Nostr relays: \(error)")
            }
        }
    }
    
    /// Disconnect from relays
    func disconnect() async {
        relayPool?.disconnect()
        relayPool = nil
        
        await MainActor.run {
            isConnected = false
            print("✅ Disconnected from Nostr relays")
        }
    }
    
    // MARK: - Event Publishing (Simplified)
    
    /// Publish workout as Kind 1301 event to actual Nostr relays
    func publishWorkoutEvent(_ workout: Workout) async -> Bool {
        // For now, we'll publish workout events as kind 1 text notes
        // In the future, we can implement proper kind 1301 support
        let workoutContent = """
        🏃‍♂️ Workout Complete!
        Activity: \(workout.activityType.displayName)
        Distance: \(workout.distanceFormatted)
        Duration: \(workout.durationFormatted)
        Date: \(workout.startTime.formatted(.dateTime.month().day().hour().minute()))
        
        #RUNSTR #Fitness #\(workout.activityType.rawValue) #Bitcoin
        """
        
        return await publishTextNote(workoutContent)
    }
    
    /// Publish Kind 1 text note to actual Nostr relays
    func publishTextNote(_ content: String) async -> Bool {
        // Ensure we have keys
        if userKeyPair == nil {
            userKeyPair = generateRunstrKeys()
            storeKeyPair(userKeyPair!)
        }
        
        guard let keyPair = userKeyPair else {
            print("❌ Cannot publish text note: no keys available")
            await MainActor.run {
                errorMessage = "No keys available for publishing"
            }
            return false
        }
        
        // Ensure we're connected to relays
        if !isConnected {
            await connect()
        }
        
        guard isConnected, let relayPool = relayPool else {
            print("❌ Cannot publish: not connected to relays")
            await MainActor.run {
                errorMessage = "Not connected to Nostr relays"
            }
            return false
        }
        
        do {
            // Convert stored keys to NostrSDK format
            guard let keypair = Keypair(nsec: keyPair.privateKey) else {
                await MainActor.run {
                    errorMessage = "Failed to create keypair from stored keys"
                }
                return false
            }
            
            // Create the text note event
            let builder = NostrEvent.Builder<NostrEvent>(kind: EventKind.textNote)
                .content(content)
            
            let signedEvent = try builder.build(signedBy: keypair)
            
            print("📝 Publishing text note...")
            print("Content: \(content)")
            print("Using npub: \(keyPair.publicKey)")
            print("Event ID: \(signedEvent.id)")
            
            // Publish to relays
            try relayPool.publishEvent(signedEvent)
            
            await MainActor.run {
                print("✅ Text note published to Nostr relays")
            }
            
            return true
            
        } catch {
            print("❌ Failed to publish text note: \(error)")
            await MainActor.run {
                errorMessage = "Failed to publish note: \(error.localizedDescription)"
            }
            return false
        }
    }
}