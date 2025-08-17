import Foundation
import Combine

/// Service responsible for local workout data persistence
@MainActor
class WorkoutStorage: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var isLoading = false
    
    private let userDefaults = UserDefaults.standard
    private let workoutsKey = "stored_workouts"
    
    init() {
        // Don't load workouts during init to avoid blocking app startup
        // Workouts will be loaded when the dashboard is accessed
    }
    
    // MARK: - Public Methods
    
    /// Ensure workouts are loaded from storage
    func ensureWorkoutsLoaded() {
        if !workouts.isEmpty || isLoading {
            return // Already loaded or currently loading
        }
        loadWorkouts()
    }
    
    /// Save a workout to local storage
    func saveWorkout(_ workout: Workout) {
        ensureWorkoutsLoaded() // Make sure workouts are loaded first
        
        // Check for duplicates based on start time and distance (within tolerance)
        let isDuplicate = workouts.contains { existingWorkout in
            let timeDifference = abs(existingWorkout.startTime.timeIntervalSince(workout.startTime))
            let distanceDifference = abs(existingWorkout.distance - workout.distance)
            
            // Consider duplicate if within 1 minute and 10 meters difference
            return timeDifference < 60 && distanceDifference < 10
        }
        
        if !isDuplicate {
            workouts.append(workout)
            persistWorkouts()
            print("✅ Workout saved locally: \(workout.distanceFormatted), \(workout.durationFormatted)")
            
            // Post notification for profile updates
            NotificationCenter.default.post(name: .workoutCompleted, object: workout)
        } else {
            print("⚠️ Duplicate workout detected, not saving: \(workout.distanceFormatted), \(workout.durationFormatted)")
        }
    }
    
    
    /// Get workouts for a specific activity type
    func getWorkouts(for activityType: ActivityType) -> [Workout] {
        ensureWorkoutsLoaded()
        return workouts.filter { $0.activityType == activityType }
    }
    
    /// Get recent workouts (last 30 days)
    func getRecentWorkouts(limit: Int = 20) -> [Workout] {
        ensureWorkoutsLoaded()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return workouts
            .filter { $0.startTime >= thirtyDaysAgo }
            .sorted { $0.startTime > $1.startTime }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Get all workouts
    func getAllWorkouts() -> [Workout] {
        ensureWorkoutsLoaded()
        return workouts.sorted { $0.startTime > $1.startTime }
    }
    
    /// Get workout by ID
    func getWorkout(id: String) -> Workout? {
        ensureWorkoutsLoaded()
        return workouts.first { $0.id == id }
    }
    
    /// Delete a workout
    func deleteWorkout(id: String) {
        workouts.removeAll { $0.id == id }
        persistWorkouts()
    }
    
    /// Get total stats for all workouts
    func getTotalStats() -> WorkoutTotalStats {
        ensureWorkoutsLoaded()
        let totalDistance = workouts.reduce(0.0) { $0 + $1.distance }
        let totalDuration = workouts.reduce(0.0) { $0 + $1.duration }
        let totalCalories = workouts.compactMap { $0.calories }.reduce(0.0, +)
        let totalRewards = 0 // Rewards removed in simplification
        
        return WorkoutTotalStats(
            totalWorkouts: workouts.count,
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            totalCalories: totalCalories,
            totalRewards: totalRewards,
            averagePace: calculateAveragePace()
        )
    }
    
    /// Get personal records
    func getPersonalRecords() -> [ActivityType: WorkoutPersonalRecords] {
        ensureWorkoutsLoaded()
        var records: [ActivityType: WorkoutPersonalRecords] = [:]
        
        for activityType in ActivityType.allCases {
            let typeWorkouts = workouts.filter { $0.activityType == activityType }
            guard !typeWorkouts.isEmpty else { continue }
            
            records[activityType] = WorkoutPersonalRecords(
                longestDistance: typeWorkouts.max { $0.distance < $1.distance },
                longestDuration: typeWorkouts.max { $0.duration < $1.duration },
                fastestPace: typeWorkouts.min { $0.averagePace < $1.averagePace },
                mostCalories: typeWorkouts.max { ($0.calories ?? 0) < ($1.calories ?? 0) },
                highestReward: nil
            )
        }
        
        return records
    }
    
    /// Clear all workouts (for testing or reset)
    func clearAllWorkouts() {
        workouts.removeAll()
        persistWorkouts()
    }
    
    // MARK: - Private Methods
    
    private func loadWorkouts() {
        isLoading = true
        
        guard let data = userDefaults.data(forKey: workoutsKey) else {
            isLoading = false
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            workouts = try decoder.decode([Workout].self, from: data)
            print("✅ Loaded \(workouts.count) workouts from local storage")
        } catch {
            print("❌ Failed to load workouts: \(error)")
            workouts = []
        }
        
        isLoading = false
    }
    
    private func persistWorkouts() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(workouts)
            userDefaults.set(data, forKey: workoutsKey)
            print("✅ Persisted \(workouts.count) workouts to storage")
        } catch {
            print("❌ Failed to persist workouts: \(error)")
        }
    }
    
    private func calculateAveragePace() -> Double {
        let validPaces = workouts.compactMap { workout -> Double? in
            guard workout.averagePace > 0 else { return nil }
            return workout.averagePace
        }
        
        guard !validPaces.isEmpty else { return 0.0 }
        return validPaces.reduce(0, +) / Double(validPaces.count)
    }
}

// MARK: - Supporting Data Structures

struct WorkoutTotalStats {
    let totalWorkouts: Int
    let totalDistance: Double // meters
    let totalDuration: TimeInterval // seconds
    let totalCalories: Double
    let totalRewards: Int // sats
    let averagePace: Double // min/km
    
    var formattedDistance: String {
        return String(format: "%.1f km", totalDistance / 1000)
    }
    
    /// Get formatted distance using unit preferences
    @MainActor
    func formattedDistance(unitService: UnitPreferencesService) -> String {
        return unitService.formatDistance(totalDistance, precision: 1)
    }
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    var formattedPace: String {
        guard averagePace > 0 else { return "--:--" }
        let minutes = Int(averagePace)
        let seconds = Int((averagePace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

struct WorkoutPersonalRecords {
    let longestDistance: Workout?
    let longestDuration: Workout?
    let fastestPace: Workout?
    let mostCalories: Workout?
    let highestReward: Workout?
}

