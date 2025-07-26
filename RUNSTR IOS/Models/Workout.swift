import Foundation
import CoreLocation
import HealthKit

struct Workout: Identifiable {
    let id: String
    let userID: String
    let activityType: ActivityType
    let startTime: Date
    let endTime: Date
    var duration: TimeInterval
    var distance: Double // meters
    var averagePace: Double // minutes per kilometer
    let calories: Double?
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let route: [CLLocationCoordinate2D]?
    let elevationGain: Double?
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
    @Published var locations: [CLLocation] = []
    
    private var timer: Timer?
    private var startTime: Date?
    
    func startWorkout(activityType: ActivityType, userID: String) {
        currentWorkout = Workout(activityType: activityType, userID: userID)
        isActive = true
        isPaused = false
        startTime = Date()
        elapsedTime = 0
        currentDistance = 0
        locations.removeAll()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateElapsedTime()
        }
    }
    
    func pauseWorkout() {
        isPaused = true
        timer?.invalidate()
    }
    
    func resumeWorkout() {
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateElapsedTime()
        }
    }
    
    func endWorkout() -> Workout? {
        timer?.invalidate()
        isActive = false
        isPaused = false
        
        guard var workout = currentWorkout else { return nil }
        
        var updatedWorkout = workout
        updatedWorkout.duration = elapsedTime
        updatedWorkout.distance = currentDistance
        updatedWorkout.averagePace = calculateAveragePace()
        updatedWorkout.rewardAmount = calculateReward()
        workout = updatedWorkout
        
        currentWorkout = nil
        return workout
    }
    
    private func updateElapsedTime() {
        guard let startTime = startTime, !isPaused else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
    }
    
    private func calculateAveragePace() -> Double {
        guard currentDistance > 0 else { return 0 }
        return (elapsedTime / 60) / (currentDistance / 1000) // minutes per km
    }
    
    private func calculateReward() -> Int {
        let baseReward = Int(currentDistance / 100) // 1 sat per 100m
        let timeBonus = Int(elapsedTime / 300) // 1 sat per 5 minutes
        return max(100, baseReward + timeBonus) // minimum 100 sats
    }
}