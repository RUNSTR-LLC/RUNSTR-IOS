import Foundation
import Combine
import HealthKit

/// Service responsible for aggregating statistics from multiple sources
/// Combines HealthKit workout data with Nostr workout events for comprehensive stats
@MainActor
class StatsService: ObservableObject {
    // MARK: - Published Properties
    @Published var aggregatedStats: AggregatedStats?
    @Published var chartData: [StatsMetric: [ChartDataPoint]] = [:]
    @Published var personalRecords: [ActivityType: [PersonalRecord]] = [:]
    @Published var aiInsights: [AIInsight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let healthKitService: HealthKitService
    private let nostrService: NostrService
    private let authService: AuthenticationService
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var lastRefreshTime: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    init(healthKitService: HealthKitService, nostrService: NostrService, authService: AuthenticationService) {
        self.healthKitService = healthKitService
        self.nostrService = nostrService
        self.authService = authService
        
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    /// Fetch comprehensive stats for the specified timeframe
    func fetchAllStats(for timeframe: TimeFrame) async {
        guard !isLoading else { return }
        
        // Check cache validity
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < cacheDuration,
           aggregatedStats != nil {
            return // Use cached data
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get user's npub configuration
            guard let user = authService.currentUser else {
                throw StatsError.userNotAuthenticated
            }
            
            let npubs = getNpubsToQuery(for: user)
            
            // Fetch data from both sources concurrently
            async let healthKitStats = healthKitService.fetchStatsForTimeframe(timeframe)
            async let nostrStats = fetchNostrStats(npubs: npubs, timeframe: timeframe)
            
            let hkStats = await healthKitStats
            let nStats = await nostrStats
            
            // Create aggregated stats
            let aggregated = AggregatedStats(healthKitStats: hkStats, nostrStats: nStats)
            
            self.aggregatedStats = aggregated
            self.lastRefreshTime = Date()
            
            // Generate additional insights
            await generateAIInsights(from: aggregated)
            
        } catch {
            errorMessage = "Failed to fetch stats: \(error.localizedDescription)"
            print("❌ StatsService error: \(error)")
        }
        
        isLoading = false
    }
    
    /// Generate chart data for a specific metric and timeframe
    func generateChartData(for metric: StatsMetric, timeframe: TimeFrame) async {
        guard let user = authService.currentUser else { return }
        
        let npubs = getNpubsToQuery(for: user)
        
        // Fetch chart data from both sources
        async let healthKitData = healthKitService.fetchChartData(for: metric, timeframe: timeframe)
        async let nostrData = fetchNostrChartData(npubs: npubs, metric: metric, timeframe: timeframe)
        
        let hkData = await healthKitData
        let nData = await nostrData
        
        // Combine and deduplicate data
        let combinedData = combineChartData(healthKit: hkData, nostr: nData)
        
        chartData[metric] = combinedData
    }
    
    /// Fetch personal records from all sources
    func fetchPersonalRecords() async {
        guard let user = authService.currentUser else { return }
        
        let npubs = getNpubsToQuery(for: user)
        
        // Fetch records from both sources
        async let healthKitRecords = healthKitService.fetchPersonalRecords()
        async let nostrRecords = fetchNostrPersonalRecords(npubs: npubs)
        
        let hkRecords = await healthKitRecords
        let nRecords = await nostrRecords
        
        // Merge records, preferring HealthKit for accuracy
        personalRecords = mergePersonalRecords(healthKit: hkRecords, nostr: nRecords)
    }
    
    /// Force refresh all data
    func refreshAllData(for timeframe: TimeFrame) async {
        lastRefreshTime = nil // Invalidate cache
        await fetchAllStats(for: timeframe)
        await fetchPersonalRecords()
        
        // Refresh chart data for all metrics
        for metric in StatsMetric.allCases {
            await generateChartData(for: metric, timeframe: timeframe)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Listen for user changes to refresh data
        authService.$currentUser
            .dropFirst()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshAllData(for: .week)
                }
            }
            .store(in: &cancellables)
    }
    
    private func getNpubsToQuery(for user: User) -> [String] {
        let config = user.statsConfiguration
        var npubs: [String] = []
        
        if config.includeRunstrNpub {
            npubs.append(user.runstrNostrPublicKey)
        }
        
        if config.includeMainNpub, let mainNpub = user.mainNostrPublicKey {
            npubs.append(mainNpub)
        }
        
        if config.includeAdditionalNpubs {
            npubs.append(contentsOf: user.additionalNostrPublicKeys)
        }
        
        return npubs
    }
    
    private func fetchNostrStats(npubs: [String], timeframe: TimeFrame) async -> NostrStats {
        guard !npubs.isEmpty else {
            return NostrStats.empty
        }
        
        var allEvents: [NostrWorkoutEvent] = []
        var mainEvents: [NostrWorkoutEvent] = []
        var runstrEvents: [NostrWorkoutEvent] = []
        var additionalEvents: [NostrWorkoutEvent] = []
        
        // Fetch events from each npub
        for npub in npubs {
            do {
                let events = await nostrService.fetchWorkoutEvents(for: npub, timeframe: timeframe)
                allEvents.append(contentsOf: events)
                
                // Categorize events by source
                if let user = authService.currentUser {
                    if npub == user.runstrNostrPublicKey {
                        runstrEvents.append(contentsOf: events)
                    } else if npub == user.mainNostrPublicKey {
                        mainEvents.append(contentsOf: events)
                    } else {
                        additionalEvents.append(contentsOf: events)
                    }
                }
            } catch {
                print("❌ Failed to fetch Nostr events for npub \(npub): \(error)")
            }
        }
        
        return NostrStats(
            mainEvents: mainEvents,
            runstrEvents: runstrEvents,
            additionalEvents: additionalEvents
        )
    }
    
    private func fetchNostrChartData(npubs: [String], metric: StatsMetric, timeframe: TimeFrame) async -> [ChartDataPoint] {
        var chartPoints: [ChartDataPoint] = []
        
        for npub in npubs {
            let events = await nostrService.fetchWorkoutEvents(for: npub, timeframe: timeframe)
            let points = generateChartDataFromEvents(events, metric: metric, timeframe: timeframe, npubSource: npub)
            chartPoints.append(contentsOf: points)
        }
        
        return chartPoints
    }
    
    private func fetchNostrPersonalRecords(npubs: [String]) async -> [ActivityType: [PersonalRecord]] {
        var allRecords: [ActivityType: [PersonalRecord]] = [:]
        
        for npub in npubs {
            do {
                let events = await nostrService.fetchWorkoutEvents(for: npub, timeframe: .year) // Get full year for records
                let records = calculatePersonalRecordsFromEvents(events, npubSource: npub)
                
                // Merge records by activity type
                for (activityType, recordList) in records {
                    if allRecords[activityType] == nil {
                        allRecords[activityType] = []
                    }
                    allRecords[activityType]?.append(contentsOf: recordList)
                }
            } catch {
                print("❌ Failed to fetch Nostr records for npub \(npub): \(error)")
            }
        }
        
        return allRecords
    }
    
    private func combineChartData(healthKit: [ChartDataPoint], nostr: [ChartDataPoint]) -> [ChartDataPoint] {
        var combinedData: [ChartDataPoint] = []
        
        // Create a dictionary to group by date
        var dataByDate: [Date: [ChartDataPoint]] = [:]
        
        for point in healthKit + nostr {
            let dayStart = Calendar.current.startOfDay(for: point.date)
            if dataByDate[dayStart] == nil {
                dataByDate[dayStart] = []
            }
            dataByDate[dayStart]?.append(point)
        }
        
        // Combine data points for each date, preferring HealthKit
        for (date, points) in dataByDate.sorted(by: { $0.key < $1.key }) {
            if let healthKitPoint = points.first(where: { $0.npubSource == "healthkit" }) {
                combinedData.append(healthKitPoint)
            } else if let nostrPoint = points.first {
                combinedData.append(nostrPoint)
            }
        }
        
        return combinedData
    }
    
    private func mergePersonalRecords(healthKit: [ActivityType: [PersonalRecord]], nostr: [ActivityType: [PersonalRecord]]) -> [ActivityType: [PersonalRecord]] {
        var mergedRecords: [ActivityType: [PersonalRecord]] = [:]
        
        // Start with HealthKit records (preferred)
        for (activityType, records) in healthKit {
            mergedRecords[activityType] = records
        }
        
        // Add Nostr records that don't exist in HealthKit
        for (activityType, nostrRecords) in nostr {
            if mergedRecords[activityType] == nil {
                mergedRecords[activityType] = nostrRecords
            } else {
                // Only add Nostr records that are better than HealthKit records
                for nostrRecord in nostrRecords {
                    if let existingRecords = mergedRecords[activityType],
                       !existingRecords.contains(where: { $0.recordType == nostrRecord.recordType && $0.value >= nostrRecord.value }) {
                        mergedRecords[activityType]?.append(nostrRecord)
                    }
                }
            }
        }
        
        return mergedRecords
    }
    
    private func generateChartDataFromEvents(_ events: [NostrWorkoutEvent], metric: StatsMetric, timeframe: TimeFrame, npubSource: String) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let dateRange = timeframe.dateRange
        
        var chartPoints: [ChartDataPoint] = []
        
        // Group events by date interval
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
            let periodicEvents = events.filter {
                $0.timestamp >= currentDate && $0.timestamp < nextDate
            }
            
            let value: Double
            switch metric {
            case .distance:
                value = periodicEvents.reduce(0) { $0 + $1.distance } / 1000 // km
            case .pace:
                let paces = periodicEvents.compactMap { $0.averagePace > 0 ? $0.averagePace : nil }
                value = paces.isEmpty ? 0 : paces.reduce(0, +) / Double(paces.count)
            case .frequency:
                value = Double(periodicEvents.count)
            case .calories:
                value = periodicEvents.reduce(0.0) { $0 + ($1.calories ?? 0) }
            }
            
            chartPoints.append(ChartDataPoint(
                date: currentDate,
                value: value,
                metric: metric,
                npubSource: npubSource
            ))
            
            currentDate = nextDate
        }
        
