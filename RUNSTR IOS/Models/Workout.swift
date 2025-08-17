import Foundation
import CoreLocation
import HealthKit
import MapKit

struct Workout: Identifiable, Codable {
    let id: String
    let userID: String
    let activityType: ActivityType
    let startTime: Date
    var endTime: Date
    var duration: TimeInterval
    var distance: Double // meters
    var averagePace: Double // minutes per kilometer
    var calories: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var steps: Int?
    var route: [CLLocationCoordinate2D]?
    var elevationGain: Double?
    var elevationLoss: Double?
    let weather: WeatherCondition?
    let nostrEventID: String? // Reference to published NIP-101e note
    var rewardAmount: Int? // Bitcoin reward in sats
    
    // Additional computed properties
    var locations: [CLLocationCoordinate2D] {
        return route ?? []
    }
    
    var splits: [WorkoutSplit] {
        // Generate splits based on distance (1km splits)
        guard distance > 1000 else { return [] }
        
        let kmDistance = distance / 1000
        let splitCount = Int(kmDistance)
        
        // Ensure splitCount is valid for range operations
        guard splitCount > 0 else { return [] }
        
        var splits: [WorkoutSplit] = []
        
        for _ in 0..<splitCount {
            splits.append(WorkoutSplit(
                distance: 1000,
                time: duration / Double(splitCount),
                pace: averagePace
            ))
        }
        return splits
    }
    
