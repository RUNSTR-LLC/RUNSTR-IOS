import Foundation
import AuthenticationServices

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let appleUserID: String?
    let runstrNostrPublicKey: String // npub - RUNSTR-generated key
    let runstrNostrPrivateKey: String // nsec - stored securely
    var mainNostrPublicKey: String? // User's existing npub (optional)
    var isDelegatedSigning: Bool = false // Has linked main npub
    var additionalNostrPublicKeys: [String] = [] // Additional npubs for stats
    var statsConfiguration: StatsConfiguration = StatsConfiguration()
    let subscriptionTier: SubscriptionTier
    let createdAt: Date
    var profile: UserProfile
    var stats: UserStats
    var loginMethod: LoginMethod
    
    // Apple Sign-In initializer
    init(appleUserID: String?, email: String?, nostrKeys: NostrKeyPair) {
        self.id = UUID().uuidString
        self.appleUserID = appleUserID
        self.email = email
        self.runstrNostrPublicKey = nostrKeys.publicKey
        self.runstrNostrPrivateKey = nostrKeys.privateKey
        self.mainNostrPublicKey = nil
        self.subscriptionTier = .none
        self.createdAt = Date()
        self.profile = UserProfile()
        self.stats = UserStats()
        self.loginMethod = .apple
    }
    
    // Nostr login initializer
    init(mainNostrPublicKey: String, runstrNostrKeys: NostrKeyPair, profile: NostrProfile? = nil) {
        self.id = UUID().uuidString
        self.appleUserID = nil
        self.email = nil
        self.runstrNostrPublicKey = runstrNostrKeys.publicKey
        self.runstrNostrPrivateKey = runstrNostrKeys.privateKey
        self.mainNostrPublicKey = mainNostrPublicKey
        self.isDelegatedSigning = false // Will be true after delegation setup
        self.subscriptionTier = .none
        self.createdAt = Date()
        self.profile = UserProfile(from: profile)
        self.stats = UserStats()
        self.loginMethod = .nostr
    }
    
    // Get display npub (main if linked, otherwise RUNSTR-generated)
    var displayNostrPublicKey: String {
        return mainNostrPublicKey ?? runstrNostrPublicKey
    }
    
    // Get all npubs configured for this user
    var allConfiguredNpubs: [String] {
        var npubs: [String] = [runstrNostrPublicKey]
        if let mainNpub = mainNostrPublicKey {
            npubs.append(mainNpub)
        }
        npubs.append(contentsOf: additionalNostrPublicKeys)
        return Array(Set(npubs)) // Remove duplicates
    }
    
    // Add an additional npub for stats aggregation
    mutating func addAdditionalNpub(_ npub: String) -> Bool {
        guard !npub.isEmpty,
              npub.hasPrefix("npub1"),
              npub != runstrNostrPublicKey,
              npub != mainNostrPublicKey,
              !additionalNostrPublicKeys.contains(npub) else {
            return false
        }
        
        additionalNostrPublicKeys.append(npub)
        return true
    }
    
    // Remove an additional npub
    mutating func removeAdditionalNpub(_ npub: String) {
        additionalNostrPublicKeys.removeAll { $0 == npub }
    }
    
    // Update stats configuration
    mutating func updateStatsConfiguration(_ config: StatsConfiguration) {
        self.statsConfiguration = config
    }
    
    // Toggle delegation signing
    mutating func setDelegationSigning(_ enabled: Bool) {
        self.isDelegatedSigning = enabled
    }
}

enum LoginMethod: String, Codable {
    case apple
    case nostr
    case email // Future implementation
}

struct NostrProfile: Codable {
    let displayName: String?
    let about: String?
    let picture: String?
    let banner: String?
    let nip05: String?
}

struct UserProfile: Codable {
    var displayName: String = ""
    var about: String = ""
    var profilePicture: String? = nil
    var banner: String? = nil
    var nip05: String? = nil
    var activityLevel: ActivityLevel = .intermediate
    var fitnessGoals: FitnessGoals = FitnessGoals()
    var preferences: UserPreferences = UserPreferences()
    
