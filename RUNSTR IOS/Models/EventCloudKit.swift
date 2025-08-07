import Foundation
import CloudKit

// MARK: - CloudKit Extensions for Event Models

extension Event {
    /// CloudKit Record Type name
    static let recordType = "Event"
    
    /// Initialize Event from CloudKit CKRecord
    init?(record: CKRecord) {
        guard let name = record["name"] as? String,
              let description = record["description"] as? String,
              let createdBy = record["createdBy"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let goalTypeRaw = record["goalType"] as? String,
              let goalType = EventGoalType(rawValue: goalTypeRaw),
              let targetValue = record["targetValue"] as? Double,
              let difficultyRaw = record["difficulty"] as? String,
              let difficulty = EventDifficulty(rawValue: difficultyRaw),
              let eventTypeRaw = record["eventType"] as? String,
              let eventType = EventType(rawValue: eventTypeRaw),
              let prizePool = record["prizePool"] as? Int else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.name = name
        self.description = description
        self.createdBy = createdBy
        self.startDate = startDate
        self.endDate = endDate
        self.goalType = goalType
        self.targetValue = targetValue
        self.difficulty = difficulty
        self.eventType = eventType
        self.prizePool = prizePool
        self.participants = (record["participants"] as? [String]) ?? []
        self.maxParticipants = record["maxParticipants"] as? Int
        self.leaderboard = [] // Will be populated separately
        self.nostrListID = record["nostrListID"] as? String ?? "event_\(self.id)"
        
        // Parse entry requirements from CloudKit
        if let requirementsData = record["entryRequirements"] as? Data {
            do {
                self.entryRequirements = try JSONDecoder().decode([EntryRequirement].self, from: requirementsData)
            } catch {
                self.entryRequirements = []
                print("Failed to decode entry requirements: \(error)")
            }
        } else {
            self.entryRequirements = []
        }
    }
    
    /// Convert Event to CloudKit CKRecord
    func toCKRecord(container: CKContainer = CKContainer.default()) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: Event.recordType, recordID: recordID)
        
        record["name"] = name as CKRecordValue
        record["description"] = description as CKRecordValue
        record["createdBy"] = createdBy as CKRecordValue
        record["startDate"] = startDate as CKRecordValue
        record["endDate"] = endDate as CKRecordValue
        record["goalType"] = goalType.rawValue as CKRecordValue
        record["targetValue"] = targetValue as CKRecordValue
        record["difficulty"] = difficulty.rawValue as CKRecordValue
        record["eventType"] = eventType.rawValue as CKRecordValue
        record["prizePool"] = prizePool as CKRecordValue
        record["participants"] = participants as CKRecordValue
        record["maxParticipants"] = maxParticipants as CKRecordValue?
        record["nostrListID"] = nostrListID as CKRecordValue
        
        // Encode entry requirements as JSON data
        if let requirementsData = try? JSONEncoder().encode(entryRequirements) {
            record["entryRequirements"] = requirementsData as CKRecordValue
        }
        
        return record
    }
}

// MARK: - Event Registration Model for CloudKit
struct EventRegistration: Codable, Identifiable {
    let id: String
    let eventID: String
    let userID: String
    let userName: String
    let registrationDate: Date
    let paymentAmount: Int // sats for entry fee
    let paymentTransactionID: String?
    var isActive: Bool = true
    var hasCompleted: Bool = false
    
    init(eventID: String, userID: String, userName: String, paymentAmount: Int = 0) {
        self.id = UUID().uuidString
        self.eventID = eventID
        self.userID = userID
        self.userName = userName
        self.registrationDate = Date()
        self.paymentAmount = paymentAmount
        self.paymentTransactionID = nil
        self.isActive = true
        self.hasCompleted = false
    }
}

extension EventRegistration {
    /// CloudKit Record Type name
    static let recordType = "EventRegistration"
    
