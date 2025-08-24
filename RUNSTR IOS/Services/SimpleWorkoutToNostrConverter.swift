import Foundation
import HealthKit

/// Ultra-simple converter to share HealthKit workouts to Nostr
struct SimpleWorkoutToNostrConverter {
    
    /// Convert HKWorkout to Nostr-shareable workout data
    static func convertWorkout(_ hkWorkout: HKWorkout, userID: String) -> Workout {
        
        // Convert HealthKit workout to our simple Workout model using the correct initializer
        let workout = Workout(
            activityType: hkWorkout.workoutActivityType.toActivityType(),
            startTime: hkWorkout.startDate,
            endTime: hkWorkout.endDate,
            distance: hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            calories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
            averageHeartRate: nil, // Could be fetched with additional queries if needed
            maxHeartRate: nil,
            elevationGain: nil,
            elevationLoss: nil,
            steps: nil,
            locations: [], // Could be fetched with HKWorkoutRoute queries if needed
            source: .local, // Since this came from HealthKit
            nostrEventID: nil,
            nostrPubkey: nil,
            nostrRelaySource: nil
        )
        
        return workout
    }
    
    /// Create a simple Nostr-shareable summary of a workout
    static func createNostrWorkoutSummary(_ hkWorkout: HKWorkout, userID: String) -> String {
        let activity = hkWorkout.workoutActivityType.emoji
        let distance = hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0
        let distanceKm = distance / 1000
        let duration = hkWorkout.duration
        let pace = calculatePace(distance: distance, duration: duration)
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let durationText = String(format: "%d:%02d", minutes, seconds)
        
        let paceMinutes = Int(pace) / 60
        let paceSeconds = Int(pace) % 60
        let paceText = String(format: "%d:%02d", paceMinutes, paceSeconds)
        
        var summary = """
        \(activity) \(hkWorkout.workoutActivityType.name) completed!
        
        📏 Distance: \(String(format: "%.2f", distanceKm)) km
        ⏱️ Duration: \(durationText)
        🏃‍♂️ Pace: \(paceText) /km
        """
        
        // Add calories if available
        if let calories = hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
            summary += "\n🔥 Calories: \(Int(calories))"
        }
        
        // Add source app info
        let sourceName = hkWorkout.sourceRevision.source.name
        summary += "\n\nTracked with \(sourceName) 📱"
        
        summary += "\n\n#fitness #\(hkWorkout.workoutActivityType.name.lowercased()) #runstr"
        
        return summary
    }
    
    /// Calculate pace in seconds per kilometer
    private static func calculatePace(distance: Double, duration: TimeInterval) -> Double {
        guard distance > 0 else { return 0 }
        let km = distance / 1000
        return duration / km // seconds per km
    }
}

// MARK: - HealthKit Extensions

extension HKWorkoutActivityType {
    func toActivityType() -> ActivityType {
        switch self {
        case .running:
            return .running
        case .walking:
            return .walking
        case .cycling:
            return .cycling
        default:
            return .running // Default fallback
        }
    }
}