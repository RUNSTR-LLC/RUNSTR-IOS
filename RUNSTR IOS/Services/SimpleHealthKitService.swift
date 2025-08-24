import Foundation
import HealthKit
import Combine

/// Ultra-simple HealthKit service that lets iOS do all the heavy lifting
@MainActor
class SimpleHealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var workouts: [HKWorkout] = []
    @Published var isWorkoutActive: Bool = false
    @Published var currentDistance: Double = 0.0 // meters
    @Published var currentDuration: TimeInterval = 0.0 // seconds
    
    // For basic workout tracking
    private var workoutStartTime: Date?
    private var workoutTimer: Timer?
    
    // Simple permissions - only what we need
    private let readTypes: Set<HKObjectType> = [
        HKWorkoutType.workoutType(),
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
    ]
    
    private let writeTypes: Set<HKSampleType> = [
        HKWorkoutType.workoutType()
    ]
    
    init() {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available on this device")
            return
        }
    }
    
    // MARK: - Permission Management
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available")
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            
            // Check authorization status
            let workoutAuth = healthStore.authorizationStatus(for: HKWorkoutType.workoutType())
            isAuthorized = workoutAuth == .sharingAuthorized
            
            print("✅ HealthKit authorization: \(workoutAuth)")
            return isAuthorized
            
        } catch {
            print("❌ HealthKit authorization failed: \(error.localizedDescription)")
            isAuthorized = false
            return false
        }
    }
    
    // MARK: - Reading Existing Workouts (Most Important Feature)
    
    /// Loads all existing workouts from HealthKit (from ALL fitness apps)
    func loadAllWorkouts() async {
        guard isAuthorized else {
            print("❌ HealthKit not authorized - cannot load workouts")
            return
        }
        
        let workoutType = HKWorkoutType.workoutType()
        
        // Create query for all workouts, sorted by date
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: nil, // Get ALL workouts from ALL apps
            limit: 100, // Reasonable limit
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            
            if let error = error {
                print("❌ Failed to load workouts: \(error.localizedDescription)")
                return
            }
            
            guard let workouts = samples as? [HKWorkout] else {
                print("❌ Invalid workout data")
                return
            }
            
            Task { @MainActor in
                self.workouts = workouts
                print("✅ Loaded \(workouts.count) workouts from HealthKit")
                
                // Log some stats
                let runningWorkouts = workouts.filter { $0.workoutActivityType == .running }
                let walkingWorkouts = workouts.filter { $0.workoutActivityType == .walking }
                let cyclingWorkouts = workouts.filter { $0.workoutActivityType == .cycling }
                
                print("   - Running: \(runningWorkouts.count)")
                print("   - Walking: \(walkingWorkouts.count)")
                print("   - Cycling: \(cyclingWorkouts.count)")
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Creating New Workouts (Optional Feature)
    
    /// Start a new workout session - For iOS, we'll use a simple approach
    func startWorkout(activityType: HKWorkoutActivityType) async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit not authorized")
            return false
        }
        
        // Start basic workout tracking
        isWorkoutActive = true
        workoutStartTime = Date()
        currentDistance = 0.0
        currentDuration = 0.0
        
        // Start a timer to update duration
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if let startTime = self.workoutStartTime {
                    self.currentDuration = Date().timeIntervalSince(startTime)
                }
            }
        }
        
        // Start distance simulation for demo
        startDistanceSimulation()
        
        print("✅ Started \(activityType.name) workout tracking with timer and distance simulation")
        return true
    }
    
    /// End the current workout session
    func endWorkout() async -> HKWorkout? {
        guard isWorkoutActive else {
            print("❌ No active workout session")
            return nil
        }
        
        // Stop the timer
        workoutTimer?.invalidate()
        workoutTimer = nil
        
        isWorkoutActive = false
        
        // Create a basic workout record for demonstration
        if let startTime = workoutStartTime, currentDuration > 0 {
            print("✅ Workout ended - Duration: \(Int(currentDuration))s, Distance: \(Int(currentDistance))m")
            
            // In a full implementation, this would save to HealthKit
            // For now, we'll create a mock workout to demonstrate the flow
            do {
                let workout = HKWorkout(
                    activityType: .running, // Default for demo
                    start: startTime,
                    end: Date(),
                    duration: currentDuration,
                    totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: currentDuration / 60 * 10), // Rough estimate
                    totalDistance: HKQuantity(unit: .meter(), doubleValue: currentDistance),
                    metadata: nil
                )
                
                // Note: We're not actually saving to HealthKit here - just creating the object
                print("📝 Would save workout: \(Int(currentDistance))m in \(Int(currentDuration))s")
                
            } catch {
                print("❌ Error creating workout: \(error)")
            }
        }
        
        // Reset workout state
        workoutStartTime = nil
        currentDistance = 0.0
        currentDuration = 0.0
        
        // Reload existing workouts
        await loadAllWorkouts()
        
        // Return the most recent workout
        return workouts.first
    }
    
    /// Update distance during workout (would be called by GPS/LocationService)
    func updateDistance(_ newDistance: Double) {
        guard isWorkoutActive else { return }
        currentDistance = newDistance
    }
    
    /// Simulate distance tracking for demo (increments distance automatically)
    func startDistanceSimulation() {
        guard isWorkoutActive else { return }
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            Task { @MainActor in
                if self.isWorkoutActive {
                    // Simulate walking/running speed: ~3-4 meters every 5 seconds
                    self.currentDistance += Double.random(in: 3.0...6.0)
                } else {
                    timer.invalidate()
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get workouts for a specific activity type
    func getWorkouts(for activityType: HKWorkoutActivityType) -> [HKWorkout] {
        return workouts.filter { $0.workoutActivityType == activityType }
    }
    
    /// Get workouts from the last 7 days
    func getRecentWorkouts() -> [HKWorkout] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workouts.filter { $0.startDate >= sevenDaysAgo }
    }
}

// MARK: - HKWorkoutActivityType Extensions

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking" 
        case .cycling: return "Cycling"
        case .hiking: return "Hiking"
        default: return "Workout"
        }
    }
    
    var emoji: String {
        switch self {
        case .running: return "🏃‍♂️"
        case .walking: return "🚶‍♂️"
        case .cycling: return "🚴‍♂️"
        case .hiking: return "🥾"
        default: return "🏋️‍♂️"
        }
    }
}

// MARK: - HKWorkout Extensions for Easy Display

extension HKWorkout {
    var distanceFormatted: String {
        guard let distance = totalDistance else { return "N/A" }
        let km = distance.doubleValue(for: .meter()) / 1000
        return String(format: "%.2f km", km)
    }
    
    var durationFormatted: String {
        let duration = self.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var caloriesFormatted: String {
        guard let calories = totalEnergyBurned else { return "N/A" }
        return String(format: "%.0f cal", calories.doubleValue(for: .kilocalorie()))
    }
    
    var paceFormatted: String {
        guard let distance = totalDistance, distance.doubleValue(for: .meter()) > 0 else { return "N/A" }
        
        let meters = distance.doubleValue(for: .meter())
        let paceSecondsPerKm = (duration / (meters / 1000))
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}