import Foundation

struct Team: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let captainID: String
    let createdAt: Date
    var memberIDs: [String]
    var memberCount: Int { memberIDs.count }
    let maxMembers: Int
    let activityLevel: ActivityLevel
    let isPublic: Bool
    var imageURL: String?
    var stats: TeamStats
    let nostrListID: String // NIP-51 list identifier
    
    // NIP-101e Enhanced fields
    let teamType: String // "running_club", "cycling_group", "mixed_fitness"
    let location: String? // City, region for local team discovery
    let supportedActivityTypes: [ActivityType] // Activities this team focuses on
    var activeChallenges: [String] // Challenge IDs team is participating in
    var teamEvents: [String] // Event IDs created by this team
    let nostrEventID: String? // Kind 33404 event ID on Nostr
    
    init(name: String, description: String, captainID: String, activityLevel: ActivityLevel, maxMembers: Int = 500, teamType: String = "running_club", location: String? = nil, supportedActivityTypes: [ActivityType] = [.running, .walking]) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.captainID = captainID
        self.createdAt = Date()
        self.memberIDs = [captainID]
        self.maxMembers = maxMembers
        self.activityLevel = activityLevel
        self.isPublic = true
        self.stats = TeamStats()
        self.nostrListID = "team_\(self.id)"
        
        // NIP-101e fields
        self.teamType = teamType
        self.location = location
        self.supportedActivityTypes = supportedActivityTypes
        self.activeChallenges = []
        self.teamEvents = []
        self.nostrEventID = nil
    }
    
    /// Initialize Team from FitnessTeamEvent (Kind 33404)
    init?(from fitnessTeamEvent: FitnessTeamEvent, activityLevel: ActivityLevel = .intermediate) {
        self.id = fitnessTeamEvent.id
        self.name = fitnessTeamEvent.name
        self.description = fitnessTeamEvent.content
        self.captainID = fitnessTeamEvent.captainPubkey
        self.createdAt = fitnessTeamEvent.createdAt
        self.memberIDs = fitnessTeamEvent.memberPubkeys
        self.maxMembers = 500 // Default, could be derived from tags if specified
        self.activityLevel = activityLevel
        self.isPublic = fitnessTeamEvent.isPublic
        self.stats = TeamStats()
        self.nostrListID = "team_\(fitnessTeamEvent.id)"
        
        // NIP-101e enhanced fields
        self.teamType = fitnessTeamEvent.teamType
        self.location = fitnessTeamEvent.location
        self.supportedActivityTypes = [.running, .walking] // Default, could be parsed from tags
        self.activeChallenges = []
        self.teamEvents = []
        self.nostrEventID = fitnessTeamEvent.id
        
        self.imageURL = nil
    }
    
    /// Convert Team to FitnessTeamEvent for Nostr publishing
    func toFitnessTeamEvent() -> FitnessTeamEvent? {
        let tags: [[String]] = [
            ["d", id],
            ["name", name],
            ["type", teamType],
            ["captain", captainID],
            ["public", isPublic ? "true" : "false"],
            ["t", "team"],
            ["t", "fitness"]
        ] + (location.map { [["location", $0]] } ?? []) +
        memberIDs.map { ["member", $0] }
        
        return FitnessTeamEvent(
            eventContent: description,
            tags: tags,
            createdAt: createdAt
        )
    }
    
    /// Check if team supports a specific activity type
    func supportsActivity(_ activityType: ActivityType) -> Bool {
        return supportedActivityTypes.contains(activityType) || teamType == "mixed_fitness"
    }
    
    /// Add member to team (updates memberIDs array)
    mutating func addMember(_ memberID: String) -> Bool {
        guard !memberIDs.contains(memberID), memberIDs.count < maxMembers else {
            return false
        }
        memberIDs.append(memberID)
        return true
    }
    
    /// Remove member from team
    mutating func removeMember(_ memberID: String) -> Bool {
        guard let index = memberIDs.firstIndex(of: memberID), memberID != captainID else {
            return false
        }
        memberIDs.remove(at: index)
        return true
    }
    
    /// Join challenge as a team
    mutating func joinChallenge(_ challengeID: String) {
        if !activeChallenges.contains(challengeID) {
            activeChallenges.append(challengeID)
        }
    }
    
    /// Leave challenge
    mutating func leaveChallenge(_ challengeID: String) {
        activeChallenges.removeAll { $0 == challengeID }
    }
}

