import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var nostrService: NostrService
    @State private var showingSettings = false
    @State private var showingWalletView = false
    @State private var statsService: StatsService?
    @State private var isLoading = false
    @State private var selectedActivity: ActivityType = .running
    
    // Mock wallet balance to match dashboard
    @State private var mockWalletBalance: Int = 2500
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header with activity selector and settings
                    headerSection
                    
                    if let user = authService.currentUser {
                        // Profile info section
                        profileInfoSection(user: user)
                        
                        // Key stats overview cards
                        keyStatsSection(user: user)
                        
                        // Weekly progress section
                        weeklyProgressSection(user: user)
                        
                        // Personal records section
                        personalRecordsSection()
                        
                        // Recent activity section
                        recentActivitySection()
                    } else {
                        // Not logged in state
                        VStack(spacing: RunstrSpacing.md) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.runstrGray)
                            
                            Text("Sign in to view your profile")
                                .font(.runstrHeadline)
                                .foregroundColor(.runstrWhite)
                        }
                        .padding(.top, RunstrSpacing.xxl)
                    }
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingWalletView) {
            WalletView()
        }
        .onAppear {
            if statsService == nil {
                statsService = StatsService(
                    healthKitService: healthKitService,
                    nostrService: nostrService,
                    authService: authService
                )
            }
            Task {
                await statsService?.fetchPersonalRecords()
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Dynamic activity selector
            Menu {
                ForEach(ActivityType.allCases, id: \.self) { activityType in
                    Button {
                        selectedActivity = activityType
                    } label: {
                        HStack {
                            Image(systemName: activityType.systemImageName)
                            Text(activityType.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: RunstrSpacing.sm) {
                    Image(systemName: selectedActivity.systemImageName)
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                    
                    Text(selectedActivity.displayName.uppercased())
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
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
            }
        }
    }
    
    // MARK: - Profile Info Section
    private func profileInfoSection(user: User) -> some View {
        VStack(spacing: RunstrSpacing.md) {
            // Profile picture and name
            HStack(spacing: RunstrSpacing.md) {
                // Profile picture
                if let profilePicture = user.profile.profilePicture, !profilePicture.isEmpty {
                    AsyncImage(url: URL(string: profilePicture)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.runstrGray)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.runstrGray)
                }
                
                VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                    // Display name
                    Text(user.profile.displayName.isEmpty ? "RUNSTR User" : user.profile.displayName)
                        .font(.runstrHeadline)
                        .foregroundColor(.runstrWhite)
                    
                    // Subscription tier
                    HStack(spacing: RunstrSpacing.xs) {
                        Text(user.subscriptionTier.displayName)
                            .font(.runstrCaptionMedium)
                            .foregroundColor(user.subscriptionTier == .none ? .runstrGray : .runstrAccent)
                        
                        // NIP-05 verification badge
                        if let nip05 = user.profile.nip05, !nip05.isEmpty {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.runstrSmall)
                                .foregroundColor(.runstrAccent)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Bio if available
            if !user.profile.about.isEmpty {
                Text(user.profile.about)
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(RunstrSpacing.md)
        .runstrCard()
    }
    
    // MARK: - Key Stats Section
    private func keyStatsSection(user: User) -> some View {
        VStack(spacing: RunstrSpacing.md) {
            HStack {
                Text("Your Stats")
                    .font(.runstrHeadline)
                    .foregroundColor(.runstrWhite)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: RunstrSpacing.md) {
                // Total Distance
                ProfileStatCard(
                    title: "Total Distance",
                    value: user.stats.formattedTotalDistance
                )
                
                // Total Workouts
                ProfileStatCard(
                    title: "Total Workouts",
                    value: "\(user.stats.totalWorkouts)"
                )
                
                // Current Streak
                ProfileStatCard(
                    title: "Current Streak",
                    value: "\(user.stats.currentStreak) days"
                )
                
                // Total Sats Earned
                ProfileStatCard(
                    title: "Sats Earned",
                    value: "\(user.stats.totalSatsEarned)"
                )
            }
        }
        .padding(RunstrSpacing.md)
        .runstrCard()
    }
    
    // MARK: - Weekly Progress Section
    private func weeklyProgressSection(user: User) -> some View {
        VStack(spacing: RunstrSpacing.md) {
            HStack {
                Text("Weekly Goals")
                    .font(.runstrHeadline)
                    .foregroundColor(.runstrWhite)
                Spacer()
            }
            
            VStack(spacing: RunstrSpacing.md) {
                // Distance progress
                WeeklyProgressView(
                    title: "Distance Goal",
                    current: getCurrentWeekDistance(user: user),
                    target: user.profile.fitnessGoals.weeklyDistanceTarget,
                    unit: "km",
                    color: .runstrAccent
                )
                
                // Workout progress
                WeeklyProgressView(
                    title: "Workout Goal",
                    current: Double(getCurrentWeekWorkouts(user: user)),
                    target: Double(user.profile.fitnessGoals.weeklyWorkoutTarget),
                    unit: "workouts",
                    color: .green
                )
            }
        }
        .padding(RunstrSpacing.md)
        .runstrCard()
    }
    
    // MARK: - Personal Records Section
    private func personalRecordsSection() -> some View {
        VStack(spacing: RunstrSpacing.md) {
            HStack {
                Text("Personal Records")
                    .font(.runstrHeadline)
                    .foregroundColor(.runstrWhite)
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let records = statsService?.personalRecords[selectedActivity], !records.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: RunstrSpacing.sm) {
                    ForEach(records) { record in
                        PersonalRecordCard(record: record)
                    }
                }
            } else {
                Text("No records yet for \(selectedActivity.displayName)")
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
                    .padding(.vertical, RunstrSpacing.lg)
            }
        }
        .padding(RunstrSpacing.md)
        .runstrCard()
    }
    
    // MARK: - Recent Activity Section
    private func recentActivitySection() -> some View {
        VStack(spacing: RunstrSpacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(.runstrHeadline)
                    .foregroundColor(.runstrWhite)
                Spacer()
            }
            
            Text("Recent workouts will appear here")
                .font(.runstrCaption)
                .foregroundColor(.runstrGray)
                .padding(.vertical, RunstrSpacing.lg)
        }
        .padding(RunstrSpacing.md)
        .runstrCard()
    }
    
    // MARK: - Helper Functions
    private func getCurrentWeekDistance(user: User) -> Double {
        // This would need to be calculated from recent workouts
        // For now, return a placeholder calculation
        let daysSinceLastWorkout = user.stats.daysSinceLastWorkout()
        if daysSinceLastWorkout <= 7 {
            return min(user.stats.totalDistance / 1000, user.profile.fitnessGoals.weeklyDistanceTarget)
        }
        return 0.0
    }
    
    private func getCurrentWeekWorkouts(user: User) -> Int {
        // This would need to be calculated from recent workouts
        // For now, return a placeholder calculation
        let daysSinceLastWorkout = user.stats.daysSinceLastWorkout()
        if daysSinceLastWorkout <= 7 {
            return min(user.stats.totalWorkouts, user.profile.fitnessGoals.weeklyWorkoutTarget)
        }
        return 0
    }
}

// MARK: - Supporting Views

struct ProfileStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: RunstrSpacing.sm) {
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                Text(value)
                    .font(.runstrMetricSmall)
                    .foregroundColor(.runstrWhite)
                
                Text(title)
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(RunstrSpacing.md)
        .runstrCard()
    }
}

struct WeeklyProgressView: View {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    
    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }
    
    var body: some View {
        VStack(spacing: RunstrSpacing.sm) {
            HStack {
                Text(title)
                    .font(.runstrBodyMedium)
                    .foregroundColor(.runstrWhite)
                Spacer()
                
                Text("\(String(format: "%.1f", current))/\(String(format: "%.0f", target)) \(unit)")
                    .font(.runstrCaptionMedium)
                    .foregroundColor(.runstrGray)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .background(Color.runstrGrayDark)
                .cornerRadius(RunstrRadius.sm / 2)
        }
    }
}

struct PersonalRecordCard: View {
    let record: PersonalRecord
    
    var body: some View {
        VStack(spacing: RunstrSpacing.xs) {
            HStack {
                Text(record.recordType.displayName)
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
                    .lineLimit(1)
                
                Spacer()
                
                if record.isNewRecord {
                    Image(systemName: "star.fill")
                        .font(.runstrSmall)
                        .foregroundColor(.runstrWhite)
                }
            }
            
            Text(record.formattedValue)
                .font(.runstrCaptionMedium)
                .foregroundColor(.runstrWhite)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(RunstrSpacing.sm)
        .background(Color.runstrCardBackground)
        .cornerRadius(RunstrRadius.sm)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationService())
        .environmentObject(HealthKitService())
        .environmentObject(NostrService())
}