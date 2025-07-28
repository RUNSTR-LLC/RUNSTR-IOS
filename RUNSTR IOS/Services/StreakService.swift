import Foundation
import Combine

/// Service responsible for managing user workout streaks and calculating streak bonuses
/// Handles daily streak tracking, weekly resets, and reward distribution
@MainActor
class StreakService: ObservableObject {
    // MARK: - Published Properties
    @Published var currentStreak: Int = 0
    @Published var weeklyProgress: [Bool] = Array(repeating: false, count: 7) // Sun-Sat
    @Published var streakRewardEarned: Int = 0
    @Published var isStreakActive: Bool = false
    @Published var daysUntilWeeklyReset: Int = 0
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Keys for UserDefaults
    private enum UserDefaultsKeys {
        static let currentStreak = "streak_current_streak"
        static let weeklyProgress = "streak_weekly_progress"
        static let lastWorkoutDate = "streak_last_workout_date"
        static let weekStartDate = "streak_week_start_date"
        static let totalStreaksCompleted = "streak_total_completed"
    }
    
    // MARK: - Initialization
    init() {
        loadStreakData()
        setupDailyCheck()
        updateWeeklyResetCountdown()
    }
    
    // MARK: - Public Methods
    
    /// Record a workout and update streak status
    func recordWorkout(date: Date = Date()) {
        let today = calendar.startOfDay(for: date)
        let lastWorkoutDate = getLastWorkoutDate()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            print("❌ Failed to calculate yesterday's date")
            return
        }
        
        // Check if this is the first workout today
        guard !hasWorkoutToday(date: date) else {
            print("ℹ️ Workout already recorded for today")
            return
        }
        
        // Update streak logic
        if calendar.isDate(lastWorkoutDate, inSameDayAs: yesterday) || lastWorkoutDate == Date.distantPast {
            // Continuing streak or starting new streak
            currentStreak += 1
        } else if !calendar.isDate(lastWorkoutDate, inSameDayAs: today) {
            // Streak broken, reset to 1
            currentStreak = 1
        }
        
        // Update weekly progress
        updateWeeklyProgress(for: date)
        
        // Save data
        saveLastWorkoutDate(date)
        saveStreakData()
        
        // Calculate and track reward
        let reward = calculateStreakReward()
        streakRewardEarned = reward
        isStreakActive = true
        
