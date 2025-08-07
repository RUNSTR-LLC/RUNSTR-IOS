import SwiftUI

struct TeamDiscoveryView: View {
    @EnvironmentObject var teamService: TeamService
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var searchText = ""
    @State private var selectedActivityType: ActivityType?
    @State private var selectedActivityLevel: ActivityLevel?
    @State private var showingFilters = false
    @State private var showingTeamDetail: Team?
    
    private var filteredTeams: [Team] {
        var teams = teamService.teams
        
        // Filter by search text
        if !searchText.isEmpty {
            teams = teams.filter { team in
                team.name.localizedCaseInsensitiveContains(searchText) ||
                team.description.localizedCaseInsensitiveContains(searchText) ||
                team.location?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Filter by activity type
        if let activityType = selectedActivityType {
            teams = teams.filter { team in
                team.supportsActivity(activityType)
            }
        }
        
        // Filter by activity level
        if let activityLevel = selectedActivityLevel {
            teams = teams.filter { team in
                team.activityLevel == activityLevel
            }
        }
        
        return teams
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            headerSection
            
            // Teams list
            if teamService.isLoading && teamService.teams.isEmpty {
                loadingView
            } else if filteredTeams.isEmpty {
                emptyStateView
            } else {
                teamsListView
            }
        }
        .background(Color.runstrBackground)
        .sheet(isPresented: $showingFilters) {
            TeamFiltersView(
                selectedActivityType: $selectedActivityType,
                selectedActivityLevel: $selectedActivityLevel
            )
        }
        .sheet(item: $showingTeamDetail) { team in
            TeamDetailView(team: team)
        }
        .onAppear {
            Task {
                await teamService.fetchPublicTeams()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: RunstrSpacing.sm) {
            // Search Bar
            HStack(spacing: RunstrSpacing.sm) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.runstrGray)
                    
                    TextField("Search teams", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.runstrWhite)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.vertical, RunstrSpacing.sm)
                .background(Color.runstrDark)
                .cornerRadius(RunstrSpacing.sm)
                
                // Filter Button
                Button {
                    showingFilters = true
                } label: {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(hasActiveFilters ? .runstrWhite : .runstrGray)
                }
            }
            
            // Active Filters
            if hasActiveFilters {
                activeFiltersView
            }
            
            // Results Count
            HStack {
                Text("\(filteredTeams.count) teams found")
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
                
                Spacer()
                
                if teamService.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: .runstrWhite))
                }
            }
        }
        .padding(.horizontal, RunstrSpacing.md)
        .padding(.vertical, RunstrSpacing.sm)
        .background(Color.runstrBackground)
    }
    
    private var hasActiveFilters: Bool {
        selectedActivityType != nil || selectedActivityLevel != nil
    }
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RunstrSpacing.sm) {
                if let activityType = selectedActivityType {
                    FilterChip(
                        title: activityType.displayName,
                        systemImage: activityType.systemImageName
                    ) {
                        selectedActivityType = nil
                    }
                }
                
                if let activityLevel = selectedActivityLevel {
                    FilterChip(
                        title: activityLevel.displayName,
                        systemImage: "gauge"
                    ) {
                        selectedActivityLevel = nil
                    }
                }
            }
            .padding(.horizontal, RunstrSpacing.md)
        }
    }
    
    // MARK: - Teams List
    
    private var teamsListView: some View {
        ScrollView {
            LazyVStack(spacing: RunstrSpacing.md) {
                ForEach(filteredTeams) { team in
                    TeamCard(team: team) {
                        showingTeamDetail = team
                    }
                }
            }
            .padding(.horizontal, RunstrSpacing.md)
            .padding(.bottom, RunstrSpacing.xl)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: RunstrSpacing.lg) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .runstrWhite))
            
            Text("Loading teams...")
                .font(.runstrBody)
                .foregroundColor(.runstrGray)
            
            Spacer()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: RunstrSpacing.lg) {
            Spacer()
            
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.runstrGray)
            
            VStack(spacing: RunstrSpacing.sm) {
                Text("No teams found")
                    .font(.runstrTitle2)
                    .foregroundColor(.runstrWhite)
                
                Text("Try adjusting your search or filters")
                    .font(.runstrBody)
                    .foregroundColor(.runstrGray)
                    .multilineTextAlignment(.center)
            }
            
            if hasActiveFilters {
                Button("Clear Filters") {
                    selectedActivityType = nil
                    selectedActivityLevel = nil
                    searchText = ""
                }
                .buttonStyle(RunstrSecondaryButtonStyle())
            }
            
            Spacer()
        }
        .padding(.horizontal, RunstrSpacing.xl)
    }
}

// MARK: - Team Card

struct TeamCard: View {
    let team: Team
    let onTap: () -> Void
    
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var teamService: TeamService
    
