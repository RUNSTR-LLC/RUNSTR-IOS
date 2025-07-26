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
    var personalRecords: [ActivityType: PersonalRecord] = [:]
    var totalSatsEarned: Int = 0
}

struct PersonalRecord: Codable {
    let distance: Double
    let time: Double // seconds
    let pace: Double // minutes per km
    let achievedAt: Date
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