    /// Initialize EventRegistration from CloudKit CKRecord
    init?(record: CKRecord) {
        guard let eventID = record["eventID"] as? String,
              let userID = record["userID"] as? String,
              let userName = record["userName"] as? String,
              let registrationDate = record["registrationDate"] as? Date,
              let paymentAmount = record["paymentAmount"] as? Int else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.eventID = eventID
        self.userID = userID
        self.userName = userName
        self.registrationDate = registrationDate
        self.paymentAmount = paymentAmount
        self.paymentTransactionID = record["paymentTransactionID"] as? String
        self.isActive = (record["isActive"] as? Int) == 1
        self.hasCompleted = (record["hasCompleted"] as? Int) == 1
    }
    
    /// Convert EventRegistration to CloudKit CKRecord
    func toCKRecord(container: CKContainer = CKContainer.default()) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: EventRegistration.recordType, recordID: recordID)
        
        record["eventID"] = eventID as CKRecordValue
        record["userID"] = userID as CKRecordValue
        record["userName"] = userName as CKRecordValue
        record["registrationDate"] = registrationDate as CKRecordValue
        record["paymentAmount"] = paymentAmount as CKRecordValue
        record["paymentTransactionID"] = paymentTransactionID as CKRecordValue?
        record["isActive"] = (isActive ? 1 : 0) as CKRecordValue
        record["hasCompleted"] = (hasCompleted ? 1 : 0) as CKRecordValue
        
        return record
    }
}

// MARK: - Enhanced Event Progress Model for CloudKit
struct EventProgressCloudKit: Codable, Identifiable {
    let id: String
    let eventID: String
    let userID: String
    let userName: String
    var currentValue: Double
    var workoutIDs: [String] // Workout IDs that contribute to this event
    var lastUpdated: Date
    var rank: Int = 0
    var isCompleted: Bool = false
    var completedDate: Date?
    
    init(eventID: String, userID: String, userName: String) {
        self.id = "\(eventID)_\(userID)"
        self.eventID = eventID
        self.userID = userID
        self.userName = userName
        self.currentValue = 0.0
        self.workoutIDs = []
        self.lastUpdated = Date()
        self.rank = 0
        self.isCompleted = false
        self.completedDate = nil
    }
    
    /// Calculate progress percentage (0.0 to 1.0) based on target value
    func progressPercentage(targetValue: Double) -> Double {
        guard targetValue > 0 else { return 0.0 }
        return min(currentValue / targetValue, 1.0)
    }
}

extension EventProgressCloudKit {
    /// CloudKit Record Type name
    static let recordType = "EventProgress"
    
    /// Initialize EventProgress from CloudKit CKRecord
    init?(record: CKRecord) {
        guard let eventID = record["eventID"] as? String,
              let userID = record["userID"] as? String,
              let userName = record["userName"] as? String,
              let currentValue = record["currentValue"] as? Double,
              let lastUpdated = record["lastUpdated"] as? Date else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.eventID = eventID
        self.userID = userID
        self.userName = userName
        self.currentValue = currentValue
        self.workoutIDs = (record["workoutIDs"] as? [String]) ?? []
        self.lastUpdated = lastUpdated
        self.rank = (record["rank"] as? Int) ?? 0
        self.isCompleted = (record["isCompleted"] as? Int) == 1
        self.completedDate = record["completedDate"] as? Date
    }
    
    /// Convert EventProgress to CloudKit CKRecord
    func toCKRecord(container: CKContainer = CKContainer.default()) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: EventProgressCloudKit.recordType, recordID: recordID)
        
        record["eventID"] = eventID as CKRecordValue
        record["userID"] = userID as CKRecordValue
        record["userName"] = userName as CKRecordValue
        record["currentValue"] = currentValue as CKRecordValue
        record["workoutIDs"] = workoutIDs as CKRecordValue
        record["lastUpdated"] = lastUpdated as CKRecordValue
        record["rank"] = rank as CKRecordValue
        record["isCompleted"] = (isCompleted ? 1 : 0) as CKRecordValue
        record["completedDate"] = completedDate as CKRecordValue?
        
        return record
    }
}

