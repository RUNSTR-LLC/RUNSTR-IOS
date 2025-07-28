import SwiftUI

struct TeamsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @State private var searchText = ""
    @State private var selectedFilter: TeamFilter = .all
    @State private var selectedTeamType: TeamTypeFilter = .all
    @State private var selectedLocation = ""
    @State private var showingCreateTeam = false
    @State private var showingFilters = false
    @State private var showingRecommended = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced search and filter bar
                VStack(spacing: 12) {
                    SearchBar(text: $searchText, placeholder: "Search teams, locations...")
                    
                    // Main filter tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Recommended button
                            FilterButton(
                                title: "For You",
                                isSelected: showingRecommended,
                                color: .blue
                            ) {
                                showingRecommended.toggle()
                                if showingRecommended {
                                    Task {
                                        await loadRecommendedTeams()
                                    }
                                }
                            }
                            
                            ForEach(TeamFilter.allCases, id: \.self) { filter in
                                FilterButton(
                                    title: filter.displayName,
                                    isSelected: selectedFilter == filter && !showingRecommended
                                ) {
                                    showingRecommended = false
                                    selectedFilter = filter
                                    Task {
                                        await applyFilters()
                                    }
                                }
                            }
                            
                            // Advanced filters button
                            FilterButton(
                                title: "Filters",
                                isSelected: showingFilters,
                                color: .gray
                            ) {
                                showingFilters = true
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Active filters display
                    if !selectedLocation.isEmpty || selectedTeamType != .all {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if !selectedLocation.isEmpty {
                                    ActiveFilterChip(title: "📍 \(selectedLocation)") {
                                        selectedLocation = ""
                                        Task { await applyFilters() }
                                    }
                                }
                                if selectedTeamType != .all {
                                    ActiveFilterChip(title: selectedTeamType.displayName) {
                                        selectedTeamType = .all
                                        Task { await applyFilters() }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
                .background(Color.gray.opacity(0.1))
                
                // Teams list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if nostrService.isLoadingTeams {
                            ProgressView("Loading teams...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 50)
                        } else if filteredTeams.isEmpty {
                            EmptyTeamsView(isFiltered: isFiltered)
                        } else {
                            ForEach(filteredTeams) { team in
                                EnhancedTeamCard(team: team)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(showingRecommended ? "Recommended" : "Teams")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Search by location button
                    Button {
                        // TODO: Implement location search
                    } label: {
                        Image(systemName: "location")
                            .foregroundColor(.orange)
                    }
                    
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
        .sheet(isPresented: $showingFilters) {
            AdvancedFiltersView(
                selectedTeamType: $selectedTeamType,
                selectedLocation: $selectedLocation,
                onApply: {
                    showingFilters = false
                    Task { await applyFilters() }
                }
            )
        }
        .onAppear {
            Task {
                await nostrService.fetchAvailableTeams()
            }
        }
        .onChange(of: searchText) { _ in
            Task {
                await performSearch()
            }
        }
    }
    
    private var filteredTeams: [Team] {
        var teams = nostrService.availableTeams
        
        // Apply search filter
        if !searchText.isEmpty {
            teams = teams.filter { team in
                team.name.localizedCaseInsensitiveContains(searchText) ||
                team.description.localizedCaseInsensitiveContains(searchText) ||
                team.location?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Apply activity level filter (if not showing recommended)
        if !showingRecommended && selectedFilter.activityLevel != nil {
            teams = teams.filter { $0.activityLevel == selectedFilter.activityLevel }
        }
        
        // Apply team type filter
        if selectedTeamType != .all {
            teams = teams.filter { $0.teamType == selectedTeamType.rawValue }
        }
        
        // Apply location filter
        if !selectedLocation.isEmpty {
            teams = teams.filter { 
                $0.location?.localizedCaseInsensitiveContains(selectedLocation) == true 
            }
        }
        
        return teams
    }
    
    private var isFiltered: Bool {
        !searchText.isEmpty || selectedFilter != .all || selectedTeamType != .all || !selectedLocation.isEmpty || showingRecommended
    }
    
    // MARK: - Helper Methods
    
    private func loadRecommendedTeams() async {
        guard let currentUser = authService.currentUser else { return }
        let recommendedTeams = await nostrService.getRecommendedTeams(for: currentUser)
        // TODO: Update UI to show only recommended teams
        print("📝 Loaded \(recommendedTeams.count) recommended teams")
    }
    
    private func applyFilters() async {
        let activityLevel = selectedFilter.activityLevel
        let location = selectedLocation.isEmpty ? nil : selectedLocation
        let teamType = selectedTeamType == .all ? nil : selectedTeamType.rawValue
        
        let filteredTeams = await nostrService.fetchTeamsWithFilters(
            activityLevel: activityLevel,
            location: location,
            teamType: teamType
        )
        
        print("📝 Applied filters, found \(filteredTeams.count) teams")
    }
    
    private func performSearch() async {
        if !searchText.isEmpty {
            let searchResults = await nostrService.searchTeams(query: searchText)
            print("📝 Search for '\(searchText)' returned \(searchResults.count) results")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    init(text: Binding<String>, placeholder: String = "Search teams...") {
        self._text = text
        self.placeholder = placeholder
    }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
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
    let color: Color
    let action: () -> Void
    
    init(title: String, isSelected: Bool, color: Color = .orange, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color.gray.opacity(0.3))
                .cornerRadius(20)
        }
    }
}

struct ActiveFilterChip: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.8))
        .cornerRadius(16)
    }
}

struct EmptyTeamsView: View {
    let isFiltered: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isFiltered ? "magnifyingglass" : "person.3")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(isFiltered ? "No teams found" : "No teams available")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(isFiltered ? "Try adjusting your filters or search terms" : "Be the first to create a team!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
    }
}

struct EnhancedTeamCard: View {
    let team: Team
    @EnvironmentObject var nostrService: NostrService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(team.name)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Team type badge
                        Text(team.teamType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(8)
                    }
                    
                    Text(team.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    // Location if available
                    if let location = team.location {
                        HStack {
                            Image(systemName: "location")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
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
                        Text("Total Distance")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(Int(team.stats.totalDistance/1000)) km")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Workouts")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(team.stats.totalWorkouts)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avg per Member")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f", team.stats.averageWorkoutsPerMember))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
                
                Button("Join") {
                    Task {
                        // Use the enhanced Nostr-enabled joining method
                        let success = await nostrService.joinTeamWithNostrUpdate(team.id)
                        if !success {
                            // Fallback to basic join if Nostr update fails
                            await nostrService.joinTeam(team.id)
                        }
                    }
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

struct TeamCard: View {
    let team: Team
    @EnvironmentObject var nostrService: NostrService
    
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
                        Text("Total Distance")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(Int(team.stats.totalDistance/1000)) km")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Workouts")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(team.stats.totalWorkouts)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
                
                Button("Join") {
                    Task {
                        // Use the enhanced Nostr-enabled joining method
                        let success = await nostrService.joinTeamWithNostrUpdate(team.id)
                        if !success {
                            // Fallback to basic join if Nostr update fails
                            await nostrService.joinTeam(team.id)
                        }
                    }
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
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
    
    var activityLevel: ActivityLevel? {
        switch self {
        case .all: return nil
        case .beginner: return .beginner
        case .intermediate: return .intermediate
        case .advanced: return .advanced
        }
    }
}

enum TeamTypeFilter: String, CaseIterable {
    case all = "all"
    case runningClub = "running_club"
    case cyclingGroup = "cycling_group"
    case mixedFitness = "mixed_fitness"
    case walkingGroup = "walking_group"
    
    var displayName: String {
        switch self {
        case .all: return "All Types"
        case .runningClub: return "🏃‍♂️ Running"
        case .cyclingGroup: return "🚴‍♂️ Cycling"
        case .mixedFitness: return "🏋️‍♂️ Mixed"
        case .walkingGroup: return "🚶‍♂️ Walking"
        }
    }
}

struct AdvancedFiltersView: View {
    @Binding var selectedTeamType: TeamTypeFilter
    @Binding var selectedLocation: String
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Team Type") {
                    Picker("Team Type", selection: $selectedTeamType) {
                        ForEach(TeamTypeFilter.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                
                Section("Location") {
                    TextField("Enter city or region", text: $selectedLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Filter teams by their location")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}


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