    private var isUserMember: Bool {
        guard let userID = authService.currentUser?.id else { return false }
        return team.memberIDs.contains(userID)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: RunstrSpacing.md) {
                // Header with name and member count
                HStack {
                    VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                        Text(team.name)
                            .font(.runstrTitle3)
                            .foregroundColor(.runstrWhite)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: RunstrSpacing.xs) {
                            Image(systemName: "person.2.fill")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                            
                            Text("\(team.memberCount)/\(team.maxMembers) members")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                            
                            if let location = team.location {
                                Image(systemName: "location.fill")
                                    .font(.runstrCaption)
                                    .foregroundColor(.runstrGray)
                                
                                Text(location)
                                    .font(.runstrCaption)
                                    .foregroundColor(.runstrGray)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: RunstrSpacing.xs) {
                        if isUserMember {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.runstrWhite)
                        }
                        
                        Text(team.activityLevel.displayName)
                            .font(.runstrCaption)
                            .foregroundColor(.runstrWhite)
                            .fontWeight(.medium)
                    }
                }
                
                // Description
                Text(team.description)
                    .font(.runstrBody)
                    .foregroundColor(.runstrGray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Activity types
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RunstrSpacing.xs) {
                        ForEach(team.supportedActivityTypes.prefix(4), id: \.self) { activityType in
                            HStack(spacing: RunstrSpacing.xs) {
                                Image(systemName: activityType.systemImageName)
                                    .font(.runstrCaption)
                                
                                Text(activityType.displayName)
                                    .font(.runstrCaption)
                            }
                            .padding(.horizontal, RunstrSpacing.sm)
                            .padding(.vertical, RunstrSpacing.xs)
                            .background(Color.runstrDark)
                            .foregroundColor(.runstrWhite)
                            .cornerRadius(RunstrSpacing.xs)
                        }
                        
                        if team.supportedActivityTypes.count > 4 {
                            Text("+\(team.supportedActivityTypes.count - 4)")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                                .padding(.horizontal, RunstrSpacing.sm)
                        }
                    }
                }
            }
            .padding(RunstrSpacing.md)
        }
        .buttonStyle(PlainButtonStyle())
        .runstrCard()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let systemImage: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: RunstrSpacing.xs) {
            Image(systemName: systemImage)
                .font(.runstrCaption)
            
            Text(title)
                .font(.runstrCaption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.runstrCaption)
            }
        }
        .padding(.horizontal, RunstrSpacing.sm)
        .padding(.vertical, RunstrSpacing.xs)
        .background(Color.runstrWhite)
        .foregroundColor(.runstrBackground)
        .cornerRadius(RunstrSpacing.sm)
    }
}

// MARK: - Team Filters View

struct TeamFiltersView: View {
    @Binding var selectedActivityType: ActivityType?
    @Binding var selectedActivityLevel: ActivityLevel?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: RunstrSpacing.lg) {
                // Activity Type Filter
                VStack(alignment: .leading, spacing: RunstrSpacing.md) {
                    Text("Activity Type")
                        .font(.runstrTitle3)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: RunstrSpacing.sm) {
                            FilterOptionButton(
                                title: "All",
                                isSelected: selectedActivityType == nil
                            ) {
                                selectedActivityType = nil
                            }
                            
                            ForEach(ActivityType.allCases, id: \.self) { activityType in
                                FilterOptionButton(
                                    title: activityType.displayName,
                                    systemImage: activityType.systemImageName,
                                    isSelected: selectedActivityType == activityType
                                ) {
                                    selectedActivityType = selectedActivityType == activityType ? nil : activityType
                                }
                            }
                        }
                        .padding(.horizontal, RunstrSpacing.md)
                    }
                }
                
                // Activity Level Filter
                VStack(alignment: .leading, spacing: RunstrSpacing.md) {
                    Text("Activity Level")
                        .font(.runstrTitle3)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                    
                    VStack(spacing: RunstrSpacing.sm) {
                        FilterOptionButton(
                            title: "All Levels",
                            isSelected: selectedActivityLevel == nil
                        ) {
                            selectedActivityLevel = nil
                        }
                        
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            FilterOptionButton(
                                title: level.displayName,
                                subtitle: level.description,
                                isSelected: selectedActivityLevel == level
                            ) {
                                selectedActivityLevel = selectedActivityLevel == level ? nil : level
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(RunstrSpacing.md)
            .background(Color.runstrBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.runstrWhite)
                }
            }
        }
    }
}

// MARK: - Filter Option Button

struct FilterOptionButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, subtitle: String? = nil, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.runstrBody)
                        .foregroundColor(isSelected ? .runstrBackground : .runstrWhite)
                }
                
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.runstrBody)
                        .foregroundColor(isSelected ? .runstrBackground : .runstrWhite)
                        .fontWeight(.medium)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.runstrCaption)
                            .foregroundColor(isSelected ? .runstrBackground.opacity(0.8) : .runstrGray)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.runstrBackground)
                }
            }
            .padding(RunstrSpacing.md)
            .background(isSelected ? Color.runstrWhite : Color.runstrDark)
            .cornerRadius(RunstrSpacing.sm)
            .overlay(
                RoundedRectangle(cornerRadius: RunstrSpacing.sm)
                    .stroke(isSelected ? Color.runstrWhite : Color.runstrGray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TeamDiscoveryView()
        .environmentObject(TeamService())
        .environmentObject(AuthenticationService())
}