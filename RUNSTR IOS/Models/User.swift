import Foundation
import AuthenticationServices
import HealthKit
import NostrSDK

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let appleUserID: String?
    let nostrPublicKey: String // npub - generated for this user
    let nostrPrivateKey: String // nsec - stored securely
    let createdAt: Date
    var profile: UserProfile
    var stats: UserStats
    var loginMethod: LoginMethod
    
    // Apple Sign-In initializer with optional Nostr keys (generated automatically if empty)
    init(appleUserID: String?, email: String?, nostrPublicKey: String = "", nostrPrivateKey: String = "") {
        self.id = UUID().uuidString
        self.appleUserID = appleUserID
        self.email = email
        
        // Generate real Nostr keys if not provided
        if nostrPublicKey.isEmpty || nostrPrivateKey.isEmpty {
            if let nostrSDKKeypair = Keypair() {
                let keyPair = NostrKeyPair(
                    privateKey: nostrSDKKeypair.privateKey.nsec,
                    publicKey: nostrSDKKeypair.publicKey.npub
                )
                self.nostrPublicKey = keyPair.publicKey
                self.nostrPrivateKey = keyPair.privateKey
            } else {
                // Fallback if key generation fails
                self.nostrPublicKey = ""
                self.nostrPrivateKey = ""
            }
        } else {
            self.nostrPublicKey = nostrPublicKey
            self.nostrPrivateKey = nostrPrivateKey
        }
        
        self.createdAt = Date()
        self.profile = UserProfile()
        self.stats = UserStats()
        self.loginMethod = .apple
    }
    
    
    
    
    
    
    
}

enum LoginMethod: String, Codable {
    case apple
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
    
    // MARK: - Profile Update Methods
    
    /// Update profile information
    mutating func updateProfile(displayName: String? = nil, about: String? = nil, profilePicture: String? = nil) {
        if let displayName = displayName {
            self.displayName = displayName
        }
        if let about = about {
            self.about = about
        }
        if let profilePicture = profilePicture {
            self.profilePicture = profilePicture
        }
    }
    
    /// Update from Nostr profile data
    mutating func updateFromNostrProfile(_ nostrProfile: NostrProfile) {
        if let displayName = nostrProfile.displayName, !displayName.isEmpty {
            self.displayName = displayName
        }
        if let about = nostrProfile.about, !about.isEmpty {
            self.about = about
        }
        if let picture = nostrProfile.picture, !picture.isEmpty {
            self.profilePicture = picture
        }
        if let banner = nostrProfile.banner, !banner.isEmpty {
            self.banner = banner
        }
        if let nip05 = nostrProfile.nip05, !nip05.isEmpty {
            self.nip05 = nip05
        }
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
    var privacyLevel: PrivacyLevel = .public
}

struct UserStats: Codable {
    var totalDistance: Double = 0.0
    var totalWorkouts: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastWorkoutDate: Date = Date.distantPast
    var lastUpdated: Date = Date()
    
    // MARK: - Stats Methods
    
    /// Update stats after a workout
    mutating func recordWorkout(_ workout: Workout) {
        totalDistance += workout.distance
        totalWorkouts += 1
        lastWorkoutDate = workout.startTime
        lastUpdated = Date()
    }
    
    /// Update streak statistics
    mutating func updateStreak(current: Int, longest: Int) {
        currentStreak = current
        longestStreak = max(longestStreak, longest)
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
    
    /// Get formatted total distance (legacy - use formattedTotalDistance(unitService:) instead)
    var formattedTotalDistance: String {
        let km = totalDistance / 1000
        return String(format: "%.1f km", km)
    }
    
    /// Get formatted total distance using unit preferences
    @MainActor
    func formattedTotalDistance(unitService: UnitPreferencesService) -> String {
        return unitService.formatDistance(totalDistance, precision: 1)
    }
    
    /// Get average distance per workout
    var averageDistancePerWorkout: Double {
        guard totalWorkouts > 0 else { return 0.0 }
        return totalDistance / Double(totalWorkouts)
    }
}

enum ActivityType: String, Codable, CaseIterable {
    case running = "running"
    case walking = "walking"
    case cycling = "cycling"
    
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        }
    }
    
    var hkWorkoutActivityType: HKWorkoutActivityType {
        switch self {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        }
    }
}

// Supporting types that need to be defined


enum ActivityLevel: String, Codable {
    case beginner
    case intermediate  
    case advanced
    case expert
}

enum PrivacyLevel: String, Codable {
    case `private`
    case friends
    case `public`
}