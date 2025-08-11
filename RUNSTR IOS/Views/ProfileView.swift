import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var workoutStorage: WorkoutStorage
    @State private var showingSettings = false
    @State private var isLoading = false
    @State private var selectedActivity: ActivityType = .running
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header with activity selector and settings
                    headerSection
                    
                    if let user = authService.currentUser {
                        // Profile info section
                        profileInfoSection(user: user)
                        
                        // Nostr identity section
                        nostrIdentitySection(user: user)
                        
                        // Key stats overview cards
                        keyStatsSection(user: user)
                        
                        // Activity overview
                        activityOverviewSection(user: user)
                        
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
            // Profile picture placeholder
            Circle()
                .fill(Color.runstrGray.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundColor(.runstrGray)
                )
            
            // User info
            VStack(spacing: RunstrSpacing.xs) {
                Text(user.profile.displayName.isEmpty ? "RUNSTR User" : user.profile.displayName)
                    .font(.runstrTitle)
                    .foregroundColor(.runstrWhite)
                
                if !user.profile.about.isEmpty {
                    Text(user.profile.about)
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private func nostrIdentitySection(user: User) -> some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "at")
                    .foregroundColor(.purple)
                Text("Nostr Identity")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
                Spacer()
                Circle()
                    .fill(nostrService.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                Text("Public Key (npub)")
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
                
                Button {
                    UIPasteboard.general.string = user.nostrPublicKey
                } label: {
                    HStack {
                        Text(user.nostrPublicKey)
                            .font(.runstrSmall)
                            .foregroundColor(.runstrWhite)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Image(systemName: "doc.on.doc")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                }
            }
            
            if nostrService.isConnected {
                Text("Connected to Nostr relays - ready to post workout summaries")
                    .font(.runstrCaption)
                    .foregroundColor(.green)
            } else {
                Text("Not connected to Nostr relays")
                    .font(.runstrCaption)
                    .foregroundColor(.red)
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private func keyStatsSection(user: User) -> some View {
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
                
                Text("\(user.stats.totalWorkouts)")
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
                
                Text(user.stats.formattedTotalDistance)
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
                
                Text("\(user.stats.currentStreak)")
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
                
                Text("\(user.stats.longestStreak)")
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
    
    private func activityOverviewSection(user: User) -> some View {
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
                    Text(String(format: "%.1f km", user.stats.averageDistancePerWorkout / 1000))
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                }
                
                HStack {
                    Text("Last workout:")
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                    Spacer()
                    Text(formatLastWorkoutDate(user.stats.lastWorkoutDate))
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
                let recentWorkouts = workoutStorage.getRecentWorkouts(limit: 5)
                
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
                            WorkoutRowView(workout: workout)
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
}