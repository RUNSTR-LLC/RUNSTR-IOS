#!/usr/bin/env swift

// Test script to verify profile stats calculations
// Run this in Xcode playground to test the stats logic

import Foundation

// Mock structures for testing
struct Workout {
    let id = UUID().uuidString
    let distance: Double // in meters
    let duration: Double // in seconds
    let startTime: Date
    let activityType = "running"
}

struct UserStats {
    var totalDistance: Double = 0.0
    var totalWorkouts: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastWorkoutDate: Date = Date.distantPast
    var lastUpdated: Date = Date()
    
    var formattedTotalDistance: String {
        let km = totalDistance / 1000
        return String(format: "%.1f km", km)
    }
    
    var averageDistancePerWorkout: Double {
        guard totalWorkouts > 0 else { return 0.0 }
        return totalDistance / Double(totalWorkouts)
    }
}

// Test data - simulating your 6 workouts with 3.7 miles being the longest
let testWorkouts = [
    // Today's workout
    Workout(distance: 5950, duration: 1800, startTime: Date()),
    
    // Yesterday's workout
    Workout(distance: 3200, duration: 1200, startTime: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
    
    // 2 days ago
    Workout(distance: 4800, duration: 1500, startTime: Calendar.current.date(byAdding: .day, value: -2, to: Date())!),
    
    // 4 days ago (gap in streak)
    Workout(distance: 2400, duration: 900, startTime: Calendar.current.date(byAdding: .day, value: -4, to: Date())!),
    
    // 5 days ago  
    Workout(distance: 1600, duration: 600, startTime: Calendar.current.date(byAdding: .day, value: -5, to: Date())!),
    
    // 6 days ago (longest - 3.7 miles = ~5950 meters)
    Workout(distance: 5950, duration: 2100, startTime: Calendar.current.date(byAdding: .day, value: -6, to: Date())!)
]

func calculateStatsFromWorkouts(_ workouts: [Workout]) -> UserStats {
    var stats = UserStats()
    stats.totalWorkouts = workouts.count
    stats.totalDistance = workouts.reduce(0) { $0 + $1.distance }
    
    // Find last workout date
    if let lastWorkout = workouts.first {
        stats.lastWorkoutDate = lastWorkout.startTime
    }
    
    // Calculate streaks
    var currentStreak = 0
    var longestStreak = 0
    var tempStreak = 0
    var lastDate: Date? = nil
    
    // Sort workouts by date (newest first)
    let sortedWorkouts = workouts.sorted { $0.startTime > $1.startTime }
    
    for workout in sortedWorkouts {
        let workoutDate = Calendar.current.startOfDay(for: workout.startTime)
        
        if let last = lastDate {
            let daysBetween = Calendar.current.dateComponents([.day], from: workoutDate, to: last).day ?? 0
            
            if daysBetween == 1 {
                tempStreak += 1
            } else if daysBetween == 0 {
                // Same day, don't increment streak
            } else {
                // Gap in workouts, reset temp streak
                longestStreak = max(longestStreak, tempStreak + 1)
                tempStreak = 0
            }
        } else {
            // First workout
            tempStreak = 1
        }
        
        lastDate = workoutDate
    }
    
    // Final check for longest streak
    longestStreak = max(longestStreak, tempStreak)
    
    // Calculate current streak (from today backwards)
    if let firstWorkout = sortedWorkouts.first {
        let today = Calendar.current.startOfDay(for: Date())
        let lastWorkoutDay = Calendar.current.startOfDay(for: firstWorkout.startTime)
        let daysSinceLastWorkout = Calendar.current.dateComponents([.day], from: lastWorkoutDay, to: today).day ?? 0
        
        if daysSinceLastWorkout <= 1 {
            // Count consecutive days from most recent workout
            currentStreak = 1
            var checkDate = lastWorkoutDay
            
            for i in 1..<sortedWorkouts.count {
                let workoutDay = Calendar.current.startOfDay(for: sortedWorkouts[i].startTime)
                let daysDiff = Calendar.current.dateComponents([.day], from: workoutDay, to: checkDate).day ?? 0
                
                if daysDiff == 1 {
                    currentStreak += 1
                    checkDate = workoutDay
                } else if daysDiff > 1 {
                    break
                }
            }
        }
    }
    
    stats.currentStreak = currentStreak
    stats.longestStreak = longestStreak
    stats.lastUpdated = Date()
    
    return stats
}

// Run the test
let calculatedStats = calculateStatsFromWorkouts(testWorkouts)

print("🧪 Profile Stats Test Results:")
print("==============================")
print("Total Workouts: \(calculatedStats.totalWorkouts)")
print("Total Distance: \(calculatedStats.formattedTotalDistance)")
print("Average per Workout: \(String(format: "%.1f km", calculatedStats.averageDistancePerWorkout / 1000))")
print("Current Streak: \(calculatedStats.currentStreak) days")
print("Longest Streak: \(calculatedStats.longestStreak) days")
print("Last Workout: \(calculatedStats.lastWorkoutDate)")
print("")
print("Expected Results:")
print("- Total Workouts: 6")
print("- Total Distance: ~28.0 km") 
print("- Average: ~4.7 km per workout")
print("- Current Streak: 3 days (today, yesterday, day before)")
print("- Longest Streak: 3 days")
print("")
print("✅ Test complete - check if values match your actual workout data!")