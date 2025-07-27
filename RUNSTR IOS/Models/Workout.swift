import Foundation
import CoreLocation
import HealthKit

struct Workout: Identifiable {
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
    var route: [CLLocationCoordinate2D]?
    var elevationGain: Double?
    let weather: WeatherCondition?
    let nostrEventID: String? // Reference to published NIP-101e note
    var rewardAmount: Int // sats earned
    let isTeamChallenge: Bool
    let teamID: String?
    let eventID: String?
    
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
        self.route = nil
        self.elevationGain = nil
        self.weather = nil
        self.nostrEventID = nil
        self.rewardAmount = 0
        self.isTeamChallenge = false
        self.teamID = nil
        self.eventID = nil
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
}

struct WeatherCondition: Codable {
    let temperature: Double // Celsius
    let condition: String
    let humidity: Double
    let windSpeed: Double
}

class WorkoutSession: ObservableObject {
    @Published var isActive: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentWorkout: Workout?
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentDistance: Double = 0
    @Published var currentPace: Double = 0
    @Published var currentHeartRate: Double? = nil
    @Published var currentCalories: Double = 0
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
        
        // Initialize workout
        currentWorkout = Workout(activityType: activityType, userID: userID)
        isActive = true
        isPaused = false
        startTime = Date()
        elapsedTime = 0
        currentDistance = 0
        currentCalories = 0
        locations.removeAll()
        
        // Start services
        let healthKitStarted = await healthKitService.startWorkoutSession(activityType: activityType)
        if !healthKitStarted {
            print("❌ Failed to start HealthKit session")
            return false
        }
        
        locationService.startTracking()
        
        // Start timer for UI updates
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateWorkoutData()
            }
        }
        
        print("✅ Started workout session for \(activityType.displayName)")
        return true
    }
    
    func pauseWorkout() {
        guard isActive, !isPaused else { return }
        
        isPaused = true
        timer?.invalidate()
        
        // Pause location tracking
        locationService?.pauseTracking()
        
        print("⏸️ Workout paused")
    }
    
    func resumeWorkout() {
        guard isActive, isPaused else { return }
        
        isPaused = false
        
        // Resume location tracking
        locationService?.resumeTracking()
        
        // Restart timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateWorkoutData()
            }
        }
        
        print("▶️ Workout resumed")
    }
    
    func endWorkout() async -> Workout? {
        guard isActive else { return nil }
        
        timer?.invalidate()
        isActive = false
        isPaused = false
        
        // Stop location tracking
        locationService?.stopTracking()
        
        // End HealthKit session and get final workout
        let finalWorkout = await healthKitService?.endWorkoutSession()
        
        guard var workout = currentWorkout else { return nil }
        
        // Update workout with final data
        workout.duration = elapsedTime
        workout.distance = currentDistance
        workout.averagePace = calculateAveragePace()
        workout.rewardAmount = calculateReward()
        workout.calories = currentCalories
        workout.route = locations.map { $0.coordinate }
        workout.elevationGain = calculateElevationGain()
        workout.endTime = Date()
        
        currentWorkout = nil
        
        print("✅ Workout ended - Distance: \(String(format: "%.2f", currentDistance/1000))km, Duration: \(formatTime(elapsedTime))")
        return workout
    }
    
    private func updateWorkoutData() {
        guard let startTime = startTime, !isPaused else { return }
        
        // Update elapsed time
        elapsedTime = Date().timeIntervalSince(startTime)
        
        // Sync data from services
        if let locationService = locationService {
            currentDistance = locationService.totalDistance
            currentPace = locationService.currentPace
            locations = locationService.route
            isGPSReady = locationService.isGPSReady
            accuracy = locationService.accuracy
        }
        
        if let healthKitService = healthKitService {
            currentHeartRate = healthKitService.currentHeartRate
            currentCalories = healthKitService.currentCalories
        }
    }
    
    private func calculateAveragePace() -> Double {
        guard currentDistance > 0 else { return 0 }
        return (elapsedTime / 60) / (currentDistance / 1000) // minutes per km
    }
    
    private func calculateReward() -> Int {
        let baseReward = Int(currentDistance / 100) // 1 sat per 100m
        let timeBonus = Int(elapsedTime / 300) // 1 sat per 5 minutes
        let heartRateBonus = currentHeartRate != nil ? 50 : 0 // bonus for heart rate data
        return max(100, baseReward + timeBonus + heartRateBonus) // minimum 100 sats
    }
    
    private func calculateElevationGain() -> Double {
        guard locations.count > 1 else { return 0.0 }
        
        var elevationGain: Double = 0.0
        for i in 1..<locations.count {
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