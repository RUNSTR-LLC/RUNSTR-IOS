import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var statsService: StatsService?
    @State private var selectedTimeframe: TimeFrame = .week
    @State private var selectedMetric: StatsMetric = .distance
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Time frame selector
                    timeFrameSelector
                    
                    // Main chart
                    mainChartSection
                    
                    // Summary cards
                    summaryCardsSection
                    
                    // Personal records
                    personalRecordsSection
                    
                    // AI insights from Coach Claude
                    coachInsightsSection
                }
                .padding()
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.black)
            .foregroundColor(.white)
            .onAppear {
                if statsService == nil {
                    statsService = StatsService(
                        healthKitService: healthKitService,
                        nostrService: nostrService,
                        authService: authService
                    )
                }
                Task {
                    await statsService?.fetchAllStats(for: selectedTimeframe)
                }
            }
            .onChange(of: selectedTimeframe) { newTimeframe in
                Task {
                    await statsService?.fetchAllStats(for: newTimeframe)
                    await statsService?.generateChartData(for: selectedMetric, timeframe: newTimeframe)
                }
            }
            .onChange(of: selectedMetric) { newMetric in
                Task {
                    await statsService?.generateChartData(for: newMetric, timeframe: selectedTimeframe)
                }
            }
        }
    }
    
    private var timeFrameSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                Button {
                    selectedTimeframe = timeFrame
                } label: {
                    Text(timeFrame.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTimeframe == timeFrame ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedTimeframe == timeFrame ? Color.orange : Color.clear)
                }
            }
        }
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var mainChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Performance Trends")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    ForEach(StatsMetric.allCases, id: \.self) { metric in
                        Button(metric.displayName) {
                            selectedMetric = metric
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedMetric.displayName)
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Real chart using Swift Charts
            if let chartData = statsService?.chartData[selectedMetric], !chartData.isEmpty {
                Chart(chartData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.displayName, dataPoint.value)
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.displayName, dataPoint.value)
                    )
                    .foregroundStyle(.orange.opacity(0.3))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel() {
                            if let doubleValue = value.as(Double.self) {
                                Text(formatChartValue(doubleValue, metric: selectedMetric))
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel() {
                            if let dateValue = value.as(Date.self) {
                                Text(formatChartDate(dateValue, timeframe: selectedTimeframe))
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.1))
                )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                    
                    if statsService?.isLoading == true {
                        VStack {
                            ProgressView()
                            Text("Loading chart data...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    } else {
                        VStack {
                            Text("📊")
                                .font(.system(size: 40))
                            Text("No data available")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Complete workouts to see your progress")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }
    
    private var summaryCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This \(selectedTimeframe.displayName)")
                .font(.headline)
                .fontWeight(.bold)
            
            if statsService?.isLoading == true {
                HStack {
                    ProgressView()
                    Text("Loading stats...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if let stats = statsService?.aggregatedStats,
                      let timeframeStats = stats.healthKitStats.timeframeData[selectedTimeframe] {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        SummaryCard(
                            title: "Total Distance",
                            value: String(format: "%.1f km", timeframeStats.distance / 1000),
                            change: String(format: "%+.1f%%", timeframeStats.improvement),
                            isPositive: timeframeStats.improvement >= 0,
                            icon: "figure.run"
                        )
                        
                        SummaryCard(
                            title: "Workouts",
                            value: "\(timeframeStats.workouts)",
                            change: timeframeStats.workouts > 0 ? "+\(timeframeStats.workouts)" : "0",
                            isPositive: timeframeStats.workouts > 0,
                            icon: "timer"
                        )
                    }
                    
                    HStack(spacing: 12) {
                        SummaryCard(
                            title: "Avg Pace",
                            value: timeframeStats.averagePace > 0 ? formatPace(timeframeStats.averagePace) : "--",
                            change: timeframeStats.averagePace > 0 ? "Good" : "--",
                            isPositive: timeframeStats.averagePace > 0,
                            icon: "speedometer"
                        )
                        
                        SummaryCard(
                            title: "Sats Earned",
                            value: "\(timeframeStats.satsEarned)",
                            change: timeframeStats.satsEarned > 0 ? "+\(timeframeStats.satsEarned)" : "0",
                            isPositive: timeframeStats.satsEarned > 0,
                            icon: "bitcoinsign.circle"
                        )
                    }
                }
            } else {
                Text("No data available for this timeframe")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
    }
    
    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Records")
                .font(.headline)
                .fontWeight(.bold)
            
            if statsService?.personalRecords.isEmpty != false {
                if statsService?.isLoading == true {
                    ProgressView("Loading records...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "trophy")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No personal records yet")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("Complete more workouts to see your records")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(statsService?.personalRecords.keys ?? Dictionary<ActivityType, [PersonalRecord]>().keys), id: \.self) { activityType in
                        if let records = statsService?.personalRecords[activityType],
                           let bestRecord = records.first {
                            PersonalRecordRow(
                                activity: "\(activityType.displayName) - \(bestRecord.recordType.displayName)",
                                time: bestRecord.formattedValue,
                                date: formatRelativeDate(bestRecord.achievedDate),
                                isNewRecord: bestRecord.isNewRecord
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var coachInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.orange)
                Text("Coach Claude Insights")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            if statsService?.aiInsights.isEmpty != false {
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No insights available")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Complete more workouts to get personalized insights")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(statsService?.aiInsights ?? []) { insight in
                        InsightCard(
                            insight: insight.message,
                            type: mapInsightType(insight.type)
                        )
                    }
                }
            }
        }
    }
    
    // Helper functions
    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func mapInsightType(_ type: InsightType) -> InsightType {
        // Map from StatsModels.InsightType to local InsightType
        return type
    }
    
    private func formatChartValue(_ value: Double, metric: StatsMetric) -> String {
        switch metric {
        case .distance:
            return String(format: "%.1f km", value)
        case .pace:
            return formatPace(value)
        case .frequency:
            return String(format: "%.0f", value)
        case .calories:
            return String(format: "%.0f cal", value)
        }
    }
    
    private func formatChartDate(_ date: Date, timeframe: TimeFrame) -> String {
        let formatter = DateFormatter()
        switch timeframe {
        case .week:
            formatter.dateFormat = "E" // Mon, Tue, etc.
        case .month:
            formatter.dateFormat = "d" // 1, 2, 3, etc.
        case .year:
            formatter.dateFormat = "MMM" // Jan, Feb, etc.
        }
        return formatter.string(from: date)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.caption)
                    Text(change)
                        .font(.caption)
                }
                .foregroundColor(isPositive ? .green : .red)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct PersonalRecordRow: View {
    let activity: String
    let time: String
    let date: String
    let isNewRecord: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if isNewRecord {
                        Text("NEW!")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(time)
                .font(.headline)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct InsightCard: View {
    let insight: String
    let type: InsightType
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(type.color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            Text(insight)
                .font(.subheadline)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

enum TimeFrame: String, CaseIterable, Codable {
    case week = "week"
    case month = "month"
    case year = "year"
    
    var displayName: String {
        return self.rawValue.capitalized
    }
}

enum StatsMetric: String, CaseIterable, Codable {
    case distance = "distance"
    case pace = "pace"
    case frequency = "frequency"
    case calories = "calories"
    
    var displayName: String {
        switch self {
        case .distance: return "Distance"
        case .pace: return "Pace"
        case .frequency: return "Frequency"
        case .calories: return "Calories"
        }
    }
}

enum InsightType: Codable {
    case positive
    case tip
    case warning
    
    var color: Color {
        switch self {
        case .positive: return .green
        case .tip: return .blue
        case .warning: return .orange
        }
    }
}

#Preview {
    StatsView()
    .environmentObject(HealthKitService())
    .environmentObject(NostrService())
    .environmentObject(AuthenticationService())
}