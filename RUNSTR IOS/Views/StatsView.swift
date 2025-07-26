import SwiftUI
import Charts

struct StatsView: View {
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
            
            // Mock chart - in real implementation, use Swift Charts
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                
                VStack {
                    Text("📈")
                        .font(.system(size: 40))
                    Text("Chart showing \(selectedMetric.displayName.lowercased())")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("over the past \(selectedTimeframe.displayName.lowercased())")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var summaryCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This \(selectedTimeframe.displayName)")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    SummaryCard(
                        title: "Total Distance",
                        value: "47.3 km",
                        change: "+12%",
                        isPositive: true,
                        icon: "figure.run"
                    )
                    
                    SummaryCard(
                        title: "Workouts",
                        value: "8",
                        change: "+2",
                        isPositive: true,
                        icon: "timer"
                    )
                }
                
                HStack(spacing: 12) {
                    SummaryCard(
                        title: "Avg Pace",
                        value: "5:42 /km",
                        change: "-0:15",
                        isPositive: true,
                        icon: "speedometer"
                    )
                    
                    SummaryCard(
                        title: "Sats Earned",
                        value: "2,450",
                        change: "+18%",
                        isPositive: true,
                        icon: "bitcoinsign.circle"
                    )
                }
            }
        }
    }
    
    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Records")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                PersonalRecordRow(
                    activity: "5K Run",
                    time: "19:42",
                    date: "2 days ago",
                    isNewRecord: true
                )
                
                PersonalRecordRow(
                    activity: "10K Run",
                    time: "42:15",
                    date: "1 week ago",
                    isNewRecord: false
                )
                
                PersonalRecordRow(
                    activity: "Longest Run",
                    time: "1:23:45 (15.2 km)",
                    date: "3 weeks ago",
                    isNewRecord: false
                )
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
            
            VStack(alignment: .leading, spacing: 12) {
                InsightCard(
                    insight: "🎯 You're 85% likely to hit your monthly distance goal at your current pace!",
                    type: .positive
                )
                
                InsightCard(
                    insight: "⚡ Your Tuesday morning runs are 12% faster than average. Consider scheduling important workouts then.",
                    type: .tip
                )
                
                InsightCard(
                    insight: "🛡️ You've increased weekly distance by 20% - consider a recovery week to prevent injury.",
                    type: .warning
                )
            }
        }
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

enum TimeFrame: String, CaseIterable {
    case week = "week"
    case month = "month"
    case year = "year"
    
    var displayName: String {
        return self.rawValue.capitalized
    }
}

enum StatsMetric: String, CaseIterable {
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

enum InsightType {
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
}