struct TeamStats: Codable {
    var totalDistance: Double = 0.0
    var totalWorkouts: Int = 0
    var averageWorkoutsPerMember: Double = 0.0
    var topPerformers: [String] = [] // User IDs
    var monthlyStats: [String: MonthlyTeamStats] = [:] // "YYYY-MM" -> stats
}

struct MonthlyTeamStats: Codable {
    let month: String
    var totalDistance: Double = 0.0
    var totalWorkouts: Int = 0
    var activeMembers: Int = 0
    var captainEarnings: Int = 0 // sats earned by captain
}

enum ActivityLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case competitive = "competitive"
    
    var displayName: String {
        return self.rawValue.capitalized
    }
    
    var description: String {
        switch self {
        case .beginner:
            return "Just starting out or getting back into fitness"
        case .intermediate:
            return "Regular exercise routine, comfortable with challenges"
        case .advanced:
            return "Serious about fitness, trains regularly"
        case .competitive:
            return "Competitive athlete or very serious trainer"
        }
    }
    
    var recommendedWeeklyDistance: ClosedRange<Double> {
        switch self {
        case .beginner: return 5.0...15.0
        case .intermediate: return 15.0...30.0
        case .advanced: return 30.0...50.0
        case .competitive: return 50.0...100.0
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        case .competitive: return 3
        }
    }
}

struct TeamMember: Codable, Identifiable {
    let id: String // User ID
    let joinedAt: Date
    var role: TeamRole
    var stats: MemberStats
    var isActive: Bool { stats.lastWorkoutDate > Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() }
}

struct MemberStats: Codable {
    var totalDistance: Double = 0.0
    var totalWorkouts: Int = 0
    var averagePace: Double = 0.0
    var currentStreak: Int = 0
    var lastWorkoutDate: Date = Date.distantPast
    var monthlyDistance: Double = 0.0
    var weeklyDistance: Double = 0.0
    var rank: Int = 0
}

enum TeamRole: String, Codable {
    case captain = "captain"
    case member = "member"
    case moderator = "moderator"
    
    var displayName: String {
        return self.rawValue.capitalized
    }
}

struct TeamChallenge: Codable, Identifiable {
    let id: String
    let teamID: String
    let name: String
    let description: String
    let goalType: ChallengeGoalType
    let targetValue: Double
    let startDate: Date
    let endDate: Date
    let createdBy: String // User ID
    var participants: [String] = [] // User IDs
    var progress: Double = 0.0
    var isCompleted: Bool { progress >= targetValue }
    let rewardPool: Int // sats
    
    var progressPercentage: Double {
        return min(100.0, (progress / targetValue) * 100.0)
    }
    
    var daysRemaining: Int {
        return Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
    }
}

enum ChallengeGoalType: String, Codable {
    case totalDistance = "total_distance"
    case totalWorkouts = "total_workouts"
    case averageDistance = "average_distance"
    case participationRate = "participation_rate"
    
    var displayName: String {
        switch self {
        case .totalDistance: return "Total Distance"
        case .totalWorkouts: return "Total Workouts"
        case .averageDistance: return "Average Distance"
        case .participationRate: return "Participation Rate"
        }
    }
    
    var unit: String {
        switch self {
        case .totalDistance, .averageDistance: return "km"
        case .totalWorkouts: return "workouts"
        case .participationRate: return "%"
        }
    }
}