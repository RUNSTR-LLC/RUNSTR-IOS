import Foundation
import HealthKit

// MARK: - Aggregated Statistics
struct AggregatedStats: Codable {
    let healthKitStats: HealthKitStats
    let nostrStats: NostrStats
    let combinedStats: CombinedStats
    let lastUpdated: Date
    
    init(healthKitStats: HealthKitStats, nostrStats: NostrStats) {
        self.healthKitStats = healthKitStats
        self.nostrStats = nostrStats
        self.combinedStats = CombinedStats(healthKit: healthKitStats, nostr: nostrStats)
        self.lastUpdated = Date()
    }
}

// MARK: - HealthKit Statistics
struct HealthKitStats: Codable {
    let totalDistance: Double // in meters
    let totalWorkouts: Int
    let averagePace: Double // min/km
    let totalCalories: Double
    let totalActiveTime: TimeInterval // in seconds
    let timeframeData: [TimeFrame: TimeframeStats]
    let chartData: [StatsMetric: [ChartDataPoint]]
    
    static let empty = HealthKitStats(
        totalDistance: 0,
        totalWorkouts: 0,
        averagePace: 0,
        totalCalories: 0,
        totalActiveTime: 0,
        timeframeData: [:],
        chartData: [:]
    )
}

// MARK: - Nostr Statistics
struct NostrStats: Codable {
    let eventsFromMainNpub: [NostrWorkoutEvent]
    let eventsFromRunstrNpub: [NostrWorkoutEvent]
    let eventsFromAdditionalNpubs: [NostrWorkoutEvent]
    let combinedEvents: [NostrWorkoutEvent]
    let totalSatsEarned: Int
    let eventsPublished: Int
    
    init(mainEvents: [NostrWorkoutEvent] = [], runstrEvents: [NostrWorkoutEvent] = [], additionalEvents: [NostrWorkoutEvent] = []) {
        self.eventsFromMainNpub = mainEvents
        self.eventsFromRunstrNpub = runstrEvents
        self.eventsFromAdditionalNpubs = additionalEvents
        self.combinedEvents = mainEvents + runstrEvents + additionalEvents
        self.totalSatsEarned = combinedEvents.reduce(0) { $0 + $1.satsEarned }
        self.eventsPublished = combinedEvents.count
    }
    
    static let empty = NostrStats()
}

// MARK: - Combined Statistics
struct CombinedStats: Codable {
    let totalDistance: Double // Combined HealthKit + Nostr
    let totalWorkouts: Int
    let averagePace: Double
    let totalCalories: Double
    let totalSatsEarned: Int
    let consistency: Double // Percentage of days with activity
    
    init(healthKit: HealthKitStats, nostr: NostrStats) {
        // Combine stats preferring HealthKit for accuracy
        self.totalDistance = max(healthKit.totalDistance, nostr.combinedEvents.reduce(0) { $0 + $1.distance })
        self.totalWorkouts = max(healthKit.totalWorkouts, nostr.eventsPublished)
        self.averagePace = healthKit.averagePace > 0 ? healthKit.averagePace : 
                         (nostr.combinedEvents.isEmpty ? 0 : 
                          nostr.combinedEvents.map { $0.averagePace }.reduce(0, +) / Double(nostr.combinedEvents.count))
        self.totalCalories = healthKit.totalCalories
        self.totalSatsEarned = nostr.totalSatsEarned
        
        // Calculate consistency based on workout frequency
        let daysWithActivity = Set(nostr.combinedEvents.map { 
            Calendar.current.startOfDay(for: $0.timestamp) 
        }).count
        let daysSinceStart = max(1, Calendar.current.dateInterval(of: .day, for: Date())?.duration ?? 86400)
        self.consistency = Double(daysWithActivity) / (daysSinceStart / 86400) * 100
    }
}

// MARK: - Timeframe Statistics
struct TimeframeStats: Codable {
    let distance: Double // in meters
    let workouts: Int
    let averagePace: Double // min/km
    let calories: Double
    let satsEarned: Int
    let activeTime: TimeInterval
    let improvement: Double // Percentage change from previous period
    