        print("✅ Streak updated: \(currentStreak) days, reward: \(reward) sats")
    }
    
    /// Get the current streak reward amount based on day of week
    func calculateStreakReward() -> Int {
        let weekday = getDayOfWeek()
        
        switch weekday {
        case 1: return 100 // Sunday - Day 1
        case 2: return 200 // Monday - Day 2  
        case 3: return 300 // Tuesday - Day 3
        case 4: return 400 // Wednesday - Day 4
        case 5: return 500 // Thursday - Day 5  
        case 6: return 600 // Friday - Day 6
        case 7: return 700 // Saturday - Day 7
        default: return 100
        }
    }
    
    /// Check if user has completed the weekly challenge (7 days)
    func hasCompletedWeeklyChallenge() -> Bool {
        return weeklyProgress.allSatisfy { $0 }
    }
    
    /// Get bonus reward for completing weekly challenge
    func getWeeklyCompletionBonus() -> Int {
        return hasCompletedWeeklyChallenge() ? 1000 : 0 // 1000 sat bonus for completing week
    }
    
    /// Reset weekly progress (called automatically on Sunday)
    func resetWeeklyProgress() {
        weeklyProgress = Array(repeating: false, count: 7)
        saveStreakData()
        updateWeekStartDate()
        print("🔄 Weekly streak progress reset")
    }
    
    /// Get formatted streak status message
    func getStreakStatusMessage() -> String {
        if currentStreak == 0 {
            return "Start your streak today! 💪"
        } else if currentStreak == 1 {
            return "Great start! Keep it going! 🔥"
        } else if hasCompletedWeeklyChallenge() {
            return "Week completed! Amazing work! 🏆"
        } else {
            return "\(currentStreak) day streak! Keep it up! 🔥"
        }
    }
    
    /// Get days remaining in current week
    func getDaysRemainingInWeek() -> Int {
        return weeklyProgress.filter { !$0 }.count
    }
    
    // MARK: - Private Methods
    
    private func loadStreakData() {
        currentStreak = userDefaults.integer(forKey: UserDefaultsKeys.currentStreak)
        weeklyProgress = userDefaults.array(forKey: UserDefaultsKeys.weeklyProgress) as? [Bool] ?? Array(repeating: false, count: 7)
        
        // Check if we need to reset for new week
        checkForWeeklyReset()
    }
    
    private func saveStreakData() {
        userDefaults.set(currentStreak, forKey: UserDefaultsKeys.currentStreak)
        userDefaults.set(weeklyProgress, forKey: UserDefaultsKeys.weeklyProgress)
    }
    
    private func getLastWorkoutDate() -> Date {
        return userDefaults.object(forKey: UserDefaultsKeys.lastWorkoutDate) as? Date ?? Date.distantPast
    }
    
    private func saveLastWorkoutDate(_ date: Date) {
        userDefaults.set(date, forKey: UserDefaultsKeys.lastWorkoutDate)
    }
    
    private func hasWorkoutToday(date: Date = Date()) -> Bool {
        let today = calendar.startOfDay(for: date)
        let lastWorkout = calendar.startOfDay(for: getLastWorkoutDate())
        return calendar.isDate(today, inSameDayAs: lastWorkout)
    }
    
    private func updateWeeklyProgress(for date: Date) {
        let weekday = calendar.component(.weekday, from: date) - 1 // 0-6 (Sun-Sat)
        weeklyProgress[weekday] = true
    }
    
    private func getDayOfWeek(for date: Date = Date()) -> Int {
        return calendar.component(.weekday, from: date)
    }
    
    private func checkForWeeklyReset() {
        let weekStartDate = getWeekStartDate()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        if !calendar.isDate(weekStartDate, inSameDayAs: currentWeekStart) {
            resetWeeklyProgress()
        }
    }
    
    private func getWeekStartDate() -> Date {
        return userDefaults.object(forKey: UserDefaultsKeys.weekStartDate) as? Date ?? Date()
    }
    
    private func updateWeekStartDate() {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        userDefaults.set(weekStart, forKey: UserDefaultsKeys.weekStartDate)
    }
    
    private func setupDailyCheck() {
        // Check for streak breaks daily at midnight
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in
                self.checkStreakValidity()
                self.updateWeeklyResetCountdown()
            }
        }
    }
    
    private func checkStreakValidity() {
        let lastWorkout = getLastWorkoutDate()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        // If last workout was more than yesterday, streak is broken
        if lastWorkout < calendar.startOfDay(for: yesterday) && currentStreak > 0 {
            currentStreak = 0
            isStreakActive = false
            saveStreakData()
            print("💔 Streak broken - no workout yesterday")
        }
    }
    
    private func updateWeeklyResetCountdown() {
        let now = Date()
        let nextSunday = calendar.nextDate(after: now, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime)
        
        if let nextSunday = nextSunday {
            daysUntilWeeklyReset = calendar.dateComponents([.day], from: now, to: nextSunday).day ?? 0
        }
    }
}

// MARK: - Extensions

extension StreakService {
    /// Get streak statistics for display
    var streakStats: StreakStats {
        return StreakStats(
            currentStreak: currentStreak,
            weeklyProgress: weeklyProgress,
            weeklyComplete: hasCompletedWeeklyChallenge(),
            daysRemaining: getDaysRemainingInWeek(),
            nextReward: calculateStreakReward(),
            weeklyBonus: getWeeklyCompletionBonus()
        )
    }
}

// MARK: - Supporting Models

struct StreakStats {
    let currentStreak: Int
    let weeklyProgress: [Bool]
    let weeklyComplete: Bool
    let daysRemaining: Int
    let nextReward: Int
    let weeklyBonus: Int
    
    var progressText: String {
        let completed = weeklyProgress.filter { $0 }.count
        return "\(completed)/7 days this week"
    }
    
    var completionPercentage: Double {
        let completed = weeklyProgress.filter { $0 }.count
        return Double(completed) / 7.0
    }
}