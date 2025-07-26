import SwiftUI

struct EventsView: View {
    @State private var selectedTab: EventTab = .discover
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(EventTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack(spacing: 8) {
                                Text(tab.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedTab == tab ? .orange : .gray)
                                
                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundColor(selectedTab == tab ? .orange : .clear)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .background(Color.black)
                
                // Content
                TabView(selection: $selectedTab) {
                    EventDiscoveryView()
                        .tag(EventTab.discover)
                    
                    MyEventsView()
                        .tag(EventTab.myEvents)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.black)
            .foregroundColor(.white)
        }
    }
}

enum EventTab: String, CaseIterable {
    case discover = "discover"
    case myEvents = "my_events"
    
    var displayName: String {
        switch self {
        case .discover: return "Discover"
        case .myEvents: return "My Events"
        }
    }
}

struct EventDiscoveryView: View {
    @State private var searchText = ""
    @State private var selectedDifficulty: EventDifficulty? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and filters
            VStack(spacing: 12) {
                SearchBar(text: $searchText)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button {
                            selectedDifficulty = nil
                        } label: {
                            Text("All")
                                .font(.subheadline)
                                .foregroundColor(selectedDifficulty == nil ? .black : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedDifficulty == nil ? Color.orange : Color.gray.opacity(0.3))
                                .cornerRadius(20)
                        }
                        
                        ForEach(EventDifficulty.allCases, id: \.self) { difficulty in
                            Button {
                                selectedDifficulty = difficulty
                            } label: {
                                Text(difficulty.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(selectedDifficulty == difficulty ? .black : .white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedDifficulty == difficulty ? Color.orange : Color.gray.opacity(0.3))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .background(Color.gray.opacity(0.1))
            
            // Events list
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(mockEvents) { event in
                        EventCard(event: event)
                    }
                }
                .padding()
            }
        }
    }
}

struct MyEventsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(mockEvents.prefix(2)) { event in
                    EventCard(event: event, showProgress: true)
                }
            }
            .padding()
        }
    }
}

struct EventCard: View {
    let event: MockEvent
    let showProgress: Bool
    
    init(event: MockEvent, showProgress: Bool = false) {
        self.event = event
        self.showProgress = showProgress
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(event.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(event.difficulty.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(event.difficulty.color))
                        .cornerRadius(8)
                    
                    Text("\(event.daysRemaining) days left")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Goal and prize
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(event.targetValue)) \(event.goalType.unit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Prize Pool")
                        .font(.caption)
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(event.prizePool)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            // Progress (if showing)
            if showProgress {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your Progress")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("\(Int(event.currentProgress))/\(Int(event.targetValue)) \(event.goalType.unit)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    ProgressView(value: event.currentProgress, total: event.targetValue)
                        .tint(.orange)
                }
            }
            
            // Participants and action button
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(event.participantCount) joined")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(showProgress ? "View Details" : "Join Event") {
                    // Handle event action
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct MockEvent: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let goalType: EventGoalType
    let targetValue: Double
    let difficulty: EventDifficulty
    let prizePool: Int
    let participantCount: Int
    let daysRemaining: Int
    let currentProgress: Double
}

let mockEvents = [
    MockEvent(
        name: "30-Day Distance Challenge",
        description: "Run or walk 100km in 30 days",
        goalType: .totalDistance,
        targetValue: 100,
        difficulty: .intermediate,
        prizePool: 100000,
        participantCount: 234,
        daysRemaining: 18,
        currentProgress: 45.2
    ),
    MockEvent(
        name: "Weekly Streak Master",
        description: "Complete workouts 7 days in a row",
        goalType: .streakDays,
        targetValue: 7,
        difficulty: .beginner,
        prizePool: 25000,
        participantCount: 892,
        daysRemaining: 5,
        currentProgress: 4
    ),
    MockEvent(
        name: "Sub-20 5K Challenge",
        description: "Run 5K under 20 minutes",
        goalType: .fastestTime,
        targetValue: 20,
        difficulty: .advanced,
        prizePool: 500000,
        participantCount: 67,
        daysRemaining: 12,
        currentProgress: 22.3
    )
]

#Preview {
    EventsView()
}