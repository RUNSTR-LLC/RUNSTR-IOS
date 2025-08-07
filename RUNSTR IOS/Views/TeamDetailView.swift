import SwiftUI

struct TeamDetailView: View {
    let team: Team
    
    @EnvironmentObject var teamService: TeamService
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTab = 0
    @State private var showingJoinAlert = false
    @State private var showingLeaveAlert = false
    @State private var isProcessing = false
    
    private var isUserMember: Bool {
        guard let userID = authService.currentUser?.id else { return false }
        return team.memberIDs.contains(userID)
    }
    
    private var canJoinTeam: Bool {
        guard let user = authService.currentUser else { return false }
        return teamService.canJoinTeam(user: user) && !isUserMember && team.memberCount < team.maxMembers
    }
    
    private var isUserCaptain: Bool {
        guard let userID = authService.currentUser?.id else { return false }
        return team.captainID == userID
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tab Picker
                tabPickerSection
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Overview Tab
                    teamOverviewView
                        .tag(0)
                    
                    // Members Tab  
                    teamMembersView
                        .tag(1)
                    
                    // Chat Tab
                    if isUserMember {
                        teamChatView
                            .tag(2)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .alert("Join Team", isPresented: $showingJoinAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Join") { joinTeam() }
        } message: {
            Text("Do you want to join \(team.name)?")
        }
        .alert("Leave Team", isPresented: $showingLeaveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) { leaveTeam() }
        } message: {
            Text("Are you sure you want to leave \(team.name)?")
        }
        .onAppear {
            loadTeamData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: RunstrSpacing.md) {
            // Navigation Bar
            HStack {
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.runstrWhite)
                
                Spacer()
                
                if isUserCaptain {
                    Button("Manage") {
                        // Navigate to team management
                    }
                    .foregroundColor(.runstrWhite)
                }
            }
            
            // Team Info
            VStack(spacing: RunstrSpacing.sm) {
                Text(team.name)
                    .font(.runstrTitle)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: RunstrSpacing.lg) {
                    HStack(spacing: RunstrSpacing.xs) {
                        Image(systemName: "person.2.fill")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                        
                        Text("\(team.memberCount)/\(team.maxMembers)")
                            .font(.runstrBody)
                            .foregroundColor(.runstrWhite)
                    }
                    
                    HStack(spacing: RunstrSpacing.xs) {
                        Image(systemName: "gauge")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                        
                        Text(team.activityLevel.displayName)
                            .font(.runstrBody)
                            .foregroundColor(.runstrWhite)
                    }
                    
                    if let location = team.location {
                        HStack(spacing: RunstrSpacing.xs) {
                            Image(systemName: "location.fill")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                            
                            Text(location)
                                .font(.runstrBody)
                                .foregroundColor(.runstrWhite)
                        }
                    }
                }
            }
            
