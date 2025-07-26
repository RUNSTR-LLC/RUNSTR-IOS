import Foundation
import AuthenticationServices

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let appleUserID: String?
    let nostrPublicKey: String // npub
    private let nostrPrivateKey: String // nsec - stored securely
    let subscriptionTier: SubscriptionTier
    let createdAt: Date
    var profile: UserProfile
    var stats: UserStats
    
    init(appleUserID: String?, email: String?, nostrKeys: NostrKeyPair) {
        self.id = UUID().uuidString
        self.appleUserID = appleUserID
        self.email = email
        self.nostrPublicKey = nostrKeys.publicKey
        self.nostrPrivateKey = nostrKeys.privateKey
        self.subscriptionTier = .none
        self.createdAt = Date()
        self.profile = UserProfile()
        self.stats = UserStats()
    }
}

struct UserProfile: Codable {
    var displayName: String = ""
    var fitnessGoals: FitnessGoals = FitnessGoals()
    var preferences: UserPreferences = UserPreferences()
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
    var personalRecords: [ActivityType: PersonalRecord] = [:]
    var totalSatsEarned: Int = 0
}

struct PersonalRecord: Codable {
    let distance: Double
    let time: Double // seconds
    let pace: Double // minutes per km
    let achievedAt: Date
}

enum SubscriptionTier: String, Codable, CaseIterable {
    case none = "none"
    case member = "member"
    case captain = "captain"
    
    var monthlyPrice: Double {
        switch self {
        case .none: return 0.0
        case .member: return 5.99
        case .captain: return 20.99
        }
    }
    
    var features: [String] {
        switch self {
        case .none:
            return ["Basic tracking"]
        case .member:
            return ["Full tracking", "Team joining", "Events", "Bitcoin rewards", "Basic AI coaching"]
        case .captain:
            return ["All Member features", "Team creation", "Event creation", "1000 sats/member/month", "Advanced analytics"]
        }
    }
}

enum PrivacyLevel: String, Codable {
    case `private` = "private"
    case team = "team"
    case `public` = "public"
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