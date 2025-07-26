import Foundation

struct Event: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let createdBy: String // User ID
    let startDate: Date
    let endDate: Date
    let goalType: EventGoalType
    let targetValue: Double
    let difficulty: EventDifficulty
    let eventType: EventType
    var participants: [String] = [] // User IDs
    let prizePool: Int // sats
    let maxParticipants: Int?
    let entryRequirements: [EntryRequirement]
    var leaderboard: [LeaderboardEntry] = []
    let nostrListID: String
    var isActive: Bool { Date() >= startDate && Date() <= endDate }
    var hasEnded: Bool { Date() > endDate }
    
    init(name: String, description: String, createdBy: String, startDate: Date, endDate: Date, goalType: EventGoalType, targetValue: Double, difficulty: EventDifficulty, eventType: EventType, prizePool: Int) {
        self.id = UUID().uuidString
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
        self.maxParticipants = nil
        self.entryRequirements = []
        self.nostrListID = "event_\(self.id)"
    }
    
    var daysRemaining: Int {
        guard !hasEnded else { return 0 }
        if !isActive {
            return Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
        }
        return Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
    }
    
    var duration: Int {
        return Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}

enum EventGoalType: String, Codable, CaseIterable {
    case totalDistance = "total_distance"
    case longestSingleRun = "longest_single_run"
    case averagePace = "average_pace"
    case streakDays = "streak_days"
    case totalWorkouts = "total_workouts"
    case fastestTime = "fastest_time" // for specific distances
    
    var displayName: String {
        switch self {
        case .totalDistance: return "Total Distance"
        case .longestSingleRun: return "Longest Single Run"
        case .averagePace: return "Average Pace"
        case .streakDays: return "Consecutive Days"
        case .totalWorkouts: return "Total Workouts"
        case .fastestTime: return "Fastest Time"
        }
    }
    
    var unit: String {
        switch self {
        case .totalDistance, .longestSingleRun: return "km"
        case .averagePace: return "min/km"
        case .streakDays: return "days"
        case .totalWorkouts: return "workouts"
        case .fastestTime: return "minutes"
        }
    }
    
    var isLowerBetter: Bool {
        switch self {
        case .averagePace, .fastestTime: return true
        default: return false
        }
    }
}

enum EventDifficulty: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case elite = "elite"
    
    var displayName: String {
        return self.rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "blue"
        case .advanced: return "orange"
        case .elite: return "red"
        }
    }
}

enum EventType: String, Codable, CaseIterable {
    case individual = "individual"
    case teamVsTeam = "team_vs_team"
    case community = "community"
    
    var displayName: String {
        switch self {
        case .individual: return "Individual"
        case .teamVsTeam: return "Team vs Team"
        case .community: return "Community"
        }
    }
}

struct EntryRequirement: Codable {
    let type: RequirementType
    let value: String
    
    enum RequirementType: String, Codable {
        case minSubscriptionTier = "min_subscription_tier"
        case teamMembership = "team_membership"
        case minActivityLevel = "min_activity_level"
        case inviteOnly = "invite_only"
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let userID: String
    let userName: String
    var currentValue: Double
    var rank: Int
    let lastUpdated: Date
    var progress: Double {
        // Calculate progress based on goal type and target
        return currentValue
    }
}

struct EventProgress: Identifiable {
    let id = UUID()
    let eventID: String
    let userID: String
    var currentValue: Double
    var workoutsContributed: [String] // Workout IDs
    var lastUpdated: Date
    
    func calculateProgress(for goalType: EventGoalType, workouts: [Workout]) -> Double {
        let relevantWorkouts = workouts.filter { workoutsContributed.contains($0.id) }
        
        switch goalType {
        case .totalDistance:
            return relevantWorkouts.reduce(0) { $0 + $1.distance / 1000 }
        case .longestSingleRun:
            return relevantWorkouts.map { $0.distance / 1000 }.max() ?? 0
        case .averagePace:
            let totalPace = relevantWorkouts.reduce(0) { $0 + $1.averagePace }
            return relevantWorkouts.isEmpty ? 0 : totalPace / Double(relevantWorkouts.count)
        case .streakDays:
            return calculateStreakDays(from: relevantWorkouts)
        case .totalWorkouts:
            return Double(relevantWorkouts.count)
        case .fastestTime:
            return relevantWorkouts.map { $0.duration / 60 }.min() ?? Double.infinity
        }
    }
    
    private func calculateStreakDays(from workouts: [Workout]) -> Double {
        let sortedDates = workouts.map { Calendar.current.startOfDay(for: $0.startTime) }
            .sorted()
        
        var streak = 0
        var currentStreak = 1
        
        for i in 1..<sortedDates.count {
            let daysDifference = Calendar.current.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
            
            if daysDifference == 1 {
                currentStreak += 1
            } else {
                streak = max(streak, currentStreak)
                currentStreak = 1
            }
        }
        
        return Double(max(streak, currentStreak))
    }
}