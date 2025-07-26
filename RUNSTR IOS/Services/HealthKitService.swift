import Foundation
import HealthKit
import CoreLocation

class HealthKitService: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var currentHeartRate: Double?
    
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKQuantityType.quantityType(forIdentifier: .stepCount)!,
        HKWorkoutType.workoutType()
    ]
    
    private let typesToWrite: Set<HKSampleType> = [
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKWorkoutType.workoutType()
    ]
    
    override init() {
        super.init()
        // Don't request authorization immediately to avoid blocking app startup
        // requestAuthorization()
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if let error = error {
                    print("HealthKit authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func startWorkoutSession(activityType: ActivityType) -> Bool {
        guard isAuthorized else { return false }
        
        // For iOS, we'll use HealthKit integration without workout sessions
        // which are primarily for watchOS
        startHeartRateQuery()
        return true
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
    
    func startHeartRateQuery() {
        guard isAuthorized else { return }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            guard let heartRateSamples = samples as? [HKQuantitySample],
                  let mostRecentSample = heartRateSamples.last else { return }
            
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let heartRate = mostRecentSample.quantity.doubleValue(for: heartRateUnit)
            
            DispatchQueue.main.async {
                self?.currentHeartRate = heartRate
            }
        }
        
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            guard let heartRateSamples = samples as? [HKQuantitySample],
                  let mostRecentSample = heartRateSamples.last else { return }
            
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let heartRate = mostRecentSample.quantity.doubleValue(for: heartRateUnit)
            
            DispatchQueue.main.async {
                self?.currentHeartRate = heartRate
            }
        }
        
        healthStore.execute(query)
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

extension HealthKitService: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            startHeartRateQuery()
        case .ended:
            break
        default:
            break
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

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