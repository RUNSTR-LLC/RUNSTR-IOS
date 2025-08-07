import Foundation
import CloudKit

// MARK: - CloudKit Extensions for Team Models

extension Team {
    /// CloudKit Record Type name
    static let recordType = "Team"
    
    /// Initialize Team from CloudKit CKRecord
    init?(record: CKRecord) {
        guard let name = record["name"] as? String,
              let description = record["description"] as? String,
              let captainID = record["captainID"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let maxMembers = record["maxMembers"] as? Int,
              let isPublic = record["isPublic"] as? Int,
              let activityLevelRaw = record["activityLevel"] as? String,
              let activityLevel = ActivityLevel(rawValue: activityLevelRaw),
              let teamType = record["teamType"] as? String else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.name = name
        self.description = description
        self.captainID = captainID
        self.createdAt = createdAt
        self.maxMembers = maxMembers
        self.activityLevel = activityLevel
        self.isPublic = isPublic == 1
        self.teamType = teamType
        self.location = record["location"] as? String
        self.imageURL = record["imageURL"] as? String
        self.memberIDs = (record["memberIDs"] as? [String]) ?? [captainID]
        self.supportedActivityTypes = ActivityType.fromStringArray(record["supportedActivityTypes"] as? [String] ?? [])
        self.activeChallenges = (record["activeChallenges"] as? [String]) ?? []
        self.teamEvents = (record["teamEvents"] as? [String]) ?? []
        self.nostrListID = record["nostrListID"] as? String ?? "team_\(self.id)"
        self.nostrEventID = record["nostrEventID"] as? String
        
        // Initialize stats with empty values - will be populated separately
        self.stats = TeamStats()
    }
    
    /// Convert Team to CloudKit CKRecord
    func toCKRecord(container: CKContainer = CKContainer.default()) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: Team.recordType, recordID: recordID)
        
        record["name"] = name as CKRecordValue
        record["description"] = description as CKRecordValue
        record["captainID"] = captainID as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["maxMembers"] = maxMembers as CKRecordValue
        record["isPublic"] = (isPublic ? 1 : 0) as CKRecordValue
        record["activityLevel"] = activityLevel.rawValue as CKRecordValue
        record["teamType"] = teamType as CKRecordValue
        record["location"] = location as CKRecordValue?
        record["imageURL"] = imageURL as CKRecordValue?
        record["memberIDs"] = memberIDs as CKRecordValue
        record["supportedActivityTypes"] = supportedActivityTypes.map { $0.rawValue } as CKRecordValue
        record["activeChallenges"] = activeChallenges as CKRecordValue
        record["teamEvents"] = teamEvents as CKRecordValue
        record["nostrListID"] = nostrListID as CKRecordValue
        record["nostrEventID"] = nostrEventID as CKRecordValue?
        
        return record
    }
}

extension TeamMember {
    /// CloudKit Record Type name
    static let recordType = "TeamMember"
    
    /// Initialize TeamMember from CloudKit CKRecord
    init?(record: CKRecord) {
        guard let joinedAt = record["joinedAt"] as? Date,
              let roleRaw = record["role"] as? String,
              let role = TeamRole(rawValue: roleRaw) else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.joinedAt = joinedAt
        self.role = role
        
        // Initialize stats with values from record or defaults
        self.stats = MemberStats.fromCloudKit(
            totalDistance: (record["totalDistance"] as? Double) ?? 0.0,
            totalWorkouts: (record["totalWorkouts"] as? Int) ?? 0,
            averagePace: (record["averagePace"] as? Double) ?? 0.0,
            currentStreak: (record["currentStreak"] as? Int) ?? 0,
            lastWorkoutDate: (record["lastWorkoutDate"] as? Date) ?? Date.distantPast,
            monthlyDistance: (record["monthlyDistance"] as? Double) ?? 0.0,
            weeklyDistance: (record["weeklyDistance"] as? Double) ?? 0.0,
            rank: (record["rank"] as? Int) ?? 0
        )
    }
    
    /// Convert TeamMember to CloudKit CKRecord
    func toCKRecord(teamID: String, container: CKContainer = CKContainer.default()) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "\(teamID)_\(id)")
        let record = CKRecord(recordType: TeamMember.recordType, recordID: recordID)
        
        record["memberID"] = id as CKRecordValue
        record["teamID"] = teamID as CKRecordValue
        record["joinedAt"] = joinedAt as CKRecordValue
        record["role"] = role.rawValue as CKRecordValue
        record["totalDistance"] = stats.totalDistance as CKRecordValue
        record["totalWorkouts"] = stats.totalWorkouts as CKRecordValue
        record["averagePace"] = stats.averagePace as CKRecordValue
        record["currentStreak"] = stats.currentStreak as CKRecordValue
        record["lastWorkoutDate"] = stats.lastWorkoutDate as CKRecordValue
        record["monthlyDistance"] = stats.monthlyDistance as CKRecordValue
        record["weeklyDistance"] = stats.weeklyDistance as CKRecordValue
        record["rank"] = stats.rank as CKRecordValue
        
        return record
    }
}

// MARK: - Team Message Model for Chat
struct TeamMessage: Codable, Identifiable {
    let id: String
    let teamID: String
    let senderID: String
    let senderName: String
    let content: String
    let messageType: MessageType
    let timestamp: Date
    var isRead: Bool = false
    var metadata: [String: String] = [:]
    
    enum MessageType: String, Codable {
        case text = "text"
        case system = "system"
        case workout = "workout"
        case challenge = "challenge"
        
        var displayName: String {
            switch self {
            case .text: return "Message"
            case .system: return "System"
            case .workout: return "Workout Update"
            case .challenge: return "Challenge"
            }
        }
    }
    
