import Foundation
import NostrSDK

/// Publishes various types of events to Nostr relays
@MainActor  
class NostrEventPublisher: ObservableObject, NostrEventPublisherProtocol {
    
    // MARK: - Published Properties
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let connectionManager: NostrConnectionManagerProtocol
    
    // MARK: - Initialization
    init(connectionManager: NostrConnectionManagerProtocol) {
        self.connectionManager = connectionManager
        print("📝 NostrEventPublisher initialized")
    }
    
    // MARK: - Workout Event Publishing
    
    /// Publish workout as Kind 1301 event to Nostr relays
    func publishWorkoutEvent(_ workout: Workout, using keyManager: NostrKeyManagerProtocol) async -> Bool {
        // For social sharing, publish as formatted text note (Kind 1)
        let workoutContent = createWorkoutSocialContent(workout)
        return await publishTextNote(workoutContent, using: keyManager)
    }
    
    /// Publish Kind 1301 workout record using NostrSDK
    func publishWorkoutRecord(_ workout: Workout, using keyManager: NostrKeyManagerProtocol) async -> Bool {
        await connectionManager.connect()
        
        // Ensure we have keys and connection
        guard let keyPair = try? keyManager.ensureKeysAvailable(),
              let nostrKeypair = keyManager.nostrSDKKeypair,
              let relayPool = connectionManager.relayPool else {
            await MainActor.run {
                errorMessage = "Missing keypair or relay pool connection"
                print("❌ Cannot publish workout record: missing requirements")
            }
            return false
        }
        
        // Create structured workout data for Kind 1301
        let workoutData = WorkoutEvent.createWorkoutContent(workout: workout)
        
        do {
            // Create kind 1301 workout record event using Builder pattern
            let builder = NostrEvent.Builder<NostrEvent>(kind: EventKind(rawValue: 1301))
                .content(workoutData)
            
            let signedEvent = try builder.build(signedBy: nostrKeypair)
            
            // Publish to relays
            relayPool.publishEvent(signedEvent)
            
            await MainActor.run {
                errorMessage = nil
                print("✅ Kind 1301 workout record published to Nostr relays")
                print("   📝 Workout: \(workout.activityType.displayName)")
                print("   🆔 Event ID: \(signedEvent.id.prefix(16))...")
                print("   🔑 Using npub: \(keyPair.publicKey.prefix(20))...")
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
    
    /// Publish Kind 1 text note using NostrSDK
    func publishTextNote(_ content: String, using keyManager: NostrKeyManagerProtocol) async -> Bool {
        await connectionManager.connect()
        
        // Ensure we have keys and connection
        guard let keyPair = try? keyManager.ensureKeysAvailable(),
              let nostrKeypair = keyManager.nostrSDKKeypair,
              let relayPool = connectionManager.relayPool else {
            await MainActor.run {
                errorMessage = "Missing keypair or relay pool connection"
                print("❌ Cannot publish text note: missing requirements")
            }
            return false
        }
        
        do {
            // Create kind 1 text note event using Builder pattern
            let builder = NostrEvent.Builder<NostrEvent>(kind: EventKind.textNote)
                .content(content)
            
            let signedEvent = try builder.build(signedBy: nostrKeypair)
            
            // Publish to relays
            relayPool.publishEvent(signedEvent)
            
            await MainActor.run {
                errorMessage = nil
                print("✅ Kind 1 text note published to Nostr relays")
                print("   📝 Content: \(content.prefix(50))...")
                print("   🆔 Event ID: \(signedEvent.id.prefix(16))...")
                print("   🔑 Using npub: \(keyPair.publicKey.prefix(20))...")
            }
            
            return true
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to publish text note: \(error.localizedDescription)"
                print("❌ Failed to publish text note: \(error)")
            }
            return false
        }
    }
    
    /// Publish user profile metadata as Kind 0 event
    func publishProfile(name: String, about: String?, picture: String?, using keyManager: NostrKeyManagerProtocol) async -> Bool {
        await connectionManager.connect()
        
        // Ensure we have keys and connection
        guard let keyPair = try? keyManager.ensureKeysAvailable(),
              let nostrKeypair = keyManager.nostrSDKKeypair,
              let relayPool = connectionManager.relayPool else {
            await MainActor.run {
                errorMessage = "Missing keypair or relay pool connection"
                print("❌ Cannot publish profile: missing requirements")
            }
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
            
            let signedEvent = try builder.build(signedBy: nostrKeypair)
            
            // Publish to relays
            relayPool.publishEvent(signedEvent)
            
            await MainActor.run {
                errorMessage = nil
                print("✅ Profile published to Nostr relays")
                print("   👤 Name: \(name)")
                print("   🆔 Event ID: \(signedEvent.id.prefix(16))...")
                print("   🔑 Using npub: \(keyPair.publicKey.prefix(20))...")
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
    
    // MARK: - Private Helper Methods
    
    /// Create social media formatted content for workout sharing
    private func createWorkoutSocialContent(_ workout: Workout) -> String {
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
            guard workout.duration > 0 else { break }
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
        
        return workoutContent
    }
}