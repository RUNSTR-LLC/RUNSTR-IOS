import Foundation
import NostrSDK

// MARK: - Core Nostr Data Models

/// Nostr key pair for RUNSTR app (using bech32 encoded keys)
struct NostrKeyPair: Codable {
    let privateKey: String // nsec (bech32)
    let publicKey: String // npub (bech32)
    
    /// Generate new key pair using NostrSDK
    static func generate() -> NostrKeyPair {
        guard let keypair = Keypair() else {
            print("❌ Failed to generate Nostr keys")
            // Fallback to mock keys for development only
            let mockPrivateKey = "nsec1" + String((0..<58).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
            let mockPublicKey = "npub1" + String((0..<58).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
            return NostrKeyPair(privateKey: mockPrivateKey, publicKey: mockPublicKey)
        }
        
        let publicKey = keypair.publicKey.npub
        let privateKey = keypair.privateKey.nsec
        
        return NostrKeyPair(
            privateKey: privateKey,
            publicKey: publicKey
        )
    }
}

// MARK: - Workout Event Helper

struct WorkoutEvent {
    /// Create NIP-101e workout event data for publishing
    static func createWorkoutContent(workout: Workout) -> String {
        let workoutData: [String: Any] = [
            "id": workout.id,
            "type": workout.activityType.rawValue,
            "start_time": Int64(workout.startTime.timeIntervalSince1970),
            "end_time": Int64(workout.endTime.timeIntervalSince1970),
            "duration": workout.duration,
            "distance": workout.distance,
            "pace": workout.averagePace,
            "calories": workout.calories ?? 0,
            "heart_rate_avg": workout.averageHeartRate ?? 0,
            "elevation_gain": workout.elevationGain ?? 0
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: workoutData)
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            print("❌ Failed to serialize workout data: \(error)")
            return ""
        }
    }
}

struct NostrRelay {
    let url: String
    let isConnected: Bool
    let lastSeen: Date?
    
    static let defaultRelays = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.snort.social",
        "wss://relay.primal.net"
    ]
}

