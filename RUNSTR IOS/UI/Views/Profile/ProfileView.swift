import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var workoutStorage: WorkoutStorage
    @EnvironmentObject var unitPreferences: UnitPreferencesService
    @State private var showingSettings = false
    @State private var showingProfileEdit = false
    @State private var isLoading = false
    @State private var selectedActivity: ActivityType = .running
    @State private var recentWorkouts: [Workout] = []
    @State private var hasLoadedWorkouts = false
    @State private var calculatedStats = UserStats()
    
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
                        keyStatsSection()
                        
                        // Activity overview
                        activityOverviewSection()
                        
                        // Recent workouts list
                        recentWorkoutsSection
                    }
                    
                    Spacer(minLength: 100)
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
        .sheet(isPresented: $showingProfileEdit) {
            ProfileEditView()
        }
        .onAppear {
            loadWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutCompleted)) { _ in
            // Reload workouts when a new workout is completed
            loadWorkouts()
        }
    }
    
    private func loadWorkouts() {
        recentWorkouts = workoutStorage.getRecentWorkouts(limit: 5)
        calculateStatsFromWorkouts()
    }
    
    private func calculateStatsFromWorkouts() {
        let allWorkouts = workoutStorage.getAllWorkouts()
        
        var stats = UserStats()
        stats.totalWorkouts = allWorkouts.count
        stats.totalDistance = allWorkouts.reduce(0) { $0 + $1.distance }
        
        // Find last workout date
        if let lastWorkout = allWorkouts.first {
            stats.lastWorkoutDate = lastWorkout.startTime
        }
        
        // Calculate streaks
        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 0
        var lastDate: Date? = nil
        
        // Sort workouts by date (newest first)
        let sortedWorkouts = allWorkouts.sorted { $0.startTime > $1.startTime }
        
        for workout in sortedWorkouts {
            let workoutDate = Calendar.current.startOfDay(for: workout.startTime)
            
            if let last = lastDate {
                let daysBetween = Calendar.current.dateComponents([.day], from: workoutDate, to: last).day ?? 0
                
                if daysBetween == 1 {
                    tempStreak += 1
                } else if daysBetween == 0 {
                    // Same day, don't increment streak
                } else {
                    // Gap in workouts, reset temp streak
                    longestStreak = max(longestStreak, tempStreak + 1)
                    tempStreak = 0
                }
            } else {
                // First workout
                tempStreak = 1
            }
            
            lastDate = workoutDate
        }
        
        // Final check for longest streak
        longestStreak = max(longestStreak, tempStreak)
        
        // Calculate current streak (from today backwards)
        if let firstWorkout = sortedWorkouts.first {
            let today = Calendar.current.startOfDay(for: Date())
            let lastWorkoutDay = Calendar.current.startOfDay(for: firstWorkout.startTime)
            let daysSinceLastWorkout = Calendar.current.dateComponents([.day], from: lastWorkoutDay, to: today).day ?? 0
            
            if daysSinceLastWorkout <= 1 {
                // Count consecutive days from most recent workout
                currentStreak = 1
                var checkDate = lastWorkoutDay
                
                for i in 1..<sortedWorkouts.count {
                    let workoutDay = Calendar.current.startOfDay(for: sortedWorkouts[i].startTime)
                    let daysDiff = Calendar.current.dateComponents([.day], from: workoutDay, to: checkDate).day ?? 0
                    
                    if daysDiff == 1 {
                        currentStreak += 1
                        checkDate = workoutDay
                    } else if daysDiff > 1 {
                        break
                    }
                }
            }
        }
        
        stats.currentStreak = currentStreak
        stats.longestStreak = longestStreak
        stats.lastUpdated = Date()
        
        calculatedStats = stats
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
    
    private func profileInfoSection(user: User) -> some View {
        VStack(spacing: RunstrSpacing.md) {
            HStack {
                Spacer()
                Button {
                    showingProfileEdit = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundColor(.runstrWhite)
                }
            }
            
            // Profile picture
            if let profilePictureURL = user.profile.profilePicture,
               let url = URL(string: profilePictureURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.runstrGray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .runstrGray))
                        )
                }
            } else {
                Circle()
                    .fill(Color.runstrGray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Group {
                            if authService.isLoadingProfile {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .runstrGray))
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.title)
                                    .foregroundColor(.runstrGray)
                            }
                        }
                    )
            }
            
            // User info
            VStack(spacing: RunstrSpacing.xs) {
                HStack {
                    Text(user.profile.displayName.isEmpty ? "RUNSTR User" : user.profile.displayName)
                        .font(.runstrTitle)
                        .foregroundColor(.runstrWhite)
                    
                    if authService.isLoadingProfile && user.profile.displayName.isEmpty {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .runstrGray))
                            .scaleEffect(0.6)
                    }
                }
                
                if !user.profile.about.isEmpty {
                    Text(user.profile.about)
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                        .multilineTextAlignment(.center)
                } else if authService.isLoadingProfile {
                    Text("Loading profile...")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private func keyStatsSection() -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: RunstrSpacing.md) {
            // Total workouts
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Workouts")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                Text("\(calculatedStats.totalWorkouts)")
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
                
                Text("total")
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
            
            // Total distance
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "location")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Distance")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                Text(calculatedStats.formattedTotalDistance(unitService: unitPreferences))
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
                
                Text("total")
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
            
            // Current streak
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "flame")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Streak")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                Text("\(calculatedStats.currentStreak)")
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
                
                Text("days")
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
            
            // Longest streak
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "trophy")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Best")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                Text("\(calculatedStats.longestStreak)")
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
                
                Text("days")
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
        }
    }
    
    private func activityOverviewSection() -> some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.runstrWhite)
                Text("Activity Overview")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            VStack(spacing: RunstrSpacing.sm) {
                HStack {
                    Text("Average per workout:")
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                    Spacer()
                    Text(unitPreferences.formatDistance(calculatedStats.averageDistancePerWorkout, precision: 1))
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                }
                
                HStack {
                    Text("Last workout:")
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                    Spacer()
                    Text(formatLastWorkoutDate(calculatedStats.lastWorkoutDate))
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                }
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.runstrWhite)
                Text("Recent Workouts")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
                
                Spacer()
                
                NavigationLink("See All") {
                    AllWorkoutsView()
                }
                .font(.runstrCaption)
                .foregroundColor(.orange)
            }
            
            VStack(spacing: RunstrSpacing.xs) {
                
                if recentWorkouts.isEmpty {
                    VStack(spacing: RunstrSpacing.sm) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 40))
                            .foregroundColor(.runstrGray)
                        
                        Text("No workouts yet")
                            .font(.runstrBody)
                            .foregroundColor(.runstrGray)
                        
                        Text("Start your first workout to see it here")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, RunstrSpacing.xl)
                } else {
                    ForEach(recentWorkouts, id: \.id) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            WorkoutRowView(workout: workout, unitPreferences: unitPreferences)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if workout.id != recentWorkouts.last?.id {
                            Divider()
                                .background(Color.runstrGray.opacity(0.3))
                        }
                    }
                }
            }
            .padding(RunstrSpacing.md)
            .runstrCard()
        }
    }
    
    private func formatLastWorkoutDate(_ date: Date) -> String {
        if date == Date.distantPast {
            return "Never"
        }
        
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        
        if daysSince == 0 {
            return "Today"
        } else if daysSince == 1 {
            return "Yesterday"
        } else if daysSince < 7 {
            return "\(daysSince) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationService())
        .environmentObject(HealthKitService())
        .environmentObject(NostrService())
        .environmentObject(WorkoutStorage())
        .environmentObject(UnitPreferencesService())
}