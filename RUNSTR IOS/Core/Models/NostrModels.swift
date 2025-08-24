import Foundation
import CryptoKit

// MARK: - Core Nostr Data Models

/// Nostr key pair for RUNSTR app - simple storage for NostrSDK generated keys
struct NostrKeyPair: Codable {
    let privateKey: String // nsec (bech32)
    let publicKey: String // npub (bech32)
    
    /// Initialize from NostrSDK keypair
    init(privateKey: String, publicKey: String) {
        self.privateKey = privateKey
        self.publicKey = publicKey
    }
}

enum NostrKeyError: Error, LocalizedError {
    case invalidFormat
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid nsec format"
        case .decodingError:
            return "Failed to decode private key"
        }
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

// MARK: - NIP-101e Enhanced Event Types

/// Kind 33404 - Fitness Team Event
struct FitnessTeamEvent: Codable {
    let id: String // d tag value
    var kind: Int { 33404 }
    let content: String // Team description
    let name: String
    let teamType: String // "running_club", "cycling_group", etc.
    let location: String? // City, region
    let captainPubkey: String // Team captain's npub
    let memberPubkeys: [String] // Team member npubs
    let isPublic: Bool
    let createdAt: Date
    let tags: [[String]] // Raw Nostr tags
    
    /// Initialize from Nostr event tags
    init?(eventContent: String, tags: [[String]], createdAt: Date) {
        guard let dTag = tags.first(where: { $0.first == "d" })?.last,
              let nameTag = tags.first(where: { $0.first == "name" })?.last,
              let captainTag = tags.first(where: { $0.first == "captain" })?.last else {
            return nil
        }
        
        self.id = dTag
        self.content = eventContent
        self.name = nameTag
        self.teamType = tags.first(where: { $0.first == "type" })?.last ?? "running_club"
        self.location = tags.first(where: { $0.first == "location" })?.last
        self.captainPubkey = captainTag
        self.memberPubkeys = tags.filter { $0.first == "member" }.compactMap { $0.last }
        self.isPublic = tags.contains(where: { $0.contains("public") && $0.contains("true") })
        self.createdAt = createdAt
        self.tags = tags
    }
    
    /// Create tags for Nostr event
    func createNostrTags() -> [[String]] {
        var tags: [[String]] = [
            ["d", id],
            ["name", name],
            ["type", teamType],
            ["captain", captainPubkey],
            ["public", isPublic ? "true" : "false"],
            ["t", "team"],
            ["t", "fitness"]
        ]
        
        if let location = location {
            tags.append(["location", location])
        }
        
        // Add member tags
        for member in memberPubkeys {
            tags.append(["member", member])
        }
        
        return tags
    }
}

/// Kind 33403 - Fitness Challenge Event
struct FitnessChallengeEvent: Codable {
    let id: String // d tag value
    let kind: Int
    let content: String // Challenge description
    let name: String
    let startTimestamp: Int64
    let endTimestamp: Int64
    let goalType: String // "distance_total", "streak_days", etc.
    let goalValue: Double
    let goalUnit: String // "miles", "km", "days"
    let activityTypes: [String] // ["running", "walking", "cycling"]
    let rules: String?
    let isPublic: Bool
    let createdAt: Date
    let tags: [[String]]
    
    init?(eventContent: String, tags: [[String]], createdAt: Date) {
        guard let dTag = tags.first(where: { $0.first == "d" })?.last,
              let nameTag = tags.first(where: { $0.first == "name" })?.last,
              let startTag = tags.first(where: { $0.first == "start" })?.last,
              let endTag = tags.first(where: { $0.first == "end" })?.last,
              let goalTypeTag = tags.first(where: { $0.first == "goal_type" })?.last,
              let goalValueTag = tags.first(where: { $0.first == "goal_value" })?.last,
              let startTimestamp = Int64(startTag),
              let endTimestamp = Int64(endTag),
              let goalValue = Double(goalValueTag) else {
            return nil
        }
        
        self.id = dTag
        self.kind = 33403
        self.content = eventContent
        self.name = nameTag
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.goalType = goalTypeTag
        self.goalValue = goalValue
        self.goalUnit = tags.first(where: { $0[safe: 0] == "goal_value" && $0.count > 2 })?[safe: 2] ?? "km"
        self.activityTypes = tags.filter { $0.first == "activity_types" }.compactMap { $0.last }
        self.rules = tags.first(where: { $0.first == "rules" })?.last
        self.isPublic = tags.contains(where: { $0.contains("public") && $0.contains("true") })
        self.createdAt = createdAt
        self.tags = tags
    }
    
    func createNostrTags() -> [[String]] {
        var tags: [[String]] = [
            ["d", id],
            ["name", name],
            ["start", String(startTimestamp)],
            ["end", String(endTimestamp)],
            ["goal_type", goalType],
            ["goal_value", String(goalValue), goalUnit],
            ["public", isPublic ? "true" : "false"],
            ["t", "challenge"],
            ["t", "fitness"]
        ]
        
        for activityType in activityTypes {
            tags.append(["activity_types", activityType])
        }
        
        if let rules = rules {
            tags.append(["rules", rules])
        }
        
        return tags
    }
}

