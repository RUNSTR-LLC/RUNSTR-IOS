import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var statsService: StatsService?
    @State private var selectedTimeframe: TimeFrame = .week
    @State private var selectedMetric: StatsMetric = .distance
    @State private var selectedActivityType: ActivityType = .running
    @State private var showingWalletView = false
    @State private var showingSettingsView = false
    
    // Mock wallet balance to match dashboard
    @State private var mockWalletBalance: Int = 2500
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header with activity selector and settings
                    headerSection
                    
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
                    
                    Spacer(minLength: 100) // Bottom padding for tab bar
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
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
        .sheet(isPresented: $showingWalletView) {
            WalletView()
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsView()
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Dynamic activity selector
            Menu {
                ForEach(ActivityType.allCases, id: \.self) { activityType in
                    Button {
                        selectedActivityType = activityType
                    } label: {
                        HStack {
                            Image(systemName: activityType.systemImageName)
                            Text(activityType.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: RunstrSpacing.sm) {
                    Image(systemName: selectedActivityType.systemImageName)
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                    
                    Text(selectedActivityType.displayName.uppercased())
                        .font(.runstrCaption)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.down")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.vertical, RunstrSpacing.sm)
            }
            .runstrCard()
            
            Spacer()
            
            // Wallet balance button
            Button {
                showingWalletView = true
            } label: {
                Text("\(mockWalletBalance)")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.bold)
                    .padding(.horizontal, RunstrSpacing.md)
                    .padding(.vertical, RunstrSpacing.sm)
            }
            .runstrCard()
            
            // Settings button
            Button {
                showingSettingsView = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
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
                        .font(.runstrBody)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTimeframe == timeFrame ? .runstrBackground : .runstrWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RunstrSpacing.sm)
                        .background(selectedTimeframe == timeFrame ? Color.runstrWhite : Color.clear)
                }
            }
        }
        .background(Color.runstrGray.opacity(0.2))
        .cornerRadius(RunstrRadius.sm)
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
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.white)
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
                    .foregroundStyle(.white)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.displayName, dataPoint.value)
                    )
                    .foregroundStyle(.white.opacity(0.3))
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
                .runstrCard()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: RunstrRadius.md)
                        .fill(Color.runstrCardBackground)
                        .frame(height: 200)
                    
                    if statsService?.isLoading == true {
                        VStack {
                            ProgressView()
                            Text("Loading chart data...")
                                .font(.runstrBody)
                                .foregroundColor(.runstrGray)
                        }
                    } else {
                        VStack {
                            Text("📊")
                                .font(.system(size: 40))
                            Text("No data available")
                                .font(.runstrBody)
                                .foregroundColor(.runstrGray)
                            Text("Complete workouts to see your progress")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
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
                            icon: "bitcoinsign.circle.fill"
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
                    .foregroundColor(.white)
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
        VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.runstrWhite)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.runstrCaption)
                    Text(change)
                        .font(.runstrCaption)
                }
                .foregroundColor(isPositive ? .green : .red)
            }
            
            Text(value)
                .font(.runstrTitle2)
                .fontWeight(.bold)
                .foregroundColor(.runstrWhite)
            
            Text(title)
                .font(.runstrCaption)
                .foregroundColor(.runstrGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RunstrSpacing.md)
        .runstrCard()
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
                        .font(.runstrBody)
                        .fontWeight(.semibold)
                        .foregroundColor(.runstrWhite)
                    
                    if isNewRecord {
                        Text("NEW!")
                            .font(.runstrCaption)
                            .fontWeight(.bold)
                            .foregroundColor(.runstrWhite)
                            .padding(.horizontal, RunstrSpacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.runstrWhite.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(date)
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
            }
            
            Spacer()
            
            Text(time)
                .font(.runstrHeadline)
                .fontWeight(.bold)
                .foregroundColor(.runstrWhite)
                .monospacedDigit()
        }
        .padding(RunstrSpacing.md)
        .runstrCard()
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
                .font(.runstrBody)
                .foregroundColor(.runstrWhite)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RunstrSpacing.md)
        .runstrCard()
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
        case .warning: return .runstrWhite
        }
    }
}

#Preview {
    StatsView()
    .environmentObject(HealthKitService())
    .environmentObject(NostrService())
    .environmentObject(AuthenticationService())
}