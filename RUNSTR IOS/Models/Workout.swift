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
        
        for i in 0..<splitCount {
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
        let hours = self.duration / 3600
        let kmDistance = distance / 1000
        self.averagePace = kmDistance > 0 ? (hours * 60) / kmDistance : 0
        
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.steps = steps
        self.route = locations.isEmpty ? nil : locations
        self.elevationGain = elevationGain
        self.weather = nil
        self.nostrEventID = nil
        self.rewardAmount = nil
    }
    
    var pace: String {
        let minutes = Int(averagePace)
        let seconds = Int((averagePace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    var distanceFormatted: String {
        return String(format: "%.2f km", distance / 1000)
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
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case id, userID, activityType, startTime, endTime, duration, distance, averagePace, calories
        case averageHeartRate, maxHeartRate, elevationGain, weather, nostrEventID, route, steps, rewardAmount
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
    
    private var timer: Timer?
    private var startTime: Date?
    private var healthKitService: HealthKitService?
    private var locationService: LocationService?
    
    func configure(healthKitService: HealthKitService, locationService: LocationService) {
        self.healthKitService = healthKitService
        self.locationService = locationService
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
            elapsedTime = 0
            currentDistance = 0
            currentCalories = 0
            locations.removeAll()
        }
        
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
            timer?.invalidate()
        }
        
        // Pause location tracking
        locationService?.pauseTracking()
        
        print("⏸️ Workout paused")
    }
    
    func resumeWorkout() {
        guard isActive, isPaused else { return }
        
        Task { @MainActor in
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
        
        print("▶️ Workout resumed")
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
        
        // End HealthKit session and get final workout
        let finalWorkout = await healthKitService?.endWorkoutSession()
        
        guard var workout = currentWorkout else { return nil }
        
        // Update workout with final data on main thread
        await MainActor.run {
            workout.duration = elapsedTime
            workout.distance = currentDistance
            workout.averagePace = calculateAveragePace()
            workout.calories = currentCalories
            workout.steps = currentSteps
            workout.averageHeartRate = currentHeartRate
            workout.route = locations.map { $0.coordinate }
            workout.elevationGain = calculateElevationGain()
            workout.endTime = Date()
            
            currentWorkout = nil
        }
        
        print("✅ Workout ended - Distance: \(String(format: "%.2f", workout.distance/1000))km, Duration: \(formatTime(workout.duration))")
        return workout
    }
    
    @MainActor
    private func updateWorkoutData() {
        guard let startTime = startTime, !isPaused else { return }
        
        // Update elapsed time
        elapsedTime = Date().timeIntervalSince(startTime)
        
        // Sync data from services
        if let locationService = locationService {
            let oldDistance = currentDistance
            currentDistance = locationService.totalDistance
            currentPace = locationService.currentPace
            currentSpeed = locationService.currentSpeed
            locations = locationService.route
            isGPSReady = locationService.isGPSReady
            accuracy = locationService.accuracy
            
            // Log significant changes
            if abs(currentDistance - oldDistance) > 10 { // 10+ meters change
                print("🏃 Distance updated: \(String(format: "%.0f", currentDistance))m, Pace: \(String(format: "%.1f", currentPace)) min/km")
            }
        }
        
        if let healthKitService = healthKitService {
            currentHeartRate = healthKitService.currentHeartRate
            currentCalories = healthKitService.currentCalories
            currentSteps = healthKitService.currentSteps
            
            // Log heart rate updates
            if let hr = currentHeartRate {
                print("❤️ Heart Rate: \(Int(hr)) bpm, Calories: \(String(format: "%.0f", currentCalories)), Steps: \(currentSteps)")
            }
        }
    }
    
    private func calculateAveragePace() -> Double {
        guard currentDistance > 0 else { return 0 }
        return (elapsedTime / 60) / (currentDistance / 1000) // minutes per km
    }
    
    
    private func calculateElevationGain() -> Double {
        guard locations.count > 1 else { return 0.0 }
        
        var elevationGain: Double = 0.0
        // Ensure we have at least 2 locations before creating range
        let locationCount = locations.count
        guard locationCount >= 2 else { return 0.0 }
        
        for i in 1..<locationCount {
            let altitudeDifference = locations[i].altitude - locations[i-1].altitude
            if altitudeDifference > 0 {
                elevationGain += altitudeDifference
            }
        }
        return elevationGain
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
}