    // Initialize from Nostr profile
    init(from nostrProfile: NostrProfile? = nil) {
        if let profile = nostrProfile {
            self.displayName = profile.displayName ?? ""
            self.about = profile.about ?? ""
            self.profilePicture = profile.picture
            self.banner = profile.banner
            self.nip05 = profile.nip05
        }
        self.activityLevel = .intermediate
        self.fitnessGoals = FitnessGoals()
        self.preferences = UserPreferences()
    }
    
    // Default initializer
    init() {
        self.displayName = ""
        self.about = ""
        self.profilePicture = nil
        self.banner = nil
        self.nip05 = nil
        self.activityLevel = .intermediate
        self.fitnessGoals = FitnessGoals()
        self.preferences = UserPreferences()
    }
}

struct FitnessGoals: Codable {
    var weeklyDistanceTarget: Double = 10.0 // kilometers
    var weeklyWorkoutTarget: Int = 3
    var paceGoal: Double? // minutes per kilometer
}

struct UserPreferences: Codable {
    var notificationsEnabled: Bool = true
    var musicAutoPlay: Bool = true
    var privacyLevel: PrivacyLevel = .team
}

struct UserStats: Codable {
    var totalDistance: Double = 0.0
    var totalWorkouts: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalSatsEarned: Int = 0
    var totalStreakSatsEarned: Int = 0
    var weeklyStreaksCompleted: Int = 0
    var lastWorkoutDate: Date = Date.distantPast
    var lastUpdated: Date = Date()
    
    // MARK: - Streak Methods
    
    /// Update stats after a workout
    mutating func recordWorkout(_ workout: Workout, streakReward: Int) {
        totalDistance += workout.distance
        totalWorkouts += 1
        totalSatsEarned += workout.rewardAmount + streakReward
        totalStreakSatsEarned += streakReward
        lastWorkoutDate = workout.startTime
        lastUpdated = Date()
    }
    
    /// Update streak statistics
    mutating func updateStreak(current: Int, longest: Int) {
        currentStreak = current
        longestStreak = max(longestStreak, longest)
        lastUpdated = Date()
    }
    
    /// Record completion of weekly streak challenge
    mutating func recordWeeklyStreakCompletion(bonus: Int) {
        weeklyStreaksCompleted += 1
        totalSatsEarned += bonus
        totalStreakSatsEarned += bonus
        lastUpdated = Date()
    }
    
    /// Check if user worked out today
    func hasWorkedOutToday() -> Bool {
        return Calendar.current.isDateInToday(lastWorkoutDate)
    }
    
    /// Get days since last workout
    func daysSinceLastWorkout() -> Int {
        let days = Calendar.current.dateComponents([.day], from: lastWorkoutDate, to: Date()).day ?? 0
        return max(0, days)
    }
    
    /// Get formatted total distance
    var formattedTotalDistance: String {
        let km = totalDistance / 1000
        return String(format: "%.1f km", km)
    }
    
    /// Get average distance per workout
    var averageDistancePerWorkout: Double {
        guard totalWorkouts > 0 else { return 0.0 }
        return totalDistance / Double(totalWorkouts)
    }
    
    /// Get streak completion rate
    var streakCompletionRate: Double {
        guard totalWorkouts > 0 else { return 0.0 }
        // Rough estimation based on weeks since starting
        let daysSinceStart = Calendar.current.dateComponents([.day], from: lastUpdated.addingTimeInterval(-Double(totalWorkouts) * 86400), to: Date()).day ?? 1
        let possibleWeeks = max(1, daysSinceStart / 7)
        return Double(weeklyStreaksCompleted) / Double(possibleWeeks)
    }
}



enum ActivityType: String, Codable, CaseIterable {
    case running = "running"
    case walking = "walking"
    case cycling = "cycling"
    
    var displayName: String {
        return self.rawValue.capitalized
    }
    
    var systemImageName: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        }
    }
}