import Foundation
import NostrSDK
import CoreLocation

/// Manages workout-specific Nostr operations
@MainActor
class NostrWorkoutService: ObservableObject, NostrWorkoutServiceProtocol {
    
    // MARK: - Published Properties
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let connectionManager: NostrConnectionManagerProtocol
    
    // MARK: - Initialization
    init(connectionManager: NostrConnectionManagerProtocol) {
        self.connectionManager = connectionManager
        print("🏃‍♂️ NostrWorkoutService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Fetch user's workout history from Nostr relays (kind 1301 events)
    func fetchUserWorkouts(limit: Int = 100, since: Date? = nil, using keyManager: NostrKeyManagerProtocol) async -> [Workout] {
        await connectionManager.connect()
        
        guard let userKeyPair = keyManager.currentKeyPair,
              let relayPool = connectionManager.relayPool else {
            print("❌ No user keypair or relay pool available for workout fetch")
            await MainActor.run {
                errorMessage = "Missing user keys or relay connection"
            }
            return []
        }
        
        // Convert npub to hex format for filter
        guard let pubkey = PublicKey(npub: userKeyPair.publicKey) else {
            print("❌ Failed to parse user's public key")
            await MainActor.run {
                errorMessage = "Invalid user public key"
            }
            return []
        }
        
        print("🔍 Fetching workout history for user: \(userKeyPair.publicKey.prefix(20))...")
        
        // Create filter for kind 1301 events from this user
        let filter: Filter
        if let since = since {
            // Convert to Unix timestamp
            let sinceTimestamp = Int(since.timeIntervalSince1970)
            guard let workoutFilter = Filter(authors: [pubkey.hex], kinds: [1301], since: sinceTimestamp, limit: limit) else {
                print("❌ Failed to create filter with since timestamp")
                await MainActor.run {
                    errorMessage = "Failed to create workout filter"
                }
                return []
            }
            filter = workoutFilter
        } else {
            guard let workoutFilter = Filter(authors: [pubkey.hex], kinds: [1301], limit: limit) else {
                print("❌ Failed to create filter")
                await MainActor.run {
                    errorMessage = "Failed to create workout filter"
                }
                return []
            }
            filter = workoutFilter
        }
        
        return await withCheckedContinuation { continuation in
            var workouts: [Workout] = []
            var hasCompleted = false
            
            // Connect to relays and subscribe
            relayPool.connect()
            let subscriptionId = relayPool.subscribe(with: filter)
            print("📡 Subscribed to workout events with ID: \(subscriptionId)")
            
            // Since NostrSDK 0.3.0 subscribes but doesn't provide event callbacks,
            // we'll implement a simple polling mechanism for now
            
            // Set a timeout to complete the fetch
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if !hasCompleted {
                    hasCompleted = true
                    print("✅ Workout fetch completed")
                    print("📝 Note: NostrSDK 0.3.0 subscription callback implementation pending")
                    print("📝 This is a placeholder - actual events would be received via subscription callbacks")
                    
                    Task { @MainActor in
                        self.errorMessage = nil
                    }
                    
                    continuation.resume(returning: workouts)
                }
            }
        }
    }
    
    /// Parse a Nostr event (kind 1301) into a Workout object
    func parseWorkoutFromNostrEvent(_ event: NostrEvent) -> Workout? {
        // Validate event kind
        guard event.kind.rawValue == 1301 else {
            print("⚠️ Skipping non-workout event: kind \(event.kind.rawValue)")
            return nil
        }
        
        print("🔍 Parsing Nostr workout event: \(event.id.prefix(16))...")
        
        // Try to parse workout data from the event content
        guard let workoutData = event.content.data(using: .utf8),
              let workoutDict = try? JSONSerialization.jsonObject(with: workoutData) as? [String: Any] else {
            print("❌ Failed to parse workout event content as JSON")
            return nil
        }
        
        // Extract basic workout information
        guard let activityTypeString = workoutDict["activityType"] as? String,
              let activityType = ActivityType(rawValue: activityTypeString),
              let startTimeInterval = workoutDict["startTime"] as? TimeInterval,
              let duration = workoutDict["duration"] as? TimeInterval,
              let distance = workoutDict["distance"] as? Double else {
            print("❌ Missing required workout fields in Nostr event")
            return nil
        }
        
        let startTime = Date(timeIntervalSince1970: startTimeInterval)
        let endTime = Date(timeIntervalSince1970: startTimeInterval + duration)
        
        // Extract optional fields
        let calories = workoutDict["calories"] as? Double
        let averageHeartRate = workoutDict["averageHeartRate"] as? Double
        let maxHeartRate = workoutDict["maxHeartRate"] as? Double
        let steps = workoutDict["steps"] as? Int
        let elevationGain = workoutDict["elevationGain"] as? Double
        let elevationLoss = workoutDict["elevationLoss"] as? Double
        
        // Parse route if available
        var route: [CLLocationCoordinate2D]? = nil
        if let routeArray = workoutDict["route"] as? [[String: Double]] {
            route = routeArray.compactMap { coord in
                guard let lat = coord["latitude"], let lon = coord["longitude"] else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        
        // Create workout with Nostr metadata
        let workout = Workout(
            activityType: activityType,
            startTime: startTime,
            endTime: endTime,
            distance: distance,
            calories: calories,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            steps: steps,
            locations: route ?? [],
            source: .nostr,
            nostrEventID: event.id,
            nostrPubkey: event.pubkey,
            nostrRelaySource: "nostr_relay"
        )
        
        print("✅ Successfully parsed Nostr workout: \(workout.activityType.displayName)")
        return workout
    }
    
    /// Validate workout event content
    func validateWorkoutEvent(_ content: String) -> Bool {
        guard let data = content.data(using: .utf8),
              let workoutDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        
        // Check for required fields
        guard let activityTypeString = workoutDict["activityType"] as? String,
              ActivityType(rawValue: activityTypeString) != nil,
              workoutDict["startTime"] is TimeInterval,
              workoutDict["duration"] is TimeInterval,
              workoutDict["distance"] is Double else {
            return false
        }
        
        return true
    }
    
    /// Get workout statistics from Nostr events
    func getWorkoutStatistics(from workouts: [Workout]) -> WorkoutStatistics {
        guard !workouts.isEmpty else {
            return WorkoutStatistics()
        }
        
        let totalDistance = workouts.reduce(0) { $0 + $1.distance }
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        let totalCalories = workouts.compactMap { $0.calories }.reduce(0, +)
        let totalElevationGain = workouts.compactMap { $0.elevationGain }.reduce(0, +)
        
        let averageDistance = totalDistance / Double(workouts.count)
        let averageDuration = totalDuration / Double(workouts.count)
        
        // Group by activity type
        let runningWorkouts = workouts.filter { $0.activityType == .running }
        let cyclingWorkouts = workouts.filter { $0.activityType == .cycling }
        let walkingWorkouts = workouts.filter { $0.activityType == .walking }
        
        return WorkoutStatistics(
            totalWorkouts: workouts.count,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            totalCalories: totalCalories,
            totalElevationGain: totalElevationGain,
            averageDistance: averageDistance,
            averageDuration: averageDuration,
            runningCount: runningWorkouts.count,
            cyclingCount: cyclingWorkouts.count,
            walkingCount: walkingWorkouts.count
        )
    }
    
    /// Filter workouts by date range
    func filterWorkouts(_ workouts: [Workout], from startDate: Date, to endDate: Date) -> [Workout] {
        return workouts.filter { workout in
            workout.startTime >= startDate && workout.startTime <= endDate
        }
    }
    
    /// Filter workouts by activity type
    func filterWorkouts(_ workouts: [Workout], byActivityType activityType: ActivityType) -> [Workout] {
        return workouts.filter { $0.activityType == activityType }
    }
    
    /// Get workout summary for sharing
    func createWorkoutSummary(for workouts: [Workout]) -> String {
        let stats = getWorkoutStatistics(from: workouts)
        
        var summary = "🏃‍♂️ RUNSTR Workout Summary\n\n"
        summary += "📊 Total Workouts: \(stats.totalWorkouts)\n"
        summary += "📏 Total Distance: \(String(format: "%.1f", stats.totalDistance / 1000)) km\n"
        summary += "⏱️ Total Time: \(formatDuration(stats.totalDuration))\n"
        
        if stats.totalCalories > 0 {
            summary += "🔥 Total Calories: \(Int(stats.totalCalories)) kcal\n"
        }
        
        if stats.totalElevationGain > 0 {
            summary += "🏔️ Total Elevation: \(Int(stats.totalElevationGain)) m\n"
        }
        
        summary += "\n📈 Breakdown:\n"
        if stats.runningCount > 0 {
            summary += "🏃‍♂️ Running: \(stats.runningCount) workouts\n"
        }
        if stats.cyclingCount > 0 {
            summary += "🚴‍♂️ Cycling: \(stats.cyclingCount) workouts\n"
        }
        if stats.walkingCount > 0 {
            summary += "🚶‍♂️ Walking: \(stats.walkingCount) workouts\n"
        }
        
        summary += "\n#RUNSTR #Fitness #Nostr"
        
        return summary
    }
    
    // MARK: - Private Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Types

struct WorkoutStatistics {
    let totalWorkouts: Int
    let totalDistance: Double
    let totalDuration: TimeInterval
    let totalCalories: Double
    let totalElevationGain: Double
    let averageDistance: Double
    let averageDuration: TimeInterval
    let runningCount: Int
    let cyclingCount: Int
    let walkingCount: Int
    
    init() {
        self.totalWorkouts = 0
        self.totalDistance = 0
        self.totalDuration = 0
        self.totalCalories = 0
        self.totalElevationGain = 0
        self.averageDistance = 0
        self.averageDuration = 0
        self.runningCount = 0
        self.cyclingCount = 0
        self.walkingCount = 0
    }
    
    init(totalWorkouts: Int, totalDistance: Double, totalDuration: TimeInterval, totalCalories: Double, totalElevationGain: Double, averageDistance: Double, averageDuration: TimeInterval, runningCount: Int, cyclingCount: Int, walkingCount: Int) {
        self.totalWorkouts = totalWorkouts
        self.totalDistance = totalDistance
        self.totalDuration = totalDuration
        self.totalCalories = totalCalories
        self.totalElevationGain = totalElevationGain
        self.averageDistance = averageDistance
        self.averageDuration = averageDuration
        self.runningCount = runningCount
        self.cyclingCount = cyclingCount
        self.walkingCount = walkingCount
    }
}