        return chartPoints
    }
    
    private func calculatePersonalRecordsFromEvents(_ events: [NostrWorkoutEvent], npubSource: String) -> [ActivityType: [PersonalRecord]] {
        var records: [ActivityType: [PersonalRecord]] = [:]
        
        // Group events by activity type
        let eventsByActivity = Dictionary(grouping: events) { $0.activityType }
        
        for (activityType, activityEvents) in eventsByActivity {
            var activityRecords: [PersonalRecord] = []
            
            // Fastest pace
            if let fastestEvent = activityEvents.min(by: { $0.averagePace < $1.averagePace }),
               fastestEvent.averagePace > 0 {
                activityRecords.append(PersonalRecord(
                    activityType: activityType,
                    recordType: .fastestPace,
                    value: fastestEvent.averagePace,
                    unit: "min/km",
                    achievedDate: fastestEvent.timestamp,
                    location: fastestEvent.location,
                    isNewRecord: isRecentRecord(fastestEvent.timestamp),
                    previousRecord: nil
                ))
            }
            
            // Longest distance
            if let longestEvent = activityEvents.max(by: { $0.distance < $1.distance }) {
                activityRecords.append(PersonalRecord(
                    activityType: activityType,
                    recordType: .longestDistance,
                    value: longestEvent.distance,
                    unit: "meters",
                    achievedDate: longestEvent.timestamp,
                    location: longestEvent.location,
                    isNewRecord: isRecentRecord(longestEvent.timestamp),
                    previousRecord: nil
                ))
            }
            
            // Longest duration
            if let longestDurationEvent = activityEvents.max(by: { $0.duration < $1.duration }) {
                activityRecords.append(PersonalRecord(
                    activityType: activityType,
                    recordType: .longestDuration,
                    value: longestDurationEvent.duration,
                    unit: "seconds",
                    achievedDate: longestDurationEvent.timestamp,
                    location: longestDurationEvent.location,
                    isNewRecord: isRecentRecord(longestDurationEvent.timestamp),
                    previousRecord: nil
                ))
            }
            
            // Most calories (if available)
            if let mostCaloriesEvent = activityEvents.compactMap({ event -> (NostrWorkoutEvent, Double)? in
                guard let calories = event.calories else { return nil }
                return (event, calories)
            }).max(by: { $0.1 < $1.1 }) {
                activityRecords.append(PersonalRecord(
                    activityType: activityType,
                    recordType: .mostCalories,
                    value: mostCaloriesEvent.1,
                    unit: "kcal",
                    achievedDate: mostCaloriesEvent.0.timestamp,
                    location: mostCaloriesEvent.0.location,
                    isNewRecord: isRecentRecord(mostCaloriesEvent.0.timestamp),
                    previousRecord: nil
                ))
            }
            
            records[activityType] = activityRecords
        }
        
        return records
    }
    
    private func isRecentRecord(_ date: Date) -> Bool {
        return Date().timeIntervalSince(date) <= 7 * 24 * 60 * 60 // 7 days
    }
    
    private func generateAIInsights(from stats: AggregatedStats) async {
        var insights: [AIInsight] = []
        
        // Goal progress insight
        let weeklyDistance = stats.combinedStats.totalDistance / 1000 // km
        let monthlyGoal = 50.0 // km (example goal)
        let progress = (weeklyDistance * 4) / monthlyGoal * 100
        
        if progress >= 85 {
            insights.append(AIInsight(
                type: .positive,
                title: "Goal Achievement",
                message: "🎯 You're \(Int(progress))% likely to hit your monthly distance goal at your current pace!",
                data: ["progress": progress],
                actionable: false,
                priority: .medium,
                generatedAt: Date()
            ))
        }
        
        // Consistency insight
        if stats.combinedStats.consistency > 70 {
            insights.append(AIInsight(
                type: .positive,
                title: "Great Consistency",
                message: "💪 You've maintained \(Int(stats.combinedStats.consistency))% workout consistency. Keep it up!",
                data: ["consistency": stats.combinedStats.consistency],
                actionable: false,
                priority: .low,
                generatedAt: Date()
            ))
        }
        
        // Pace improvement insight
        if let currentWeek = stats.healthKitStats.timeframeData[.week],
           currentWeek.improvement > 10 {
            insights.append(AIInsight(
                type: .tip,
                title: "Performance Improvement",
                message: "⚡ Your performance has improved by \(String(format: "%.1f", currentWeek.improvement))% this week!",
                data: ["improvement": currentWeek.improvement],
                actionable: false,
                priority: .medium,
                generatedAt: Date()
            ))
        }
        
        // Recovery recommendation
        if stats.combinedStats.totalWorkouts > 5 {
            insights.append(AIInsight(
                type: .warning,
                title: "Recovery Recommendation",
                message: "🛡️ You've done \(stats.combinedStats.totalWorkouts) workouts recently. Consider a recovery day to prevent injury.",
                data: ["workouts": Double(stats.combinedStats.totalWorkouts)],
                actionable: true,
                priority: .high,
                generatedAt: Date()
            ))
        }
        
        self.aiInsights = insights
    }
}

// MARK: - Extensions

extension NostrService {
    func fetchWorkoutEvents(for npub: String, timeframe: TimeFrame) async -> [NostrWorkoutEvent] {
        // This method needs to be implemented in NostrService
        // For now, return empty array as placeholder
        return []
    }
}

// MARK: - Errors

enum StatsError: LocalizedError {
    case userNotAuthenticated
    case healthKitNotAuthorized
    case nostrConnectionFailed
    case dataProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .healthKitNotAuthorized:
            return "HealthKit access not authorized"
        case .nostrConnectionFailed:
            return "Failed to connect to Nostr relays"
        case .dataProcessingFailed:
            return "Failed to process workout data"
        }
    }
}