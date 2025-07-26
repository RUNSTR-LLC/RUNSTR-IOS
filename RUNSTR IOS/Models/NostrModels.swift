import Foundation
import CryptoKit

struct NostrKeyPair {
    let privateKey: String // nsec
    let publicKey: String // npub
    
    static func generate() -> NostrKeyPair {
        let privateKeyData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let privateKeyHex = privateKeyData.hexString
        let publicKeyHex = derivePublicKey(from: privateKeyHex)
        
        return NostrKeyPair(
            privateKey: "nsec" + privateKeyHex,
            publicKey: "npub" + publicKeyHex
        )
    }
    
    private static func derivePublicKey(from privateKeyHex: String) -> String {
        return privateKeyHex // Simplified - would use secp256k1 in production
    }
}

struct NostrEvent: Codable {
    let id: String
    let pubkey: String
    let created_at: Int64
    let kind: Int
    let tags: [[String]]
    let content: String
    let sig: String
    
    init(kind: Int, content: String, tags: [[String]] = [], pubkey: String) {
        self.pubkey = pubkey
        self.created_at = Int64(Date().timeIntervalSince1970)
        self.kind = kind
        self.tags = tags
        self.content = content
        self.id = "" // Would be calculated from event data
        self.sig = "" // Would be signed with private key
    }
}

struct WorkoutEvent {
    static func createNIP101e(workout: Workout, userPubkey: String) -> NostrEvent {
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
        
        let jsonData = try! JSONSerialization.data(withJSONObject: workoutData)
        let content = String(data: jsonData, encoding: .utf8)!
        
        let tags = [
            ["t", "fitness"],
            ["t", workout.activityType.rawValue],
            ["distance", String(Int(workout.distance))],
            ["duration", String(Int(workout.duration))]
        ]
        
        return NostrEvent(kind: 1063, content: content, tags: tags, pubkey: userPubkey)
    }
}

struct TeamList {
    static func createNIP51(team: Team, captainPubkey: String) -> NostrEvent {
        let teamTags = team.memberIDs.map { ["p", $0] }
        let metaTags = [
            ["d", team.nostrListID],
            ["name", team.name],
            ["description", team.description],
            ["activity_level", team.activityLevel.rawValue],
            ["max_members", String(team.maxMembers)]
        ]
        
        let allTags = teamTags + metaTags
        
        return NostrEvent(
            kind: 30001, // Parameterized replaceable event for teams
            content: team.description,
            tags: allTags,
            pubkey: captainPubkey
        )
    }
}

struct EventList {
    static func createNIP51(event: Event, creatorPubkey: String) -> NostrEvent {
        let participantTags = event.participants.map { ["p", $0] }
        let metaTags = [
            ["d", event.nostrListID],
            ["name", event.name],
            ["description", event.description],
            ["start_date", String(Int64(event.startDate.timeIntervalSince1970))],
            ["end_date", String(Int64(event.endDate.timeIntervalSince1970))],
            ["goal_type", event.goalType.rawValue],
            ["target_value", String(event.targetValue)],
            ["prize_pool", String(event.prizePool)]
        ]
        
        let allTags = participantTags + metaTags
        
        return NostrEvent(
            kind: 30002, // Parameterized replaceable event for events
            content: event.description,
            tags: allTags,
            pubkey: creatorPubkey
        )
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

extension Data {
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}