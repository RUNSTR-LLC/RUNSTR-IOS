import Foundation

struct CashuWallet: Codable {
    let id: String
    var balance: Int // sats
    var transactions: [CashuTransaction]
    let mintURL: String
    private var tokens: [CashuToken]
    
    init(mintURL: String = "https://mint.runstr.app") {
        self.id = UUID().uuidString
        self.balance = 0
        self.transactions = []
        self.mintURL = mintURL
        self.tokens = []
    }
    
    mutating func addReward(_ amount: Int, source: RewardSource, workoutID: String? = nil) {
        let transaction = CashuTransaction(
            amount: amount,
            type: .reward,
            source: source,
            workoutID: workoutID
        )
        
        transactions.append(transaction)
        balance += amount
    }
    
    mutating func withdraw(_ amount: Int, destination: String) -> Bool {
        guard balance >= amount else { return false }
        
        let transaction = CashuTransaction(
            amount: -amount,
            type: .withdrawal,
            source: .withdrawal,
            destination: destination
        )
        
        transactions.append(transaction)
        balance -= amount
        return true
    }
    
    var totalEarned: Int {
        return transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }
    
    var totalWithdrawn: Int {
        return transactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }
    
    var recentTransactions: [CashuTransaction] {
        return Array(transactions.suffix(10))
    }
}

struct CashuTransaction: Codable, Identifiable {
    let id: String
    let amount: Int // positive for incoming, negative for outgoing
    let type: TransactionType
    let source: RewardSource
    let timestamp: Date
    let workoutID: String?
    let destination: String? // for withdrawals
    var status: TransactionStatus
    
    init(amount: Int, type: TransactionType, source: RewardSource, workoutID: String? = nil, destination: String? = nil) {
        self.id = UUID().uuidString
        self.amount = amount
        self.type = type
        self.source = source
        self.timestamp = Date()
        self.workoutID = workoutID
        self.destination = destination
        self.status = .pending
    }
    
    var displayAmount: String {
        let absAmount = abs(amount)
        return amount >= 0 ? "+\(absAmount) sats" : "-\(absAmount) sats"
    }
    
    var displaySource: String {
        switch source {
        case .workout: return "Workout Reward"
        case .streak: return "Streak Bonus"
        case .personalRecord: return "Personal Record"
        case .eventPrize: return "Event Prize"
        case .teamBonus: return "Team Bonus"
        case .captainEarnings: return "Captain Earnings"
        case .withdrawal: return "Lightning Withdrawal"
        }
    }
}

enum TransactionType: String, Codable {
    case reward = "reward"
    case withdrawal = "withdrawal"
    case refund = "refund"
}

enum RewardSource: String, Codable {
    case workout = "workout"
    case streak = "streak"
    case personalRecord = "personal_record"
    case eventPrize = "event_prize"
    case teamBonus = "team_bonus"
    case captainEarnings = "captain_earnings"
    case withdrawal = "withdrawal"
}

enum TransactionStatus: String, Codable {
    case pending = "pending"
    case confirmed = "confirmed"
    case failed = "failed"
}


struct RewardCalculator {
    static func calculateWorkoutReward(workout: Workout, userStats: UserStats) -> Int {
        let baseReward = calculateBaseReward(distance: workout.distance, duration: workout.duration)
        let streakMultiplier = calculateStreakMultiplier(currentStreak: userStats.currentStreak)
        let paceBonus = calculatePaceBonus(workout: workout, userStats: userStats)
        
        return Int(Double(baseReward) * streakMultiplier) + paceBonus
    }
    
    private static func calculateBaseReward(distance: Double, duration: TimeInterval) -> Int {
        let distanceKm = distance / 1000
        let durationMinutes = duration / 60
        
        // Base reward: 50 sats per km + 10 sats per minute
        let distanceReward = Int(distanceKm * 50)
        let timeReward = Int(durationMinutes * 10)
        
        return max(100, distanceReward + timeReward) // Minimum 100 sats
    }
    
    private static func calculateStreakMultiplier(currentStreak: Int) -> Double {
        switch currentStreak {
        case 0...6: return 1.0
        case 7...29: return 2.0
        case 30...89: return 3.0
        default: return 4.0
        }
    }
    
    private static func calculatePaceBonus(workout: Workout, userStats: UserStats) -> Int {
        guard let personalRecord = userStats.personalRecords[workout.activityType] else {
            return 0 // No bonus for first workout of type
        }
        
        if workout.averagePace < personalRecord.pace {
            return 1000 // 1000 sat bonus for new personal record
        }
        
        return 0
    }
    
    static func calculateCaptainEarnings(teamMemberCount: Int) -> Int {
        return teamMemberCount * 1000 // 1000 sats per member per month
    }
}