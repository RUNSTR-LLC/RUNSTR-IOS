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
    
    init(name: String, description: String, captainID: String, activityLevel: ActivityLevel, maxMembers: Int = 500) {
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