    static let empty = TimeframeStats(
        distance: 0,
        workouts: 0,
        averagePace: 0,
        calories: 0,
        satsEarned: 0,
        activeTime: 0,
        improvement: 0
    )
}

// MARK: - Chart Data
struct ChartDataPoint: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let metric: StatsMetric
    let npubSource: String? // Which npub this data came from
    
    private enum CodingKeys: String, CodingKey {
        case date, value, metric, npubSource
    }
}

// MARK: - Personal Records
struct PersonalRecord: Codable, Identifiable {
    let id = UUID()
    let activityType: ActivityType
    let recordType: RecordType
    let value: Double
    let unit: String
    let achievedDate: Date
    let location: String?
    let isNewRecord: Bool
    let previousRecord: Double?
    
    var formattedValue: String {
        switch recordType {
        case .fastestPace:
            return formatPace(value)
        case .longestDistance:
            return String(format: "%.2f km", value / 1000)
        case .longestDuration:
            return formatDuration(value)
        case .mostCalories:
            return String(format: "%.0f cal", value)
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case activityType, recordType, value, unit, achievedDate, location, isNewRecord, previousRecord
    }
}

enum RecordType: String, CaseIterable, Codable {
    case fastestPace = "fastest_pace"
    case longestDistance = "longest_distance"
    case longestDuration = "longest_duration"
    case mostCalories = "most_calories"
    
    var displayName: String {
        switch self {
        case .fastestPace: return "Fastest Pace"
        case .longestDistance: return "Longest Distance"
        case .longestDuration: return "Longest Duration"
        case .mostCalories: return "Most Calories"
        }
    }
}

// MARK: - AI Insights
struct AIInsight: Codable, Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let message: String
    let data: [String: Double] // Supporting data for the insight
    let actionable: Bool
    let priority: InsightPriority
    let generatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case type, title, message, data, actionable, priority, generatedAt
    }
}

enum InsightPriority: String, CaseIterable, Codable {
    case low, medium, high
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "orange"  
        case .high: return "red"
        }
    }
}

// MARK: - Stats Configuration
struct StatsConfiguration: Codable {
    var includeMainNpub: Bool = true
    var includeRunstrNpub: Bool = true
    var includeAdditionalNpubs: Bool = false
    var selectedNpubs: [String] = []
    var selectedTimeframe: TimeFrame = .week
    var selectedMetrics: [StatsMetric] = StatsMetric.allCases
    var enableAIInsights: Bool = true
    var privacyLevel: PrivacyLevel = .personal
    
    var allSelectedNpubs: [String] {
        var npubs: [String] = []
        if includeRunstrNpub { npubs.append("runstr") } // Placeholder
        if includeMainNpub { npubs.append("main") } // Placeholder
        if includeAdditionalNpubs { npubs.append(contentsOf: selectedNpubs) }
        return npubs
    }
}

enum PrivacyLevel: String, CaseIterable, Codable {
    case personal = "personal" // Only user can see
    case team = "team" // Team members can see aggregated stats
    case `public` = "public" // Anyone can see stats
    
    var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Extensions for TimeFrame
extension TimeFrame {
    var dateRange: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return DateInterval(start: startOfWeek, end: now)
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return DateInterval(start: startOfMonth, end: now)
        case .year:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return DateInterval(start: startOfYear, end: now)
        }
    }
    
    var chartDataPoints: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 12
        }
    }
}

// MARK: - Extensions for StatsMetric
extension StatsMetric {
    var unit: String {
        switch self {
        case .distance: return "km"
        case .pace: return "min/km"
        case .frequency: return "workouts"
        case .calories: return "cal"
        }
    }
    
    var chartColor: String {
        switch self {
        case .distance: return "blue"
        case .pace: return "green"
        case .frequency: return "orange"
        case .calories: return "red"
        }
    }
}