import Foundation
import HealthKit
import CoreLocation
import Combine

@MainActor
class HealthKitService: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var currentHeartRate: Double?
    @Published var currentCalories: Double = 0
    @Published var currentDistance: Double = 0  // Distance from HealthKit in meters
    @Published var currentSteps: Int = 0
    @Published var isWorkoutActive = false
    
    // Individual permission tracking
    @Published var canReadSteps = false
    @Published var canReadHeartRate = false
    @Published var canReadCalories = false
    @Published var canWriteWorkouts = false
    
    // Track workout session timing
    private var workoutStartTime: Date?
    
    // For iOS implementation, we don't use HKWorkoutSession
    // private var workoutSession: HKWorkoutSession? // watchOS only
    // private var workoutBuilder: HKWorkoutBuilder? // not needed for basic implementation
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var calorieQuery: HKAnchoredObjectQuery?
    private var distanceQuery: HKStatisticsQuery?
    private var stepsQuery: HKStatisticsQuery?
    private var cancellables = Set<AnyCancellable>()
    
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
        HKQuantityType.quantityType(forIdentifier: .stepCount)!,
        HKQuantityType.quantityType(forIdentifier: .vo2Max)!,
        HKSeriesType.workoutRoute(),
        HKWorkoutType.workoutType()
    ]
    
    private let typesToWrite: Set<HKSampleType> = [
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
        HKSeriesType.workoutRoute(),
        HKWorkoutType.workoutType()
    ]
    
    override init() {
        super.init()
        // Don't request authorization immediately to avoid blocking app startup
        // requestAuthorization()
    }
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device")
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            
            // Check individual authorization status (KEEP ORIGINAL LOGIC)
            let heartRateAuth = healthStore.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)
            let workoutAuth = healthStore.authorizationStatus(for: HKWorkoutType.workoutType())
            let stepAuth = healthStore.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .stepCount)!)
            
            DispatchQueue.main.async {
                self.authorizationStatus = heartRateAuth
                // REVERT: Use original working logic
                self.isAuthorized = heartRateAuth != .notDetermined && workoutAuth != .notDetermined
                
                // Add step tracking for debugging only
                self.canReadSteps = stepAuth == .sharingAuthorized
            }
            
            print("✅ HealthKit authorization completed - Heart Rate: \(heartRateAuth.rawValue), Workouts: \(workoutAuth.rawValue), Steps: \(stepAuth.rawValue)")
            return isAuthorized
            
        } catch {
            print("❌ HealthKit authorization failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
            return false
        }
    }
    
    func startWorkoutSession(activityType: ActivityType) async -> Bool {
        guard isAuthorized else { 
            print("❌ HealthKit not authorized for workout session")
            return false 
        }
        
        // Set workout start time for queries
        workoutStartTime = Date()
        
        // Start real-time data collection
        startRealTimeQueries()
        
        DispatchQueue.main.async {
            self.isWorkoutActive = true
            self.currentCalories = 0
            self.currentHeartRate = nil
        }
        
        print("✅ Started HealthKit data collection for \(activityType.displayName) at \(workoutStartTime!)")
        return true
    }
    
    func endWorkoutSession() async -> HKWorkout? {
        // Stop real-time queries
        stopRealTimeQueries()
        
        // Clear workout timing
        workoutStartTime = nil
        
        // For iOS, we'll create and save a basic workout manually
        // This is a simplified approach suitable for iPhone apps
        
        DispatchQueue.main.async {
            self.isWorkoutActive = false
            self.currentHeartRate = nil
        }
        
        print("✅ Ended HealthKit data collection")
        return nil // Return nil for now - the workout will be saved by the WorkoutSession
    }
    
    func saveWorkout(_ workout: Workout, completion: @escaping (Bool) -> Void) {
        guard isAuthorized else {
            completion(false)
            return
        }
        
        // Use HKWorkoutBuilder for iOS 17+
        if #available(iOS 17.0, *) {
            Task {
                do {
                    let configuration = HKWorkoutConfiguration()
                    configuration.activityType = workout.activityType.hkWorkoutActivityType
                    
                    let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
                    
                    // Begin the workout
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        builder.beginCollection(withStart: workout.startTime) { success, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                    
                    // Add samples if available using withCheckedThrowingContinuation
                    if let calories = workout.calories {
                        let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
                        let calorieSample = HKQuantitySample(type: HKQuantityType(.activeEnergyBurned), 
                                                           quantity: calorieQuantity, 
                                                           start: workout.startTime, 
                                                           end: workout.endTime)
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            builder.add([calorieSample]) { success, error in
                                if let error = error {
                                    continuation.resume(throwing: error)
                                } else {
                                    continuation.resume()
                                }
                            }
                        }
                    }
                    
                    let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: workout.distance)
                    let distanceSample = HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning), 
                                                        quantity: distanceQuantity, 
                                                        start: workout.startTime, 
                                                        end: workout.endTime)
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        builder.add([distanceSample]) { success, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                    
                    // End collection and create workout
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        builder.endCollection(withEnd: workout.endTime) { success, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                    
                    let _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout?, Error>) in
                        builder.finishWorkout { workout, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: workout)
                            }
                        }
                    }
                    
                    completion(true)
                } catch {
                    print("Failed to save workout with HKWorkoutBuilder: \(error.localizedDescription)")
                    completion(false)
                }
            }
        } else {
            // Fallback for iOS 16 and below
            let hkWorkout = HKWorkout(
                activityType: workout.activityType.hkWorkoutActivityType,
                start: workout.startTime,
                end: workout.endTime,
                workoutEvents: nil,
                totalEnergyBurned: workout.calories.map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) },
                totalDistance: HKQuantity(unit: .meter(), doubleValue: workout.distance),
                totalSwimmingStrokeCount: nil,
                device: .local(),
                metadata: [
                    HKMetadataKeyExternalUUID: workout.id
                ]
            )
            
            healthStore.save(hkWorkout) { success, error in
                completion(success && error == nil)
            }
        }
    }
    
    private func startRealTimeQueries() {
        startHeartRateQuery()
        startCalorieQuery()
        startDistanceQuery()
        startStepsQuery()
    }
    
    private func stopRealTimeQueries() {
        if let heartRateQuery = heartRateQuery {
            healthStore.stop(heartRateQuery)
            self.heartRateQuery = nil
        }
        
        if let calorieQuery = calorieQuery {
            healthStore.stop(calorieQuery)
            self.calorieQuery = nil
        }
        
        if let distanceQuery = distanceQuery {
            healthStore.stop(distanceQuery)
            self.distanceQuery = nil
        }
        
        if let stepsQuery = stepsQuery {
            healthStore.stop(stepsQuery)
            self.stepsQuery = nil
        }
    }
    
    private func startHeartRateQuery() {
        guard isAuthorized, let startTime = workoutStartTime else { return }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startTime, 
                                                   end: nil, 
                                                   options: .strictStartDate)
        
        heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processHeartRateSamples(samples)
            }
        }
        
        heartRateQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processHeartRateSamples(samples)
            }
        }
        
        if let query = heartRateQuery {
            healthStore.execute(query)
        }
    }
    
    private func startCalorieQuery() {
        guard isAuthorized, let startTime = workoutStartTime else { return }
        
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = HKQuery.predicateForSamples(withStart: startTime,
                                                   end: nil,
                                                   options: .strictStartDate)
        
        calorieQuery = HKAnchoredObjectQuery(
            type: calorieType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processCalorieSamples(samples)
            }
        }
        
        calorieQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processCalorieSamples(samples)
            }
        }
        
        if let query = calorieQuery {
            healthStore.execute(query)
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample],
              let mostRecentSample = heartRateSamples.last else { return }
        
        let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let heartRate = mostRecentSample.quantity.doubleValue(for: heartRateUnit)
        
        DispatchQueue.main.async {
            self.currentHeartRate = heartRate
        }
    }
    
    private func processCalorieSamples(_ samples: [HKSample]?) {
        guard let calorieSamples = samples as? [HKQuantitySample] else { return }
        
        let calorieUnit = HKUnit.kilocalorie()
        let totalCalories = calorieSamples.reduce(0.0) { total, sample in
            return total + sample.quantity.doubleValue(for: calorieUnit)
        }
        
        DispatchQueue.main.async {
            // Set total calories (don't add, since this query gets all samples since start)
            self.currentCalories = totalCalories
        }
    }
    
    private func startDistanceQuery() {
        guard isAuthorized, let startTime = workoutStartTime else { return }
        
        // Use appropriate distance type based on activity
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let predicate = HKQuery.predicateForSamples(withStart: startTime,
                                                   end: Date(),
                                                   options: .strictStartDate)
        
        // Use HKStatisticsQuery to get cumulative sum directly from HealthKit
        distanceQuery = HKStatisticsQuery(
            quantityType: distanceType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ HealthKit distance query error: \(error.localizedDescription)")
                return
            }
            
            // Get the cumulative sum from HealthKit
            if let sumQuantity = statistics?.sumQuantity() {
                let totalDistance = sumQuantity.doubleValue(for: HKUnit.meter())
                
                DispatchQueue.main.async {
                    self.currentDistance = totalDistance
                    print("📊 HealthKit Distance: \(String(format: "%.0f", totalDistance))m")
                }
            }
        }
        
        if let query = distanceQuery {
            healthStore.execute(query)
            
            // Set up a timer to refresh the query periodically
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.refreshDistanceQuery()
            }
        }
    }
    
    private func refreshDistanceQuery() {
        guard isAuthorized, let startTime = workoutStartTime else { return }
        
        // Stop the old query
        if let oldQuery = distanceQuery {
            healthStore.stop(oldQuery)
        }
        
        // Create new query with updated end time
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let predicate = HKQuery.predicateForSamples(withStart: startTime,
                                                   end: Date(),
                                                   options: .strictStartDate)
        
        distanceQuery = HKStatisticsQuery(
            quantityType: distanceType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ HealthKit distance refresh error: \(error.localizedDescription)")
                return
            }
            
            if let sumQuantity = statistics?.sumQuantity() {
                let totalDistance = sumQuantity.doubleValue(for: HKUnit.meter())
                
                DispatchQueue.main.async {
                    self.currentDistance = totalDistance
                }
            }
        }
        
        if let query = distanceQuery {
            healthStore.execute(query)
        }
    }
    
    private func startStepsQuery() {
        guard isAuthorized, let startTime = workoutStartTime else { return }
        
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: startTime,
                                                   end: Date(),
                                                   options: .strictStartDate)
        
        // Use HKStatisticsQuery for steps as well
        stepsQuery = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ HealthKit steps query error: \(error.localizedDescription)")
                return
            }
            
            if let sumQuantity = statistics?.sumQuantity() {
                let totalSteps = sumQuantity.doubleValue(for: HKUnit.count())
                
                DispatchQueue.main.async {
                    self.currentSteps = Int(totalSteps)
                    print("👟 HealthKit Steps: \(Int(totalSteps))")
                }
            }
        }
        
        if let query = stepsQuery {
            healthStore.execute(query)
            
            // Refresh steps periodically
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.refreshStepsQuery()
            }
        }
    }
    
    private func refreshStepsQuery() {
        guard isAuthorized, let startTime = workoutStartTime else { return }
        
        // Stop the old query
        if let oldQuery = stepsQuery {
            healthStore.stop(oldQuery)
        }
        
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: startTime,
                                                   end: Date(),
                                                   options: .strictStartDate)
        
        stepsQuery = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ HealthKit steps refresh error: \(error.localizedDescription)")
                return
            }
            
            if let sumQuantity = statistics?.sumQuantity() {
                let totalSteps = sumQuantity.doubleValue(for: HKUnit.count())
                
                DispatchQueue.main.async {
                    self.currentSteps = Int(totalSteps)
                }
            }
        }
        
        if let query = stepsQuery {
            healthStore.execute(query)
        }
    }
    
    func fetchRecentWorkouts(completion: @escaping ([HKWorkout]) -> Void) {
        guard isAuthorized else {
            completion([])
            return
        }
        
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: nil,
            limit: 50,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            let workouts = samples as? [HKWorkout] ?? []
            DispatchQueue.main.async {
                completion(workouts)
            }
        }
        
        healthStore.execute(query)
    }
}
