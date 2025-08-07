import SwiftUI

struct TeamsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var teamService: TeamService
    @State private var showingSettings = false
    @State private var showingTeamCreation = false
    @State private var showingWalletView = false
    @State private var selectedTab = 0
    @State private var selectedActivityType: ActivityType = .running
    
    // Mock wallet balance to match dashboard
    @State private var mockWalletBalance: Int = 2500
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with activity selector and settings
                headerSection
                
                // Tab selector
                tabSelectorSection
                
                // Main content
                TabView(selection: $selectedTab) {
                    // My Teams Tab
                    myTeamsView
                        .tag(0)
                    
                    // Discover Teams Tab
                    TeamDiscoveryView()
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingTeamCreation) {
            TeamCreationView()
        }
        .sheet(isPresented: $showingWalletView) {
            WalletView()
        }
        .onAppear {
            loadTeamData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // Activity selector
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
            
            // Create Team Button (for Captains/Organizations)
            if let user = authService.currentUser, teamService.canCreateTeam(user: user) {
                Button {
                    showingTeamCreation = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.runstrWhite)
                }
            }
            
            // Settings button
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
            }
        }
        .padding(.horizontal, RunstrSpacing.md)
        .padding(.top, RunstrSpacing.md)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelectorSection: some View {
        HStack(spacing: 0) {
            TabButton(title: "My Teams", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabButton(title: "Discover", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
        }
        .padding(.horizontal, RunstrSpacing.md)
        .padding(.top, RunstrSpacing.sm)
    }
    
    // MARK: - My Teams View
    
    private var myTeamsView: some View {
        Group {
            if teamService.isLoading && teamService.myTeams.isEmpty {
                loadingView
            } else if teamService.myTeams.isEmpty {
                myTeamsEmptyStateView
            } else {
                myTeamsListView
            }
        }
    }
    
    private var myTeamsListView: some View {
        ScrollView {
            LazyVStack(spacing: RunstrSpacing.md) {
                ForEach(teamService.myTeams) { team in
                    MyTeamCard(team: team)
                }
            }
            .padding(.horizontal, RunstrSpacing.md)
            .padding(.top, RunstrSpacing.md)
            .padding(.bottom, RunstrSpacing.xl)
        }
    }
    
    private var myTeamsEmptyStateView: some View {
        VStack(spacing: RunstrSpacing.lg) {
            Spacer()
            
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.runstrGray)
            
            VStack(spacing: RunstrSpacing.sm) {
                Text("No Teams Yet")
                    .font(.runstrTitle2)
                    .foregroundColor(.runstrWhite)
                
                Text("Join a team to connect with other fitness enthusiasts")
                    .font(.runstrBody)
                    .foregroundColor(.runstrGray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: RunstrSpacing.sm) {
                Button("Discover Teams") {
                    selectedTab = 1
                }
                .buttonStyle(RunstrPrimaryButtonStyle())
                
                if let user = authService.currentUser, teamService.canCreateTeam(user: user) {
                    Button("Create Team") {
                        showingTeamCreation = true
                    }
                    .buttonStyle(RunstrSecondaryButtonStyle())
                } else {
                    VStack(spacing: RunstrSpacing.xs) {
                        Text("Upgrade to Captain tier to create teams")
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
            
            Spacer()
        }
        .padding(.horizontal, RunstrSpacing.xl)
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
    
    // MARK: - Actions
    
    private func loadTeamData() {
        Task {
            if let user = authService.currentUser {
                // Load user's teams
                let _ = await teamService.fetchMyTeams(userID: user.id)
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: RunstrSpacing.xs) {
                Text(title)
                    .font(.runstrBody)
                    .foregroundColor(isSelected ? .runstrWhite : .runstrGray)
                    .fontWeight(isSelected ? .medium : .regular)
                
                Rectangle()
                    .fill(isSelected ? Color.runstrWhite : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - My Team Card

struct MyTeamCard: View {
    let team: Team
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingTeamDetail = false
    
    private var isUserCaptain: Bool {
        guard let userID = authService.currentUser?.id else { return false }
        return team.captainID == userID
    }
    
    var body: some View {
        Button {
            showingTeamDetail = true
        } label: {
            VStack(alignment: .leading, spacing: RunstrSpacing.md) {
                // Header with team name and role
                HStack {
                    VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                        Text(team.name)
                            .font(.runstrTitle3)
                            .foregroundColor(.runstrWhite)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: RunstrSpacing.sm) {
                            HStack(spacing: RunstrSpacing.xs) {
                                Image(systemName: isUserCaptain ? "crown.fill" : "person.circle.fill")
                                    .font(.runstrCaption)
                                    .foregroundColor(.runstrWhite)
                                
                                Text(isUserCaptain ? "Captain" : "Member")
                                    .font(.runstrCaption)
                                    .foregroundColor(.runstrWhite)
                                    .fontWeight(.medium)
                            }
                            
                            HStack(spacing: RunstrSpacing.xs) {
                                Image(systemName: "person.2.fill")
                                    .font(.runstrCaption)
                                    .foregroundColor(.runstrGray)
                                
                                Text("\(team.memberCount) members")
                                    .font(.runstrCaption)
                                    .foregroundColor(.runstrGray)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                // Team description
                Text(team.description)
                    .font(.runstrBody)
                    .foregroundColor(.runstrGray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Activity types
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RunstrSpacing.xs) {
                        ForEach(team.supportedActivityTypes.prefix(3), id: \.self) { activityType in
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
                    }
                }
                
                // Quick stats
                if isUserCaptain {
                    HStack {
                        HStack(spacing: RunstrSpacing.xs) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrWhite)
                            
                            Text("$\(team.memberCount - 1)/month")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrWhite)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Text("Captain earnings")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                }
            }
            .padding(RunstrSpacing.md)
        }
        .buttonStyle(PlainButtonStyle())
        .runstrCard()
        .sheet(isPresented: $showingTeamDetail) {
            TeamDetailView(team: team)
        }
    }
}

#Preview {
    TeamsView()
        .environmentObject(AuthenticationService())
        .environmentObject(TeamService())
}