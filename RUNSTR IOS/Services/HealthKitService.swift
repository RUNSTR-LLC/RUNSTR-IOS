import Foundation
import HealthKit
import CoreLocation
import Combine

class HealthKitService: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var currentHeartRate: Double?
    @Published var currentCalories: Double = 0
    @Published var currentSteps: Int = 0
    @Published var isWorkoutActive = false
    
    // For iOS implementation, we don't use HKWorkoutSession
    // private var workoutSession: HKWorkoutSession? // watchOS only
    // private var workoutBuilder: HKWorkoutBuilder? // not needed for basic implementation
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var calorieQuery: HKAnchoredObjectQuery?
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
            
            // Check individual authorization status
            let heartRateAuth = healthStore.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)
            let workoutAuth = healthStore.authorizationStatus(for: HKWorkoutType.workoutType())
            
            DispatchQueue.main.async {
                self.authorizationStatus = heartRateAuth
                self.isAuthorized = heartRateAuth != .notDetermined && workoutAuth != .notDetermined
            }
            
            print("✅ HealthKit authorization completed - Heart Rate: \(heartRateAuth.rawValue), Workouts: \(workoutAuth.rawValue)")
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
        
        // For iOS, we'll implement a simpler approach without HKWorkoutSession
        // which is primarily designed for watchOS
        
        // Start real-time data collection
        startRealTimeQueries()
        
        DispatchQueue.main.async {
            self.isWorkoutActive = true
            self.currentCalories = 0
        }
        
        print("✅ Started HealthKit data collection for \(activityType.displayName)")
        return true
    }
    
    func endWorkoutSession() async -> HKWorkout? {
        // Stop real-time queries
        stopRealTimeQueries()
        
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
        
        // Create a workout builder for iOS 17+
        let workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, 
                                            configuration: HKWorkoutConfiguration(), 
                                            device: .local())
        
        // For now, we'll create a simple workout record
        // In production, you'd use the workout builder pattern
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
            if let error = error {
                print("Failed to save workout to HealthKit: \(error.localizedDescription)")
            }
            completion(success)
        }
    }
    
    private func startRealTimeQueries() {
        startHeartRateQuery()
        startCalorieQuery()
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
    }
    
    private func startHeartRateQuery() {
        guard isAuthorized else { return }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-60), 
                                                   end: nil, 
                                                   options: .strictStartDate)
        
        heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }
        
        heartRateQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }
        
        if let query = heartRateQuery {
            healthStore.execute(query)
        }
    }
    
    private func startCalorieQuery() {
        guard isAuthorized else { return }
        
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-60),
                                                   end: nil,
                                                   options: .strictStartDate)
        
        calorieQuery = HKAnchoredObjectQuery(
            type: calorieType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processCalorieSamples(samples)
        }
        
        calorieQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processCalorieSamples(samples)
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
            self.currentCalories += totalCalories
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

// MARK: - iOS HealthKit Implementation
// For iOS, we use a simplified approach with manual data collection
// rather than HKWorkoutSession which is primarily designed for watchOS

// MARK: - Data Collection
// For iOS, we handle data collection through manual queries rather than
// the live workout builder delegate pattern which is primarily for watchOS

extension ActivityType {
    var hkWorkoutActivityType: HKWorkoutActivityType {
        switch self {
        case .running:
            return .running
        case .walking:
            return .walking
        case .cycling:
            return .cycling
        }
    }
}