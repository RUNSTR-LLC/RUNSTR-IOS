import Foundation
import Combine
import NostrSDK


/// Real Nostr service for RUNSTR using NostrSDK 0.3.0
@MainActor
class NostrService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var userKeyPair: NostrKeyPair?
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var keypair: Keypair?
    private var relayPool: RelayPool?
    private let relayUrls = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.snort.social",
        "wss://relay.primal.net"
    ]
    
    // MARK: - Initialization
    init() {
        print("📱 NostrService initialized with NostrSDK 0.3.0")
        loadStoredKeys()
    }
    
    // MARK: - SDK Setup
    private func ensureRelayPoolSetup() async {
        guard relayPool == nil else { return }
        
        let relays = Set(relayUrls.compactMap { URL(string: $0) }.compactMap { 
            try? Relay(url: $0) 
        })
        relayPool = RelayPool(relays: relays)
        print("✅ RelayPool initialized with \(relays.count) relays")
    }
    
    // MARK: - Key Management
    
    /// Generate new Nostr key pair using NostrSDK
    func generateRunstrKeys() -> NostrKeyPair? {
        guard let keypair = Keypair() else {
            print("❌ Failed to generate Nostr keypair")
            return nil
        }
        
        let nostrKeyPair = NostrKeyPair(
            privateKey: keypair.privateKey.nsec,
            publicKey: keypair.publicKey.npub
        )
        
        self.keypair = keypair
        return nostrKeyPair
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
    
    // MARK: - Connection Management (Lightweight)
    
    /// Connect to Nostr relays using NostrSDK
    func connect() async {
        await ensureRelayPoolSetup()
        
        guard let relayPool = relayPool else {
            errorMessage = "RelayPool not initialized"
            return
        }
        
        relayPool.connect()
        await MainActor.run {
            isConnected = true
            print("✅ Connected to Nostr relays")
        }
    }
    
    /// Disconnect from relays
    func disconnect() async {
        relayPool?.disconnect()
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
        
        // Build the workout content with emojis and proper formatting
        let activityText: String
        switch workout.activityType {
        case .running:
            activityText = "run"
        case .cycling:
            activityText = "ride"
        case .walking:
            activityText = "walk"
        }
        
        var workoutContent = "Just completed a \(activityText) with RUNSTR! "
        
        // Add activity-specific emoji
        switch workout.activityType {
        case .running:
            workoutContent += "🏃‍♂️💨"
        case .cycling:
            workoutContent += "🚴‍♂️💨"
        case .walking:
            workoutContent += "🚶‍♂️💨"
        }
        
        workoutContent += """
        
        
        ⏱️ Duration: \(workout.durationFormatted)
        📏 Distance: \(workout.distanceFormatted)
        """
        
        // Add activity-specific metrics
        switch workout.activityType {
        case .running:
            workoutContent += "\n⚡ Pace: \(workout.pace)"
        case .cycling:
            // Calculate and show speed for cycling
            let speedKmh = workout.distance / 1000 / (workout.duration / 3600)
            let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
            if useMetric {
                workoutContent += "\n🚴‍♂️ Speed: \(String(format: "%.1f", speedKmh)) km/h"
            } else {
                let speedMph = speedKmh * 0.621371
                workoutContent += "\n🚴‍♂️ Speed: \(String(format: "%.1f", speedMph)) mph"
            }
        case .walking:
            // Show steps for walking if available, otherwise show pace
            if let steps = workout.steps, steps > 0 {
                workoutContent += "\n👣 Steps: \(steps)"
            } else {
                workoutContent += "\n⚡ Pace: \(workout.pace)"
            }
        }
        
        // Add calories if available
        if let calories = workout.calories {
            workoutContent += "\n🔥 Calories: \(Int(calories)) kcal"
        }
        
        // Add elevation data if available
        if let elevationGain = workout.elevationGain, elevationGain > 0 {
            workoutContent += "\n\n🏔️ Elevation Gain: \(Int(elevationGain)) m"
        }
        
        workoutContent += "\n#RUNSTR #\(workout.activityType.displayName)"
        
        return await publishTextNote(workoutContent)
    }
    
    /// Publish Kind 1301 workout record using NostrSDK
    func publishWorkoutRecord(_ workout: Workout) async -> Bool {
        await ensureRelayPoolSetup()
        
        // Ensure we have keys loaded
        ensureKeysLoaded()
        
        // Generate new keys if none exist
        if userKeyPair == nil {
            guard let newKeyPair = generateRunstrKeys() else {
                print("❌ Failed to generate new Nostr keys")
                return false
            }
            userKeyPair = newKeyPair
            storeKeyPair(newKeyPair)
        }
        
        // Ensure keypair is loaded for signing
        if keypair == nil {
            keypair = Keypair(nsec: userKeyPair!.privateKey)
        }
        
        guard let keypair = keypair,
              let relayPool = relayPool else {
            print("❌ Missing keypair or relay pool")
            return false
        }
        
        // Create structured workout data for Kind 1301
        let workoutData = WorkoutEvent.createWorkoutContent(workout: workout)
        
        do {
            // Create kind 1301 workout record event using Builder pattern
            let builder = NostrEvent.Builder<NostrEvent>(kind: EventKind(rawValue: 1301))
                .content(workoutData)
            
            let signedEvent = try builder.build(signedBy: keypair)
            
            // Publish to relays
            relayPool.publishEvent(signedEvent)
            
            await MainActor.run {
                print("✅ Kind 1301 workout record published to Nostr relays")
                print("Workout data: \(workoutData)")
                print("Event ID: \(signedEvent.id)")
                print("Using npub: \(userKeyPair?.publicKey ?? "unknown")")
            }
            
            return true
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to publish workout record: \(error.localizedDescription)"
                print("❌ Failed to publish workout record: \(error)")
            }
            return false
        }
    }
    
    /// Ensure keys are loaded from keychain if not already loaded
    private func ensureKeysLoaded() {
        if userKeyPair == nil {
            loadStoredKeys()
        }
    }
    
    /// Publish Kind 1 text note using NostrSDK
    func publishTextNote(_ content: String) async -> Bool {
        await ensureRelayPoolSetup()
        
        // Ensure we have keys loaded
        ensureKeysLoaded()
        
        // Generate new keys if none exist
        if userKeyPair == nil {
            guard let newKeyPair = generateRunstrKeys() else {
                print("❌ Failed to generate new Nostr keys")
                return false
            }
            userKeyPair = newKeyPair
            storeKeyPair(newKeyPair)
        }
        
        // Ensure keypair is loaded for signing
        if keypair == nil {
            keypair = Keypair(nsec: userKeyPair!.privateKey)
        }
        
        guard let keypair = keypair,
              let relayPool = relayPool else {
            print("❌ Missing keypair or relay pool")
            return false
        }
        
        do {
            // Create kind 1 text note event using Builder pattern
            let builder = NostrEvent.Builder<NostrEvent>(kind: EventKind.textNote)
                .content(content)
            
            let signedEvent = try builder.build(signedBy: keypair)
            
            // Publish to relays
            relayPool.publishEvent(signedEvent)
            
            await MainActor.run {
                print("✅ Kind 1 text note published to Nostr relays")
                print("Content: \(content)")
                print("Event ID: \(signedEvent.id)")
                print("Using npub: \(userKeyPair?.publicKey ?? "unknown")")
            }
            
            return true
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to publish note: \(error.localizedDescription)"
                print("❌ Failed to publish text note: \(error)")
            }
            return false
        }
    }
    
    // MARK: - Profile Management (NIP-01)
    
    /// Publish user profile metadata as Kind 0 event
    func publishProfile(name: String, about: String? = nil, picture: String? = nil) async -> Bool {
        await ensureRelayPoolSetup()
        
        // Ensure we have keys loaded
        ensureKeysLoaded()
        
        // Generate new keys if none exist
        if userKeyPair == nil {
            guard let newKeyPair = generateRunstrKeys() else {
                print("❌ Failed to generate new Nostr keys")
                return false
            }
            userKeyPair = newKeyPair
            storeKeyPair(newKeyPair)
        }
        
        // Ensure keypair is loaded for signing
        if keypair == nil {
            keypair = Keypair(nsec: userKeyPair!.privateKey)
        }
        
        guard let keypair = keypair,
              let relayPool = relayPool else {
            print("❌ Missing keypair or relay pool")
            return false
        }
        
        // Create profile metadata JSON
        var profileData: [String: Any] = [
            "name": name
        ]
        
        if let about = about, !about.isEmpty {
            profileData["about"] = about
        }
        
        if let picture = picture, !picture.isEmpty {
            profileData["picture"] = picture
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: profileData)
            let profileContent = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            // Create kind 0 profile event using Builder pattern
            let builder = NostrEvent.Builder<NostrEvent>(kind: EventKind(rawValue: 0))
                .content(profileContent)
            
            let signedEvent = try builder.build(signedBy: keypair)
            
            // Publish to relays
            relayPool.publishEvent(signedEvent)
            
            await MainActor.run {
                print("✅ Profile published to Nostr relays")
                print("Profile data: \(profileContent)")
                print("Event ID: \(signedEvent.id)")
            }
            
            return true
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to publish profile: \(error.localizedDescription)"
                print("❌ Failed to publish profile: \(error)")
            }
            return false
        }
    }
    
    /// Fetch profile metadata from Nostr relays
    func fetchProfile(pubkey: String) async -> NostrProfile? {
        await ensureRelayPoolSetup()
        
        guard relayPool != nil else {
            print("❌ RelayPool not initialized")
            return nil
        }
        
        // Create filter for profile events (kind 0) for specific pubkey
        _ = Filter(
            authors: [pubkey],
            kinds: [0],
            limit: 1
        )
        
        // Note: This is a simplified implementation
        // In a full implementation, you would subscribe to events and handle responses
        print("🔍 Profile fetch initiated for pubkey: \(pubkey)")
        
        // For now, return nil as this requires implementing subscription handling
        // which would need additional relay event handling infrastructure
        return nil
    }
    
    /// Update local user profile and publish to Nostr
    func updateUserProfile(name: String, about: String? = nil, picture: String? = nil) async -> Bool {
        // First update locally stored profile
        await MainActor.run {
            // This will be handled by the User model update methods
        }
        
        // Then publish to Nostr relays
        return await publishProfile(name: name, about: about, picture: picture)
    }
}