    init(teamID: String, senderID: String, senderName: String, content: String, messageType: MessageType = .text) {
        self.id = UUID().uuidString
        self.teamID = teamID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.messageType = messageType
        self.timestamp = Date()
        self.isRead = false
        self.metadata = [:]
    }
}

extension TeamMessage {
    /// CloudKit Record Type name
    static let recordType = "TeamMessage"
    
    /// Initialize TeamMessage from CloudKit CKRecord
    init?(record: CKRecord) {
        guard let teamID = record["teamID"] as? String,
              let senderID = record["senderID"] as? String,
              let senderName = record["senderName"] as? String,
              let content = record["content"] as? String,
              let timestamp = record["timestamp"] as? Date,
              let messageTypeRaw = record["messageType"] as? String,
              let messageType = MessageType(rawValue: messageTypeRaw) else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.teamID = teamID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.messageType = messageType
        self.timestamp = timestamp
        self.isRead = (record["isRead"] as? Int == 1)
        
        // Decode metadata from JSON string
        if let metadataString = record["metadata"] as? String,
           let jsonData = metadataString.data(using: .utf8),
           let metadataDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] {
            self.metadata = metadataDict
        } else {
            self.metadata = [:]
        }
    }
    
    /// Convert TeamMessage to CloudKit CKRecord
    func toCKRecord(container: CKContainer = CKContainer.default()) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: TeamMessage.recordType, recordID: recordID)
        
        record["teamID"] = teamID as CKRecordValue
        record["senderID"] = senderID as CKRecordValue
        record["senderName"] = senderName as CKRecordValue
        record["content"] = content as CKRecordValue
        record["messageType"] = messageType.rawValue as CKRecordValue
        record["timestamp"] = timestamp as CKRecordValue
        record["isRead"] = (isRead ? 1 : 0) as CKRecordValue
        
        // Convert metadata dictionary to CloudKit-compatible format
        if !metadata.isEmpty {
            // Store metadata as a JSON-encoded string since CloudKit doesn't support nested dictionaries
            if let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                record["metadata"] = jsonString as CKRecordValue
            }
        }
        
        return record
    }
}

// MARK: - Team Statistics Model for CloudKit
struct TeamStatsCloudKit: Codable, Identifiable {
    let id: String // teamID
    let teamID: String
    var totalDistance: Double = 0.0
    var totalWorkouts: Int = 0
    var activeMembers: Int = 0
    var averageWorkoutsPerMember: Double = 0.0
    var lastUpdated: Date = Date()
    var weeklyDistance: Double = 0.0
    var monthlyDistance: Double = 0.0
    var topPerformers: [String] = [] // User IDs
    
    init(teamID: String) {
        self.id = teamID
        self.teamID = teamID
        self.totalDistance = 0.0
        self.totalWorkouts = 0
        self.activeMembers = 0
        self.averageWorkoutsPerMember = 0.0
        self.lastUpdated = Date()
        self.weeklyDistance = 0.0
        self.monthlyDistance = 0.0
        self.topPerformers = []
    }
}

extension TeamStatsCloudKit {
    /// CloudKit Record Type name
    static let recordType = "TeamStats"
    
    /// Initialize TeamStats from CloudKit CKRecord
    init?(record: CKRecord) {
        guard let teamID = record["teamID"] as? String else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.teamID = teamID
        self.totalDistance = (record["totalDistance"] as? Double) ?? 0.0
        self.totalWorkouts = (record["totalWorkouts"] as? Int) ?? 0
        self.activeMembers = (record["activeMembers"] as? Int) ?? 0
        self.averageWorkoutsPerMember = (record["averageWorkoutsPerMember"] as? Double) ?? 0.0
        self.lastUpdated = (record["lastUpdated"] as? Date) ?? Date()
        self.weeklyDistance = (record["weeklyDistance"] as? Double) ?? 0.0
        self.monthlyDistance = (record["monthlyDistance"] as? Double) ?? 0.0
        self.topPerformers = (record["topPerformers"] as? [String]) ?? []
    }
    
    /// Convert TeamStats to CloudKit CKRecord
    func toCKRecord(container: CKContainer = CKContainer.default()) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: TeamStatsCloudKit.recordType, recordID: recordID)
        
        record["teamID"] = teamID as CKRecordValue
        record["totalDistance"] = totalDistance as CKRecordValue
        record["totalWorkouts"] = totalWorkouts as CKRecordValue
        record["activeMembers"] = activeMembers as CKRecordValue
        record["averageWorkoutsPerMember"] = averageWorkoutsPerMember as CKRecordValue
        record["lastUpdated"] = lastUpdated as CKRecordValue
        record["weeklyDistance"] = weeklyDistance as CKRecordValue
        record["monthlyDistance"] = monthlyDistance as CKRecordValue
        record["topPerformers"] = topPerformers as CKRecordValue
        
        return record
    }
}

// MARK: - Helper Extensions

extension ActivityType {
    static func fromStringArray(_ strings: [String]) -> [ActivityType] {
        return strings.compactMap { ActivityType(rawValue: $0) }
    }
}

extension MemberStats {
    static func fromCloudKit(totalDistance: Double, totalWorkouts: Int, averagePace: Double, currentStreak: Int, lastWorkoutDate: Date, monthlyDistance: Double, weeklyDistance: Double, rank: Int) -> MemberStats {
        var stats = MemberStats()
        stats.totalDistance = totalDistance
        stats.totalWorkouts = totalWorkouts
        stats.averagePace = averagePace
        stats.currentStreak = currentStreak
        stats.lastWorkoutDate = lastWorkoutDate
        stats.monthlyDistance = monthlyDistance
        stats.weeklyDistance = weeklyDistance
        stats.rank = rank
        return stats
    }
}