// MARK: - Enhanced Leaderboard Entry for CloudKit
extension LeaderboardEntry {
    /// CloudKit Record Type name  
    static let recordType = "LeaderboardEntry"
    
    /// Initialize LeaderboardEntry from CloudKit CKRecord
    init?(record: CKRecord) {
        guard let userID = record["userID"] as? String,
              let userName = record["userName"] as? String,
              let currentValue = record["currentValue"] as? Double,
              let rank = record["rank"] as? Int,
              let lastUpdated = record["lastUpdated"] as? Date else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.userID = userID
        self.userName = userName
        self.currentValue = currentValue
        self.rank = rank
        self.lastUpdated = lastUpdated
    }
    
    /// Convert LeaderboardEntry to CloudKit CKRecord
    func toCKRecord(eventID: String, container: CKContainer = CKContainer.default()) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "\(eventID)_leaderboard_\(userID)")
        let record = CKRecord(recordType: LeaderboardEntry.recordType, recordID: recordID)
        
        record["eventID"] = eventID as CKRecordValue
        record["userID"] = userID as CKRecordValue
        record["userName"] = userName as CKRecordValue
        record["currentValue"] = currentValue as CKRecordValue
        record["rank"] = rank as CKRecordValue
        record["lastUpdated"] = lastUpdated as CKRecordValue
        
        return record
    }
}

// MARK: - Event Ticket Model for Premium Events
struct EventTicket: Codable, Identifiable {
    let id: String
    let eventID: String
    let purchaserID: String
    let purchaserName: String
    let ticketPrice: Int // sats
    let purchaseDate: Date
    let paymentTransactionID: String
    var isValid: Bool = true
    var usedDate: Date?
    
    init(eventID: String, purchaserID: String, purchaserName: String, ticketPrice: Int, paymentTransactionID: String) {
        self.id = UUID().uuidString
        self.eventID = eventID
        self.purchaserID = purchaserID
        self.purchaserName = purchaserName
        self.ticketPrice = ticketPrice
        self.purchaseDate = Date()
        self.paymentTransactionID = paymentTransactionID
        self.isValid = true
        self.usedDate = nil
    }
}

extension EventTicket {
    /// CloudKit Record Type name
    static let recordType = "EventTicket"
    
    /// Initialize EventTicket from CloudKit CKRecord
    init?(record: CKRecord) {
        guard let eventID = record["eventID"] as? String,
              let purchaserID = record["purchaserID"] as? String,
              let purchaserName = record["purchaserName"] as? String,
              let ticketPrice = record["ticketPrice"] as? Int,
              let purchaseDate = record["purchaseDate"] as? Date,
              let paymentTransactionID = record["paymentTransactionID"] as? String else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.eventID = eventID
        self.purchaserID = purchaserID
        self.purchaserName = purchaserName
        self.ticketPrice = ticketPrice
        self.purchaseDate = purchaseDate
        self.paymentTransactionID = paymentTransactionID
        self.isValid = (record["isValid"] as? Int) == 1
        self.usedDate = record["usedDate"] as? Date
    }
    
    /// Convert EventTicket to CloudKit CKRecord
    func toCKRecord(container: CKContainer = CKContainer.default()) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: EventTicket.recordType, recordID: recordID)
        
        record["eventID"] = eventID as CKRecordValue
        record["purchaserID"] = purchaserID as CKRecordValue
        record["purchaserName"] = purchaserName as CKRecordValue
        record["ticketPrice"] = ticketPrice as CKRecordValue
        record["purchaseDate"] = purchaseDate as CKRecordValue
        record["paymentTransactionID"] = paymentTransactionID as CKRecordValue
        record["isValid"] = (isValid ? 1 : 0) as CKRecordValue
        record["usedDate"] = usedDate as CKRecordValue?
        
        return record
    }
}