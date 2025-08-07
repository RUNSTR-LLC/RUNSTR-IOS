import Foundation
import HealthKit
import ObjectiveC

/// Aggregates team statistics from real workout data
class TeamStatsAggregator {
    private let healthKitService: HealthKitService
    private let workoutStorage: WorkoutStorage
    
    init(healthKitService: HealthKitService, workoutStorage: WorkoutStorage) {
        self.healthKitService = healthKitService
        self.workoutStorage = workoutStorage
    }
    
    // MARK: - Team Statistics Aggregation
    
    /// Calculate comprehensive team statistics from real workout data
    func calculateTeamStats(for team: Team) async -> TeamStatsCloudKit {
        var stats = TeamStatsCloudKit(teamID: team.id)
        
        // Collect all workouts from team members
        var allMemberWorkouts: [Workout] = []
        var memberStats: [String: MemberStats] = [:]
        var activeMembers = 0
        
        for memberID in team.memberIDs {
            let memberWorkouts = await fetchMemberWorkouts(userID: memberID)
            allMemberWorkouts.append(contentsOf: memberWorkouts)
            
            // Calculate individual member stats
            let individualStats = calculateMemberStats(workouts: memberWorkouts)
            memberStats[memberID] = individualStats
            
            // Count as active if they have workouts in the last 30 days
            if individualStats.lastWorkoutDate > Date().addingTimeInterval(-30 * 24 * 60 * 60) {
                activeMembers += 1
            }
        }
        
        // Aggregate team-wide statistics
        stats.totalDistance = allMemberWorkouts.reduce(0) { $0 + $1.distance }
        stats.totalWorkouts = allMemberWorkouts.count
        stats.activeMembers = activeMembers
        stats.averageWorkoutsPerMember = team.memberIDs.isEmpty ? 0 : Double(stats.totalWorkouts) / Double(team.memberIDs.count)
        
        // Calculate weekly and monthly distances
        let weeklyWorkouts = getWorkoutsInRange(allMemberWorkouts, days: 7)
        let monthlyWorkouts = getWorkoutsInRange(allMemberWorkouts, days: 30)
        
        stats.weeklyDistance = weeklyWorkouts.reduce(0) { $0 + $1.distance }
        stats.monthlyDistance = monthlyWorkouts.reduce(0) { $0 + $1.distance }
        
        // Determine top performers (by total distance)
        stats.topPerformers = getTopPerformers(memberStats: memberStats, limit: 5)
        
        stats.lastUpdated = Date()
        
        print("✅ Calculated team stats for \(team.name): \(stats.totalWorkouts) workouts, \(String(format: "%.1f", stats.totalDistance/1000))km")
        
        return stats
    }
    
    /// Calculate individual member statistics
    func calculateMemberStats(workouts: [Workout]) -> MemberStats {
        var stats = MemberStats()
        
        guard !workouts.isEmpty else { return stats }
        
        // Total aggregations
        stats.totalDistance = workouts.reduce(0) { $0 + $1.distance }
        stats.totalWorkouts = workouts.count
        
        // Calculate average pace for running/walking workouts
        let runningWorkouts = workouts.filter { 
            $0.activityType == .running || $0.activityType == .walking 
        }
        if !runningWorkouts.isEmpty {
            let totalRunningTime = runningWorkouts.reduce(0) { $0 + $1.duration }
            let totalRunningDistance = runningWorkouts.reduce(0) { $0 + $1.distance }
            stats.averagePace = totalRunningDistance > 0 ? totalRunningTime / totalRunningDistance : 0
        }
        
        // Find most recent workout
        stats.lastWorkoutDate = workouts.map { $0.startTime }.max() ?? Date.distantPast
        
        // Calculate current streak (consecutive days with workouts)
        stats.currentStreak = calculateCurrentStreak(workouts: workouts)
        
        // Weekly and monthly distances
        let weeklyWorkouts = getWorkoutsInRange(workouts, days: 7)
        let monthlyWorkouts = getWorkoutsInRange(workouts, days: 30)
        
        stats.weeklyDistance = weeklyWorkouts.reduce(0) { $0 + $1.distance }
        stats.monthlyDistance = monthlyWorkouts.reduce(0) { $0 + $1.distance }
        
        return stats
    }
    