/// Kind 33405 - Fitness Event
struct FitnessEventEvent: Codable {
    let id: String // d tag value
    var kind: Int { 33405 }
    let content: String // Event description
    let name: String
    let eventDate: Int64 // Unix timestamp
    let location: String?
    let distance: Double?
    let distanceUnit: String?
    let registrationDeadline: Int64?
    let maxParticipants: Int?
    let isPublic: Bool
    let createdAt: Date
    let tags: [[String]]
    
    init?(eventContent: String, tags: [[String]], createdAt: Date) {
        guard let dTag = tags.first(where: { $0.first == "d" })?.last,
              let nameTag = tags.first(where: { $0.first == "name" })?.last,
              let dateTag = tags.first(where: { $0.first == "date" })?.last,
              let eventDate = Int64(dateTag) else {
            return nil
        }
        
        self.id = dTag
        self.content = eventContent
        self.name = nameTag
        self.eventDate = eventDate
        self.location = tags.first(where: { $0.first == "location" })?.last
        
        if let distanceTag = tags.first(where: { $0.first == "distance" && $0.count > 1 }),
           let distance = Double(distanceTag[1]) {
            self.distance = distance
            self.distanceUnit = distanceTag.count > 2 ? distanceTag[2] : "km"
        } else {
            self.distance = nil
            self.distanceUnit = nil
        }
        
        if let regTag = tags.first(where: { $0.first == "registration_deadline" })?.last {
            self.registrationDeadline = Int64(regTag)
        } else {
            self.registrationDeadline = nil
        }
        
        if let maxTag = tags.first(where: { $0.first == "max_participants" })?.last {
            self.maxParticipants = Int(maxTag)
        } else {
            self.maxParticipants = nil
        }
        
        self.isPublic = tags.contains(where: { $0.contains("public") && $0.contains("true") })
        self.createdAt = createdAt
        self.tags = tags
    }
    
    func createNostrTags() -> [[String]] {
        var tags: [[String]] = [
            ["d", id],
            ["name", name],
            ["date", String(eventDate)],
            ["t", "event"],
            ["t", "fitness"]
        ]
        
        if let location = location {
            tags.append(["location", location])
        }
        
        if let distance = distance, let unit = distanceUnit {
            tags.append(["distance", String(distance), unit])
        }
        
        if let deadline = registrationDeadline {
            tags.append(["registration_deadline", String(deadline)])
        }
        
        if let maxParticipants = maxParticipants {
            tags.append(["max_participants", String(maxParticipants)])
        }
        
        return tags
    }
}

/// Enhanced Kind 1301 - Workout Record with Team/Challenge Links
struct EnhancedWorkoutEvent: Codable {
    let id: String // d tag value
    var kind: Int { 1301 }
    let content: String // Workout description/notes
    let title: String
    let workoutType: String // "cardio", "strength", etc.
    let startTimestamp: Int64
    let endTimestamp: Int64
    let exerciseData: ExerciseData
    let accuracy: String // "exact", "approximate"
    let deviceInfo: String?
    let gpsPolyline: String? // Encoded GPS data
    
    // Community connections
    let challengeReference: String? // "33403:<pubkey>:<challenge-uuid>"
    let teamReference: String? // "33404:<pubkey>:<team-uuid>"
    let eventReference: String? // "33405:<pubkey>:<event-uuid>"
    
    let createdAt: Date
    let tags: [[String]]
    
    struct ExerciseData: Codable {
        let distance: Double // km
        let duration: TimeInterval // seconds
        let pace: Double // min/km
        let elevationGain: Double? // meters
        let calories: Double?
        let averageHeartRate: Double?
    }
    
    init?(eventContent: String, tags: [[String]], createdAt: Date) {
        guard let dTag = tags.first(where: { $0.first == "d" })?.last,
              let titleTag = tags.first(where: { $0.first == "title" })?.last,
              let startTag = tags.first(where: { $0.first == "start" })?.last,
              let endTag = tags.first(where: { $0.first == "end" })?.last,
              let exerciseTag = tags.first(where: { $0.first == "exercise" }),
              exerciseTag.count >= 6,
              let distance = Double(exerciseTag[3]),
              let duration = TimeInterval(exerciseTag[4]),
              let pace = Double(exerciseTag[5]),
              let startTimestamp = Int64(startTag),
              let endTimestamp = Int64(endTag) else {
            return nil
        }
        
        self.id = dTag
        self.content = eventContent
        self.title = titleTag
        self.workoutType = tags.first(where: { $0.first == "type" })?.last ?? "cardio"
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        
        // Parse exercise data
        self.exerciseData = ExerciseData(
            distance: distance,
            duration: duration,
            pace: pace,
            elevationGain: exerciseTag.count > 6 ? Double(exerciseTag[6]) : nil,
            calories: nil, // TODO: Parse from additional tags
            averageHeartRate: tags.first(where: { $0.first == "heart_rate_avg" })?.last.flatMap(Double.init)
        )
        
        self.accuracy = tags.first(where: { $0.first == "accuracy" })?.last ?? "approximate"
        self.deviceInfo = tags.first(where: { $0.first == "device" })?.last
        self.gpsPolyline = tags.first(where: { $0.first == "gps_polyline" })?.last
        
        // Parse community references
        self.challengeReference = tags.first(where: { $0.first == "challenge" })?.last
        self.teamReference = tags.first(where: { $0.first == "team" })?.last
        self.eventReference = tags.first(where: { $0.first == "event" })?.last
        
        self.createdAt = createdAt
        self.tags = tags
    }
}

// MARK: - Helper Extensions

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