            // Join/Leave Button
            if isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .runstrWhite))
                    
                    Text("Processing...")
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                }
            } else if isUserMember {
                if !isUserCaptain {
                    Button("Leave Team") {
                        showingLeaveAlert = true
                    }
                    .buttonStyle(RunstrSecondaryButtonStyle())
                }
            } else if canJoinTeam {
                Button("Join Team") {
                    showingJoinAlert = true
                }
                .buttonStyle(RunstrPrimaryButtonStyle())
            } else if team.memberCount >= team.maxMembers {
                Text("Team Full")
                    .font(.runstrBody)
                    .foregroundColor(.runstrGray)
                    .padding()
            } else {
                VStack(spacing: RunstrSpacing.xs) {
                    Text("Upgrade to Member tier to join teams")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                        .multilineTextAlignment(.center)
                    
                    Button("Upgrade Now") {
                        // Navigate to subscription
                    }
                    .buttonStyle(RunstrSecondaryButtonStyle())
                }
            }
        }
        .padding(.horizontal, RunstrSpacing.md)
        .padding(.vertical, RunstrSpacing.sm)
    }
    
    // MARK: - Tab Picker
    
    private var tabPickerSection: some View {
        HStack(spacing: 0) {
            TabButton(title: "Overview", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabButton(title: "Members", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            if isUserMember {
                TabButton(title: "Chat", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
        }
        .padding(.horizontal, RunstrSpacing.md)
        .background(Color.runstrBackground)
    }
    
    // MARK: - Team Overview
    
    private var teamOverviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RunstrSpacing.lg) {
                // Description
                VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                    Text("About")
                        .font(.runstrTitle3)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                    
                    Text(team.description)
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                }
                .runstrCard()
                
                // Supported Activities
                VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                    Text("Activities")
                        .font(.runstrTitle3)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RunstrSpacing.sm) {
                        ForEach(team.supportedActivityTypes, id: \.self) { activityType in
                            HStack {
                                Image(systemName: activityType.systemImageName)
                                    .font(.runstrBody)
                                    .foregroundColor(.runstrWhite)
                                
                                Text(activityType.displayName)
                                    .font(.runstrBody)
                                    .foregroundColor(.runstrWhite)
                                
                                Spacer()
                            }
                        }
                    }
                }
                .runstrCard()
                
                // Team Stats (if member)
                if isUserMember {
                    teamStatsView
                }
                
                Spacer(minLength: RunstrSpacing.xl)
            }
            .padding(.horizontal, RunstrSpacing.md)
        }
    }
    
    private var teamStatsView: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
            Text("Team Stats")
                .font(.runstrTitle3)
                .foregroundColor(.runstrWhite)
                .fontWeight(.medium)
            
            if let stats = teamService.teamStats[team.id] {
                VStack(spacing: RunstrSpacing.md) {
                    HStack {
                        TeamStatCard(
                            title: "Total Distance",
                            value: String(format: "%.1f km", stats.totalDistance / 1000),
                            icon: "figure.run"
                        )
                        
                        TeamStatCard(
                            title: "Workouts",
                            value: "\(stats.totalWorkouts)",
                            icon: "bolt.fill"
                        )
                    }
                    
                    HStack {
                        TeamStatCard(
                            title: "Active Members",
                            value: "\(stats.activeMembers)",
                            icon: "person.2.fill"
                        )
                        
                        TeamStatCard(
                            title: "Avg/Member",
                            value: String(format: "%.1f", stats.averageWorkoutsPerMember),
                            icon: "chart.bar.fill"
                        )
                    }
                }
            } else {
                Text("Loading stats...")
                    .font(.runstrBody)
                    .foregroundColor(.runstrGray)
            }
        }
        .runstrCard()
    }
    
    // MARK: - Team Members
    
    private var teamMembersView: some View {
        ScrollView {
            LazyVStack(spacing: RunstrSpacing.sm) {
                ForEach(team.memberIDs, id: \.self) { memberID in
                    TeamMemberRow(
                        memberID: memberID,
                        isCaptain: memberID == team.captainID,
                        isCurrentUser: memberID == authService.currentUser?.id
                    )
                }
            }
            .padding(.horizontal, RunstrSpacing.md)
            .padding(.bottom, RunstrSpacing.xl)
        }
    }
    
    // MARK: - Team Chat
    
    private var teamChatView: some View {
        TeamChatView(team: team)
    }
    
    // MARK: - Actions
    
    private func loadTeamData() {
        Task {
            // Load team stats
            let _ = await teamService.fetchTeamStats(teamID: team.id)
            
            // Load chat messages if member
            if isUserMember {
                let _ = await teamService.fetchTeamMessages(teamID: team.id)
            }
        }
    }
    
    private func joinTeam() {
        guard let userID = authService.currentUser?.id else { return }
        
        isProcessing = true
        
        Task {
            let result = await teamService.joinTeam(teamID: team.id, userID: userID)
            
            await MainActor.run {
                isProcessing = false
                // The UI will automatically update via @Published properties
            }
        }
    }
    
    private func leaveTeam() {
        guard let userID = authService.currentUser?.id else { return }
        
        isProcessing = true
        
        Task {
            let result = await teamService.leaveTeam(teamID: team.id, userID: userID)
            
            await MainActor.run {
                isProcessing = false
                
                switch result {
                case .success(_):
                    presentationMode.wrappedValue.dismiss()
                case .failure(_):
                    // Error handling is done by teamService
                    break
                }
            }
        }
    }
}

// TabButton is defined in TeamsView.swift and shared

// MARK: - Team Stat Card

struct TeamStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: RunstrSpacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.runstrWhite)
            
            Text(value)
                .font(.runstrTitle3)
                .foregroundColor(.runstrWhite)
                .fontWeight(.medium)
            
            Text(title)
                .font(.runstrCaption)
                .foregroundColor(.runstrGray)
                .multilineTextAlignment(.center)
        }
        .padding(RunstrSpacing.md)
        .frame(maxWidth: .infinity)
        .background(Color.runstrDark)
        .cornerRadius(RunstrSpacing.sm)
    }
}

// MARK: - Team Member Row

struct TeamMemberRow: View {
    let memberID: String
    let isCaptain: Bool
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: RunstrSpacing.md) {
            // Avatar placeholder
            Circle()
                .fill(Color.runstrDark)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(memberID.prefix(2).uppercased())
                        .font(.runstrCaption)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                )
            
            // Member info
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Text(memberID.prefix(8) + "...")
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                    
                    if isCaptain {
                        Image(systemName: "crown.fill")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrWhite)
                    }
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                }
                
                Text(isCaptain ? "Team Captain" : "Member")
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
            }
            
            Spacer()
            
            // Member stats placeholder
            VStack(alignment: .trailing, spacing: RunstrSpacing.xs) {
                Text("--")
                    .font(.runstrBody)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.medium)
                
                Text("workouts")
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
            }
        }
        .padding(RunstrSpacing.md)
        .background(Color.runstrDark)
        .cornerRadius(RunstrSpacing.sm)
    }
}

#Preview {
    let sampleTeam = Team(
        name: "Morning Runners",
        description: "Early bird runners who love to start the day with a good workout. We meet virtually and share our progress!",
        captainID: "captain123",
        activityLevel: .intermediate,
        maxMembers: 50,
        teamType: "running_club",
        location: "San Francisco",
        supportedActivityTypes: [.running, .walking]
    )
    
    return TeamDetailView(team: sampleTeam)
        .environmentObject(TeamService())
        .environmentObject(AuthenticationService())
}