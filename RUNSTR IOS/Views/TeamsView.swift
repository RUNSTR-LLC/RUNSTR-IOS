import SwiftUI

struct TeamsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var searchText = ""
    @State private var selectedFilter: TeamFilter = .all
    @State private var showingCreateTeam = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter bar
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TeamFilter.allCases, id: \.self) { filter in
                                FilterButton(
                                    title: filter.displayName,
                                    isSelected: selectedFilter == filter
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color.gray.opacity(0.1))
                
                // Teams list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(mockTeams.filter { team in
                            searchText.isEmpty || team.name.localizedCaseInsensitiveContains(searchText)
                        }) { team in
                            TeamCard(team: team)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Teams")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authService.currentUser?.subscriptionTier == .captain {
                        Button {
                            showingCreateTeam = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .background(Color.black)
            .foregroundColor(.white)
        }
        .sheet(isPresented: $showingCreateTeam) {
            CreateTeamView()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search teams...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color.gray.opacity(0.3))
                .cornerRadius(20)
        }
    }
}

struct TeamCard: View {
    let team: MockTeam
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(team.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(team.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(team.activityLevel.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            
            HStack {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly Distance")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(Int(team.weeklyDistance)) km")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Members")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(team.activeMembers)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
                
                Button("Join") {
                    // Handle join team
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

enum TeamFilter: String, CaseIterable {
    case all = "all"
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case competitive = "competitive"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .competitive: return "Competitive"
        }
    }
}

struct MockTeam: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let memberCount: Int
    let activityLevel: ActivityLevel
    let weeklyDistance: Double
    let activeMembers: Int
}

let mockTeams = [
    MockTeam(name: "Morning Runners", description: "Early bird runners who love sunrise workouts", memberCount: 85, activityLevel: .intermediate, weeklyDistance: 450, activeMembers: 72),
    MockTeam(name: "Weekend Warriors", description: "Casual runners who focus on weekend activities", memberCount: 156, activityLevel: .beginner, weeklyDistance: 280, activeMembers: 94),
    MockTeam(name: "Marathon Maniacs", description: "Serious runners training for marathons and ultras", memberCount: 43, activityLevel: .advanced, weeklyDistance: 890, activeMembers: 41),
    MockTeam(name: "Couch to 5K Club", description: "Beginners starting their running journey", memberCount: 234, activityLevel: .beginner, weeklyDistance: 120, activeMembers: 187)
]

struct CreateTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var teamName = ""
    @State private var teamDescription = ""
    @State private var selectedActivityLevel: ActivityLevel = .intermediate
    
    var body: some View {
        NavigationView {
            Form {
                Section("Team Details") {
                    TextField("Team Name", text: $teamName)
                    TextField("Description", text: $teamDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Activity Level") {
                    Picker("Activity Level", selection: $selectedActivityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text(selectedActivityLevel.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Create Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        // Handle team creation
                        dismiss()
                    }
                    .disabled(teamName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    TeamsView()
        .environmentObject(AuthenticationService())
}