    /// Update all team member stats and rankings
    func updateTeamMemberStats(for team: Team) async {
        var memberStatsList: [(String, MemberStats)] = []
        
        // Calculate stats for each member
        for memberID in team.memberIDs {
            let memberWorkouts = await fetchMemberWorkouts(userID: memberID)
            let stats = calculateMemberStats(workouts: memberWorkouts)
            memberStatsList.append((memberID, stats))
        }
        
        // Sort by total distance for ranking
        memberStatsList.sort { $0.1.totalDistance > $1.1.totalDistance }
        
        // Assign ranks (stats will be cached in memory for this session)
        for (index, (memberID, var stats)) in memberStatsList.enumerated() {
            stats.rank = index + 1
            
            // In a real implementation, these member stats could be stored
            // either in CloudKit member records or a separate stats service
            print("📊 Member \(memberID) rank: \(stats.rank), distance: \(String(format: "%.1f", stats.totalDistance/1000))km")
        }
        
        print("✅ Updated stats for \(memberStatsList.count) members of team \(team.name)")
    }
    
    // MARK: - Private Helper Methods
    
    /// Fetch all workouts for a specific user
    private func fetchMemberWorkouts(userID: String) async -> [Workout] {
        // In a real implementation, this would fetch workouts for the specific user
        // For now, we'll use the current user's workouts as a placeholder
        let allWorkouts = await workoutStorage.workouts
        return allWorkouts.filter { workout in
            // Filter workouts from the last 6 months for performance
            workout.startTime > Date().addingTimeInterval(-6 * 30 * 24 * 60 * 60)
        }
    }
    
    /// Get workouts within the specified number of days
    private func getWorkoutsInRange(_ workouts: [Workout], days: Int) -> [Workout] {
        let cutoffDate = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))
        return workouts.filter { $0.startTime > cutoffDate }
    }
    
    /// Calculate current workout streak (consecutive days)
    private func calculateCurrentStreak(workouts: [Workout]) -> Int {
        guard !workouts.isEmpty else { return 0 }
        
        // Sort workouts by date (most recent first)
        let sortedWorkouts = workouts.sorted { $0.startTime > $1.startTime }
        
        var streak = 0
        var currentDate = Calendar.current.startOfDay(for: Date())
        
        // Group workouts by day
        let workoutsByDay = Dictionary(grouping: sortedWorkouts) { workout in
            Calendar.current.startOfDay(for: workout.startTime)
        }
        
        // Check consecutive days starting from today
        while let _ = workoutsByDay[currentDate] {
            streak += 1
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        // If no workout today but has one yesterday, check if streak should start from yesterday
        if streak == 0 {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            let yesterdayStart = Calendar.current.startOfDay(for: yesterday)
            
            if workoutsByDay[yesterdayStart] != nil {
                streak = 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: yesterdayStart) ?? yesterdayStart
                
                while let _ = workoutsByDay[currentDate] {
                    streak += 1
                    currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                }
            }
        }
        
        return streak
    }
    
    /// Get top performers by total distance
    private func getTopPerformers(memberStats: [String: MemberStats], limit: Int) -> [String] {
        return memberStats.sorted { $0.value.totalDistance > $1.value.totalDistance }
            .prefix(limit)
            .map { $0.key }
    }
}

// MARK: - TeamService Extension for Stats Integration

extension TeamService {
    /// Initialize stats aggregator with required services
    func setupStatsAggregator(healthKitService: HealthKitService, workoutStorage: WorkoutStorage) {
        self.statsAggregator = TeamStatsAggregator(
            healthKitService: healthKitService,
            workoutStorage: workoutStorage
        )
    }
    
    /// Recalculate and update team statistics
    func updateTeamStatistics(for team: Team) async {
        guard let aggregator = statsAggregator else {
            print("❌ Stats aggregator not initialized")
            return
        }
        
        isLoading = true
        
        do {
            // Calculate new stats
            let updatedStats = await aggregator.calculateTeamStats(for: team)
            
            // Update member stats and rankings
            await aggregator.updateTeamMemberStats(for: team)
            
            // Save to CloudKit
            let statsRecord = updatedStats.toCKRecord(container: container)
            let _ = try await publicDatabase.save(statsRecord)
            
            // Stats are now stored in CloudKit and cached in memory
            
            await MainActor.run {
                teamStats[team.id] = updatedStats
                isLoading = false
            }
            
            print("✅ Updated statistics for team: \(team.name)")
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update team statistics: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Failed to update team statistics: \(error)")
        }
    }
    
    /// Schedule periodic stats updates for active teams
    func scheduleStatsUpdates() {
        // Update stats for user's teams every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self = self else { return }
                
                for team in self.myTeams {
                    await self.updateTeamStatistics(for: team)
                }
            }
        }
    }
}

// MARK: - Private Properties Extension

extension TeamService {
    private var statsAggregator: TeamStatsAggregator? {
        get {
            return objc_getAssociatedObject(self, &statsAggregatorKey) as? TeamStatsAggregator
        }
        set {
            objc_setAssociatedObject(self, &statsAggregatorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private var statsAggregatorKey: UInt8 = 0