    var mapRegion: MKCoordinateRegion? {
        guard !locations.isEmpty else { return nil }
        
        let latitudes = locations.map { $0.latitude }
        let longitudes = locations.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    init(activityType: ActivityType, userID: String) {
        self.id = UUID().uuidString
        self.userID = userID
        self.activityType = activityType
        self.startTime = Date()
        self.endTime = Date()
        self.duration = 0
        self.distance = 0
        self.averagePace = 0
        self.calories = nil
        self.averageHeartRate = nil
        self.maxHeartRate = nil
        self.steps = nil
        self.route = nil
        self.elevationGain = nil
        self.elevationLoss = nil
        self.weather = nil
        self.nostrEventID = nil
        self.rewardAmount = nil
    }
    
    // Convenience initializer for previews and testing
    init(activityType: ActivityType, 
         startTime: Date, 
         endTime: Date, 
         distance: Double, 
         calories: Double? = nil, 
         averageHeartRate: Double? = nil, 
         maxHeartRate: Double? = nil,
         elevationGain: Double? = nil,
         elevationLoss: Double? = nil,
         steps: Int? = nil,
         locations: [CLLocationCoordinate2D] = []) {
        
        self.id = UUID().uuidString
        self.userID = "preview-user"
        self.activityType = activityType
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.distance = distance
        
        // Calculate average pace (min/km)
        let minutes = self.duration / 60  // Convert seconds to minutes directly
        let kmDistance = distance / 1000
        self.averagePace = kmDistance > 0 ? minutes / kmDistance : 0
        
        // Debug: Log pace calculation for verification
        print("📊 Pace Calculation Debug:")
        print("   Duration: \(self.duration) seconds (\(minutes) minutes)")
        print("   Distance: \(distance) meters (\(kmDistance) km)")
        print("   Calculated Pace: \(self.averagePace) min/km")
        
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.steps = steps
        self.route = locations.isEmpty ? nil : locations
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.weather = nil
        self.nostrEventID = nil
        self.rewardAmount = nil
    }
    
    var pace: String {
        let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
        let minutes = Int(averagePace)
        let seconds = Int((averagePace - Double(minutes)) * 60)
        let unit = useMetric ? "/km" : "/mi"
        return String(format: "%d:%02d %@", minutes, seconds, unit)
    }
    
    var distanceFormatted: String {
        let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
        if useMetric {
            return String(format: "%.2f km", distance / 1000)
        } else {
            let miles = distance * 0.000621371 // Convert meters to miles
            return String(format: "%.2f mi", miles)
        }
    }
    
    var paceInPreferredUnits: Double {
        let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
        if useMetric {
            return averagePace // Already in min/km
        } else {
            // Convert min/km to min/mile
            return averagePace * 1.60934
        }
    }
    
    var distanceInPreferredUnits: Double {
        let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
        if useMetric {
            return distance / 1000 // Convert meters to km
        } else {
            return distance * 0.000621371 // Convert meters to miles
        }
    }
    
    var preferredDistanceUnit: String {
        let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
        return useMetric ? "km" : "mi"
    }
    
    var preferredPaceUnit: String {
        let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
        return useMetric ? "min/km" : "min/mi"
    }
    
    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Unit-aware formatting methods
    
    /// Get formatted distance using unit preferences
    @MainActor
    func distanceFormatted(unitService: UnitPreferencesService) -> String {
        return unitService.formatDistance(distance)
    }
    
    /// Get formatted pace using unit preferences
    @MainActor
    func paceFormatted(unitService: UnitPreferencesService) -> String {
        return unitService.formatPace(averagePace)
    }
    
    /// Get distance value in preferred units
    @MainActor
    func distanceInPreferredUnits(unitService: UnitPreferencesService) -> Double {
        return unitService.convertDistance(distance)
    }
    
    /// Get pace value in preferred units
    @MainActor
    func paceInPreferredUnits(unitService: UnitPreferencesService) -> Double {
        return unitService.convertPace(averagePace)
    }
    
    /// Get distance unit abbreviation
    @MainActor
    func distanceUnit(unitService: UnitPreferencesService) -> String {
        return unitService.distanceUnit
    }
    
    /// Get pace unit abbreviation
    @MainActor
    func paceUnit(unitService: UnitPreferencesService) -> String {
        return unitService.paceUnit
    }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case id, userID, activityType, startTime, endTime, duration, distance, averagePace, calories
        case averageHeartRate, maxHeartRate, elevationGain, elevationLoss, weather, nostrEventID, route, steps, rewardAmount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userID = try container.decode(String.self, forKey: .userID)
        activityType = try container.decode(ActivityType.self, forKey: .activityType)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        distance = try container.decode(Double.self, forKey: .distance)
        averagePace = try container.decode(Double.self, forKey: .averagePace)
        calories = try container.decodeIfPresent(Double.self, forKey: .calories)
        averageHeartRate = try container.decodeIfPresent(Double.self, forKey: .averageHeartRate)
        maxHeartRate = try container.decodeIfPresent(Double.self, forKey: .maxHeartRate)
        steps = try container.decodeIfPresent(Int.self, forKey: .steps)
        elevationGain = try container.decodeIfPresent(Double.self, forKey: .elevationGain)
        elevationLoss = try container.decodeIfPresent(Double.self, forKey: .elevationLoss)
        weather = try container.decodeIfPresent(WeatherCondition.self, forKey: .weather)
        nostrEventID = try container.decodeIfPresent(String.self, forKey: .nostrEventID)
        rewardAmount = try container.decodeIfPresent(Int.self, forKey: .rewardAmount)
        
        // Decode route as array of coordinate dictionaries
        if let routeData = try container.decodeIfPresent([[String: Double]].self, forKey: .route) {
            route = routeData.compactMap { dict in
                guard let lat = dict["latitude"], let lon = dict["longitude"] else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        } else {
            route = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(activityType, forKey: .activityType)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(distance, forKey: .distance)
        try container.encode(averagePace, forKey: .averagePace)
        try container.encodeIfPresent(calories, forKey: .calories)
        try container.encodeIfPresent(averageHeartRate, forKey: .averageHeartRate)
        try container.encodeIfPresent(maxHeartRate, forKey: .maxHeartRate)
        try container.encodeIfPresent(steps, forKey: .steps)
        try container.encodeIfPresent(elevationGain, forKey: .elevationGain)
        try container.encodeIfPresent(elevationLoss, forKey: .elevationLoss)
        try container.encodeIfPresent(weather, forKey: .weather)
        try container.encodeIfPresent(nostrEventID, forKey: .nostrEventID)
        
        // Encode route as array of coordinate dictionaries
        if let route = route {
            let routeData = route.map { coordinate in
                ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
            }
            try container.encode(routeData, forKey: .route)
        } else {
            try container.encodeNil(forKey: .route)
        }
    }
}

struct WeatherCondition: Codable {
    let temperature: Double // Celsius
    let condition: String
    let humidity: Double
    let windSpeed: Double
}

struct WorkoutSplit: Codable {
    let distance: Double // meters
    let time: TimeInterval // seconds for this split
    let pace: Double // minutes per km
}

struct LiveWorkoutSplit: Identifiable {
    let id = UUID()
    let splitNumber: Int
    let distance: Double // meters (actual distance covered for current split)
    let time: TimeInterval // seconds for this split
    let pace: Double // minutes per km
    let isCompleted: Bool
    
    var distanceFormatted: String {
        let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
        if useMetric {
            return String(format: "%.2f km", distance / 1000)
        } else {
            let miles = distance * 0.000621371
            return String(format: "%.2f mi", miles)
        }
    }
    
    var paceFormatted: String {
        guard pace > 0 && pace.isFinite else { return "--:--" }
        
        let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
        let displayPace = useMetric ? pace : pace * 1.60934 // Convert to min/mile if needed
        
        let minutes = Int(displayPace)
        let seconds = Int((displayPace - Double(minutes)) * 60)
        let unit = useMetric ? "/km" : "/mi"
        return String(format: "%d:%02d%@", minutes, seconds, unit)
    }
    
    var timeFormatted: String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@MainActor
class WorkoutSession: ObservableObject {
    @Published var isActive: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentWorkout: Workout?
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentDistance: Double = 0
    @Published var currentPace: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var currentHeartRate: Double? = nil
    @Published var currentCalories: Double = 0
    @Published var currentSteps: Int = 0
    @Published var locations: [CLLocation] = []
    @Published var isGPSReady: Bool = false
    @Published var accuracy: Double = 0
    @Published var currentSplits: [LiveWorkoutSplit] = []
    @Published var currentSplitProgress: LiveWorkoutSplit?
    
    private var timer: Timer?
    private var startTime: Date?
    private var pauseStartTime: Date?  // Track when pause started
    private var totalPausedTime: TimeInterval = 0  // Accumulate total paused duration
    private var healthKitService: HealthKitService?
    private var locationService: LocationService?
    private var hapticService: HapticFeedbackService?
    
    // Split tracking properties
    private var lastSplitDistance: Double = 0
    private var lastSplitTime: TimeInterval = 0
    private var splitStartTime: Date?
    private var splitDistance: Double = 1000 // Default 1km splits
    
    func configure(healthKitService: HealthKitService, locationService: LocationService, hapticService: HapticFeedbackService? = nil) {
        self.healthKitService = healthKitService
        self.locationService = locationService
        self.hapticService = hapticService
    }
    
    func startWorkout(activityType: ActivityType, userID: String) async -> Bool {
        guard let healthKitService = healthKitService,
              let locationService = locationService else {
            print("❌ Services not configured")
            return false
        }
        
        // Check permissions
        guard healthKitService.isAuthorized else {
            print("❌ HealthKit not authorized")
            return false
        }
        
        guard locationService.authorizationStatus == .authorizedWhenInUse || 
              locationService.authorizationStatus == .authorizedAlways else {
            print("❌ Location not authorized")
            return false
        }
        
        // Initialize workout on main thread
        await MainActor.run {
            currentWorkout = Workout(activityType: activityType, userID: userID)
            isActive = true
            isPaused = false
            startTime = Date()
            pauseStartTime = nil
            totalPausedTime = 0
            elapsedTime = 0
            currentDistance = 0
            currentCalories = 0
            locations.removeAll()
            
            // Initialize split tracking
            currentSplits.removeAll()
            currentSplitProgress = nil
            lastSplitDistance = 0
            lastSplitTime = 0
            splitStartTime = Date()
            
            // Set split distance based on unit preference
            let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
            splitDistance = useMetric ? 1000 : 1609.34 // 1km or 1 mile
        }
        
        // Configure location service with activity type for accuracy improvements
        locationService.setActivityType(activityType)
        
        // Start services
        let healthKitStarted = await healthKitService.startWorkoutSession(activityType: activityType)
        if !healthKitStarted {
            print("❌ Failed to start HealthKit session")
            return false
        }
        
        locationService.startTracking()
        
        // Start timer for UI updates on main thread
        await MainActor.run {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in
                    self.updateWorkoutData()
                }
            }
        }
        
        print("✅ Started workout session for \(activityType.displayName)")
        return true
    }
    
    func pauseWorkout() {
        guard isActive, !isPaused else { return }
        
        Task { @MainActor in
            isPaused = true
            pauseStartTime = Date()  // Record when pause started
            timer?.invalidate()
        }
        
        // Pause location tracking
        locationService?.pauseTracking()
        
        print("⏸️ Workout paused at \(Date())")
    }
    
    func resumeWorkout() {
        guard isActive, isPaused else { return }
        
        Task { @MainActor in
            // Calculate how long we were paused
            if let pauseStart = pauseStartTime {
                let pauseDuration = Date().timeIntervalSince(pauseStart)
                totalPausedTime += pauseDuration
                print("⏸️ Was paused for \(String(format: "%.1f", pauseDuration)) seconds")
            }
            pauseStartTime = nil
            isPaused = false
            
            // Restart timer
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in
                    self.updateWorkoutData()
                }
            }
        }
        
