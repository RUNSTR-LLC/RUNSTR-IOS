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
    
    // MARK: - Enhanced Stats Methods
    
    func fetchStatsForTimeframe(_ timeframe: TimeFrame) async -> HealthKitStats {
        guard isAuthorized else {
            return HealthKitStats.empty
        }
        
        let dateRange = timeframe.dateRange
        let workouts = await fetchWorkoutsInDateRange(dateRange)
        
        // Calculate aggregated stats
        let totalDistance = workouts.compactMap { $0.totalDistance?.doubleValue(for: .meter()) }.reduce(0, +)
        let totalWorkouts = workouts.count
        let totalCalories = workouts.compactMap { $0.totalEnergyBurned?.doubleValue(for: .kilocalorie()) }.reduce(0, +)
        let totalActiveTime = workouts.reduce(0) { $0 + $1.duration }
        
        // Calculate average pace
        let validPaces = workouts.compactMap { workout -> Double? in
            guard let distance = workout.totalDistance?.doubleValue(for: .meter()),
                  distance > 0 else { return nil }
            return (workout.duration / 60) / (distance / 1000) // min/km
        }
        let averagePace = validPaces.isEmpty ? 0 : validPaces.reduce(0, +) / Double(validPaces.count)
        
        // Generate timeframe data for different periods
        let timeframeData = await generateTimeframeData(workouts: workouts, timeframe: timeframe)
        
        // Generate chart data for different metrics
        let chartData = await generateChartData(workouts: workouts, timeframe: timeframe)
        
        return HealthKitStats(
            totalDistance: totalDistance,
            totalWorkouts: totalWorkouts,
            averagePace: averagePace,
            totalCalories: totalCalories,
            totalActiveTime: totalActiveTime,
            timeframeData: timeframeData,
            chartData: chartData
        )
    }
    
    func fetchPersonalRecords() async -> [ActivityType: [PersonalRecord]] {
        guard isAuthorized else {
            return [:]
        }
        
        var records: [ActivityType: [PersonalRecord]] = [:]
        
        for activityType in ActivityType.allCases {
            let workouts = await fetchWorkoutsForActivityType(activityType)
            records[activityType] = calculatePersonalRecords(for: workouts, activityType: activityType)
        }
        
        return records
    }
    
    func fetchChartData(for metric: StatsMetric, timeframe: TimeFrame) async -> [ChartDataPoint] {
        guard isAuthorized else {
            return []
        }
        
        let dateRange = timeframe.dateRange
        let workouts = await fetchWorkoutsInDateRange(dateRange)
        
        return generateChartDataPoints(workouts: workouts, metric: metric, timeframe: timeframe)
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchWorkoutsInDateRange(_ dateRange: DateInterval) async -> [HKWorkout] {
        return await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let predicate = HKQuery.predicateForSamples(withStart: dateRange.start, end: dateRange.end, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchWorkoutsForActivityType(_ activityType: ActivityType) async -> [HKWorkout] {
        return await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let activityPredicate = HKQuery.predicateForWorkouts(with: activityType.hkWorkoutActivityType)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: activityPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func generateTimeframeData(workouts: [HKWorkout], timeframe: TimeFrame) async -> [TimeFrame: TimeframeStats] {
        var timeframeData: [TimeFrame: TimeframeStats] = [:]
        
        // Current period stats
        let currentStats = calculateTimeframeStats(workouts: workouts)
        timeframeData[timeframe] = currentStats
        
        // Previous period for comparison (if available)
        let previousDateRange = getPreviousDateRange(for: timeframe)
        let previousWorkouts = await fetchWorkoutsInDateRange(previousDateRange)
        let previousStats = calculateTimeframeStats(workouts: previousWorkouts)
        
        // Calculate improvement percentage
        let improvement = calculateImprovement(current: currentStats, previous: previousStats)
        let currentWithImprovement = TimeframeStats(
            distance: currentStats.distance,
            workouts: currentStats.workouts,
            averagePace: currentStats.averagePace,
            calories: currentStats.calories,
            satsEarned: currentStats.satsEarned,
            activeTime: currentStats.activeTime,
            improvement: improvement
        )
        
        timeframeData[timeframe] = currentWithImprovement
        
        return timeframeData
    }
    
    private func calculateTimeframeStats(workouts: [HKWorkout]) -> TimeframeStats {
        let distance = workouts.compactMap { $0.totalDistance?.doubleValue(for: .meter()) }.reduce(0, +)
        let calories = workouts.compactMap { $0.totalEnergyBurned?.doubleValue(for: .kilocalorie()) }.reduce(0, +)
        let activeTime = workouts.reduce(0) { $0 + $1.duration }
        
        // Calculate average pace
        let validPaces = workouts.compactMap { workout -> Double? in
            guard let workoutDistance = workout.totalDistance?.doubleValue(for: .meter()),
                  workoutDistance > 0 else { return nil }
            return (workout.duration / 60) / (workoutDistance / 1000)
        }
        let averagePace = validPaces.isEmpty ? 0 : validPaces.reduce(0, +) / Double(validPaces.count)
        
        // Estimate sats earned (100 sats per km + time bonus)
        let satsEarned = Int((distance / 1000) * 100) + Int(activeTime / 60)
        
        return TimeframeStats(
            distance: distance,
            workouts: workouts.count,
            averagePace: averagePace,
            calories: calories,
            satsEarned: satsEarned,
            activeTime: activeTime,
            improvement: 0
        )
    }
    
    private func getPreviousDateRange(for timeframe: TimeFrame) -> DateInterval {
        let calendar = Calendar.current
        let currentRange = timeframe.dateRange
        
        let duration = currentRange.duration
        let previousStart = currentRange.start.addingTimeInterval(-duration)
        let previousEnd = currentRange.start
        
        return DateInterval(start: previousStart, end: previousEnd)
    }
    
    private func calculateImprovement(current: TimeframeStats, previous: TimeframeStats) -> Double {
        guard previous.distance > 0 else { return 0 }
        return ((current.distance - previous.distance) / previous.distance) * 100
    }
    
    private func generateChartData(workouts: [HKWorkout], timeframe: TimeFrame) async -> [StatsMetric: [ChartDataPoint]] {
        var chartData: [StatsMetric: [ChartDataPoint]] = [:]
        
        for metric in StatsMetric.allCases {
            chartData[metric] = generateChartDataPoints(workouts: workouts, metric: metric, timeframe: timeframe)
        }
        
        return chartData
    }
    
    private func generateChartDataPoints(workouts: [HKWorkout], metric: StatsMetric, timeframe: TimeFrame) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let dateRange = timeframe.dateRange
        let dataPoints = timeframe.chartDataPoints
        
        var chartPoints: [ChartDataPoint] = []
        
        // Group workouts by date intervals based on timeframe
        let interval: TimeInterval
        switch timeframe {
        case .week:
            interval = 86400 // 1 day
        case .month:
            interval = 86400 // 1 day  
        case .year:
            interval = 86400 * 30.4 // ~1 month
        }
        
        var currentDate = dateRange.start
        while currentDate < dateRange.end {
            let nextDate = currentDate.addingTimeInterval(interval)
            let periodicWorkouts = workouts.filter { 
                $0.startDate >= currentDate && $0.startDate < nextDate 
            }
            
            let value: Double
            switch metric {
            case .distance:
                value = periodicWorkouts.compactMap { $0.totalDistance?.doubleValue(for: .meter()) }.reduce(0, +) / 1000 // km
            case .pace:
                let paces = periodicWorkouts.compactMap { workout -> Double? in
                    guard let distance = workout.totalDistance?.doubleValue(for: .meter()),
                          distance > 0 else { return nil }
                    return (workout.duration / 60) / (distance / 1000)
                }
                value = paces.isEmpty ? 0 : paces.reduce(0, +) / Double(paces.count)
            case .frequency:
                value = Double(periodicWorkouts.count)
            case .calories:
                value = periodicWorkouts.compactMap { $0.totalEnergyBurned?.doubleValue(for: .kilocalorie()) }.reduce(0, +)
            }
            
            chartPoints.append(ChartDataPoint(
                date: currentDate,
                value: value,
                metric: metric,
                npubSource: "healthkit"
            ))
            
            currentDate = nextDate
        }
        
        return chartPoints
    }
    
    private func calculatePersonalRecords(for workouts: [HKWorkout], activityType: ActivityType) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        
        // Fastest pace
        if let fastestWorkout = workouts.min(by: { workout1, workout2 in
            guard let distance1 = workout1.totalDistance?.doubleValue(for: .meter()),
                  let distance2 = workout2.totalDistance?.doubleValue(for: .meter()),
                  distance1 > 0, distance2 > 0 else { return false }
            
            let pace1 = (workout1.duration / 60) / (distance1 / 1000)
            let pace2 = (workout2.duration / 60) / (distance2 / 1000)
            return pace1 < pace2
        }) {
            let distance = fastestWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0
            if distance > 0 {
                let pace = (fastestWorkout.duration / 60) / (distance / 1000)
                records.append(PersonalRecord(
                    activityType: activityType,
                    recordType: .fastestPace,
                    value: pace,
                    unit: "min/km",
                    achievedDate: fastestWorkout.startDate,
                    location: nil,
                    isNewRecord: isRecentRecord(fastestWorkout.startDate),
                    previousRecord: nil
                ))
            }
        }
        
        // Longest distance
        if let longestWorkout = workouts.max(by: { 
            ($0.totalDistance?.doubleValue(for: .meter()) ?? 0) < ($1.totalDistance?.doubleValue(for: .meter()) ?? 0)
        }) {
            let distance = longestWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0
            records.append(PersonalRecord(
                activityType: activityType,
                recordType: .longestDistance,
                value: distance,
                unit: "meters",
                achievedDate: longestWorkout.startDate,
                location: nil,
                isNewRecord: isRecentRecord(longestWorkout.startDate),
                previousRecord: nil
            ))
        }
        
        // Longest duration
        if let longestDurationWorkout = workouts.max(by: { $0.duration < $1.duration }) {
            records.append(PersonalRecord(
                activityType: activityType,
                recordType: .longestDuration,
                value: longestDurationWorkout.duration,
                unit: "seconds",
                achievedDate: longestDurationWorkout.startDate,
                location: nil,
                isNewRecord: isRecentRecord(longestDurationWorkout.startDate),
                previousRecord: nil
            ))
        }
        
        // Most calories
        if let mostCaloriesWorkout = workouts.max(by: {
            ($0.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0) < ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
        }) {
            let calories = mostCaloriesWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            records.append(PersonalRecord(
                activityType: activityType,
                recordType: .mostCalories,
                value: calories,
                unit: "kcal",
                achievedDate: mostCaloriesWorkout.startDate,
                location: nil,
                isNewRecord: isRecentRecord(mostCaloriesWorkout.startDate),
                previousRecord: nil
            ))
        }
        
        return records
    }
    
    private func isRecentRecord(_ date: Date) -> Bool {
        // Consider a record "new" if it's within the last 7 days
        return Date().timeIntervalSince(date) <= 7 * 24 * 60 * 60
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