        // Resume location tracking
        locationService?.resumeTracking()
        
        print("▶️ Workout resumed at \(Date())")
    }
    
    func endWorkout() async -> Workout? {
        guard isActive else { return nil }
        
        // Update UI state on main thread
        await MainActor.run {
            timer?.invalidate()
            isActive = false
            isPaused = false
        }
        
        // Stop location tracking
        locationService?.stopTracking()
        
        // End HealthKit session
        _ = await healthKitService?.endWorkoutSession()
        
        guard var workout = currentWorkout else { return nil }
        
        // Update workout with final data on main thread
        await MainActor.run {
            // If still paused when ending, add final pause duration
            var finalElapsedTime = elapsedTime
            if isPaused, let pauseStart = pauseStartTime {
                let finalPauseDuration = Date().timeIntervalSince(pauseStart)
                finalElapsedTime = Date().timeIntervalSince(startTime ?? Date()) - (totalPausedTime + finalPauseDuration)
            }
            workout.duration = finalElapsedTime
            workout.distance = currentDistance
            workout.averagePace = calculateAveragePace()
            workout.calories = currentCalories
            workout.steps = currentSteps
            workout.averageHeartRate = currentHeartRate
            workout.route = locations.map { $0.coordinate }
            let elevationData = calculateElevationGainAndLoss()
            workout.elevationGain = elevationData.gain
            workout.elevationLoss = elevationData.loss
            workout.endTime = Date()
            
            currentWorkout = nil
        }
        
        print("✅ Workout ended - Distance: \(String(format: "%.2f", workout.distance/1000))km, Duration: \(formatTime(workout.duration))")
        return workout
    }
    
    @MainActor
    private func updateWorkoutData() {
        guard let startTime = startTime, !isPaused else { return }
        
        // Calculate elapsed time correctly: total time - paused time
        let totalTime = Date().timeIntervalSince(startTime)
        elapsedTime = totalTime - totalPausedTime
        
        // Sync data from services
        if let locationService = locationService {
            let oldDistance = currentDistance
            currentDistance = locationService.totalDistance
            currentPace = locationService.currentPace
            currentSpeed = locationService.currentSpeed
            locations = locationService.route
            isGPSReady = locationService.isGPSReady
            accuracy = locationService.accuracy
            
            // Update splits when distance changes
            if abs(currentDistance - oldDistance) > 10 { // 10+ meters change
                updateSplits()
                print("🏃 Distance updated: \(String(format: "%.0f", currentDistance))m, Pace: \(String(format: "%.1f", currentPace)) min/km")
            }
        }
        
        if let healthKitService = healthKitService {
            currentHeartRate = healthKitService.currentHeartRate
            currentCalories = healthKitService.currentCalories
        }
        
        // Calculate steps from distance using average stride length
        let averageStrideLength = 0.75 // meters per step (average adult)
        currentSteps = currentDistance > 0 ? Int(currentDistance / averageStrideLength) : 0
        
        // Log workout updates
        if let hr = currentHeartRate {
            print("❤️ Heart Rate: \(Int(hr)) bpm, Calories: \(String(format: "%.0f", currentCalories)), Steps: \(currentSteps) (estimated)")
        } else if currentSteps > 0 {
            print("📊 Distance: \(String(format: "%.0f", currentDistance))m, Calories: \(String(format: "%.0f", currentCalories)), Steps: \(currentSteps) (estimated)")
        }
    }
    
    private func calculateAveragePace() -> Double {
        guard currentDistance > 0 else { return 0 }
        let pace = (elapsedTime / 60) / (currentDistance / 1000) // minutes per km
        
        // Debug: Log real-time pace calculation
        print("🏃 Real-time Pace Debug:")
        print("   Elapsed Time: \(elapsedTime) seconds")
        print("   Current Distance: \(currentDistance) meters")
        print("   Calculated Pace: \(pace) min/km")
        
        return pace
    }
    
    
    private func calculateElevationGainAndLoss() -> (gain: Double, loss: Double) {
        guard locations.count > 1 else { return (0.0, 0.0) }
        
        var elevationGain: Double = 0.0
        var elevationLoss: Double = 0.0
        
        // Ensure we have at least 2 locations before creating range
        let locationCount = locations.count
        guard locationCount >= 2 else { return (0.0, 0.0) }
        
        for i in 1..<locationCount {
            let altitudeDifference = locations[i].altitude - locations[i-1].altitude
            if altitudeDifference > 0 {
                elevationGain += altitudeDifference
            } else if altitudeDifference < 0 {
                elevationLoss += abs(altitudeDifference)
            }
        }
        return (gain: elevationGain, loss: elevationLoss)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Split Tracking
    
    private func updateSplits() {
        let completedSplits = Int(currentDistance / splitDistance)
        
        // Check if we've completed a new split
        if completedSplits > currentSplits.count {
            // Complete the previous split
            if currentSplits.count > 0 || lastSplitDistance > 0 {
                let splitTime = elapsedTime - lastSplitTime
                let splitPace = splitTime > 0 ? (splitTime / 60) / (splitDistance / 1000) : 0
                
                let completedSplit = LiveWorkoutSplit(
                    splitNumber: currentSplits.count + 1,
                    distance: splitDistance,
                    time: splitTime,
                    pace: splitPace,
                    isCompleted: true
                )
                
                currentSplits.append(completedSplit)
                lastSplitDistance = currentDistance
                lastSplitTime = elapsedTime
                
                // Trigger haptic feedback for split completion
                hapticService?.splitCompleted()
                
                print("✅ Split \(completedSplit.splitNumber) completed: \(formatTime(splitTime)) @ \(formatPace(splitPace))")
            }
        }
        
        // Update current split progress
        let currentSplitDistance = currentDistance - (Double(currentSplits.count) * splitDistance)
        let currentSplitTime = elapsedTime - lastSplitTime
        let currentSplitPace = currentSplitTime > 0 && currentSplitDistance > 100 ? 
            (currentSplitTime / 60) / (currentSplitDistance / 1000) : currentPace
        
        currentSplitProgress = LiveWorkoutSplit(
            splitNumber: currentSplits.count + 1,
            distance: currentSplitDistance,
            time: currentSplitTime,
            pace: currentSplitPace,
            isCompleted: false
        )
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace.isFinite else { return "--:--" }
        
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}