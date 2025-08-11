import SwiftUI
import HealthKit

struct DashboardView: View {
    @EnvironmentObject var workoutSession: WorkoutSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var workoutStorage: WorkoutStorage
    
    @State private var selectedActivityType: ActivityType = .running
    @State private var showingWorkoutView = false
    @State private var showingSettingsView = false
    @State private var showingSummary = false
    @State private var completedWorkout: Workout?
    @State private var recentWorkouts: [HKWorkout] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header with activity selector and settings
                    headerSection
                    
                    // Metrics grid (4 cards)
                    metricsSection
                    
                    // Start Run button
                    startRunButton
                    
                    // Recent workouts section
                    if !recentWorkouts.isEmpty {
                        recentWorkoutsSection
                    }
                    
                    Spacer(minLength: 100) // Bottom padding for tab bar
                    
                    // Hidden NavigationLink for workout summary
                    NavigationLink(
                        destination: Group {
                            if let workout = completedWorkout {
                                SimpleWorkoutSummaryView(workout: workout)
                                    .environmentObject(workoutStorage)
                            }
                        },
                        isActive: $showingSummary
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingWorkoutView) {
            WorkoutView(activityType: selectedActivityType)
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsView()
        }
        .onAppear {
            loadRecentWorkouts()
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Dynamic activity selector
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
            
            // Settings button
            Button {
                showingSettingsView = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
            }
        }
    }
    
    private var metricsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: RunstrSpacing.md) {
            // Distance card
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "location")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Distance")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                Text(workoutSession.isActive ? String(format: "%.2f", workoutSession.currentDistance / 1000) : "0.00")
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
                
                Text("km")
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
            
            // Time card
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "clock")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Time")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                Text(workoutSession.isActive ? formatTime(workoutSession.elapsedTime) : "00:00")
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
            
            // Activity-specific metric card
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                switch selectedActivityType {
                case .walking:
                    HStack {
                        Image(systemName: "shoeprints.fill")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                        Text("Steps")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                    Text(workoutSession.isActive ? "\(workoutSession.currentSteps)" : "0")
                        .font(.runstrMetric)
                        .foregroundColor(.runstrWhite)
                    Text("steps")
                        .font(.runstrSmall)
                        .foregroundColor(.runstrGray)
                        
                case .cycling:
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                        Text("Speed")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                    Text(workoutSession.isActive ? String(format: "%.1f", workoutSession.currentSpeed * 2.23694) : "0.0")
                        .font(.runstrMetric)
                        .foregroundColor(.runstrWhite)
                    Text("mph")
                        .font(.runstrSmall)
                        .foregroundColor(.runstrGray)
                        
                default: // .running and others
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                        Text("Pace")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                    Text(workoutSession.isActive ? String(format: "%.1f", workoutSession.currentPace) : "--")
                        .font(.runstrMetric)
                        .foregroundColor(.runstrWhite)
                    Text("min/km")
                        .font(.runstrSmall)
                        .foregroundColor(.runstrGray)
                }
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
            
            // Elevation card
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "triangle")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Elevation")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                Text(workoutSession.isActive ? String(format: "%.0f", locationService.getElevationGain() * 3.28084) : "0")
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
                
                Text("ft")
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
        }
    }
    
    private var startRunButton: some View {
        VStack(spacing: RunstrSpacing.md) {
            if workoutSession.isActive {
                // Show workout controls when active
                // Pause/Resume button
                Button {
                    if workoutSession.isPaused {
                        resumeWorkout()
                    } else {
                        pauseWorkout()
                    }
                } label: {
                    HStack {
                        Image(systemName: workoutSession.isPaused ? "play.fill" : "pause.fill")
                        Text(workoutSession.isPaused ? "Resume" : "Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RunstrSpacing.lg)
                }
                .buttonStyle(RunstrSecondaryButton())
                
                // Finish workout button
                Button {
                    endWorkout()
                } label: {
                    Text("Finish Workout")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RunstrSpacing.lg)
                }
                .buttonStyle(RunstrPrimaryButton())
            } else {
                // Show start button when inactive
                Button {
                    print("🎯 Start \(selectedActivityType.displayName) button tapped")
                    startWorkout()
                } label: {
                    Text("Start \(selectedActivityType.displayName)")
                        .font(.runstrSubheadline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RunstrSpacing.lg)
                        .background(Color.runstrWhite)
                        .cornerRadius(RunstrRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var recentWorkoutsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Recent Workouts")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
                Spacer()
            }
            
            VStack(spacing: RunstrSpacing.sm) {
                ForEach(Array(recentWorkouts.prefix(3).enumerated()), id: \.offset) { index, workout in
                    WorkoutSummaryCard(
                        activityType: ActivityType.from(hkWorkout: workout),
                        distance: (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000,
                        duration: workout.duration,
                        date: workout.startDate
                    )
                }
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    // MARK: - Helper Functions
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func loadRecentWorkouts() {
        healthKitService.fetchRecentWorkouts { workouts in
            self.recentWorkouts = workouts
        }
    }
    
    // MARK: - Workout Control Functions
    
    private func requestPermissions() async {
        // Request HealthKit authorization
        if !healthKitService.isAuthorized {
            print("🏥 Requesting HealthKit authorization...")
            let healthKitAuthorized = await healthKitService.requestAuthorization()
            if !healthKitAuthorized {
                print("❌ HealthKit authorization denied")
                return
            }
        }
        
        // Request Location permission
        if locationService.authorizationStatus == .notDetermined {
            print("📍 Requesting location authorization...")
            locationService.requestLocationPermission()
        }
    }
    
    private func startWorkout() {
        let userID = authService.currentUser?.id ?? "test-user-123"
        
        print("🎯 Starting workout with userID: \(userID)")
        
        // Configure WorkoutSession with required services
        workoutSession.configure(healthKitService: healthKitService, locationService: locationService)
        
        Task {
            // CRITICAL FIX: Request permissions before starting
            await requestPermissions()
            
            locationService.startTracking()
            let success = await workoutSession.startWorkout(activityType: selectedActivityType, userID: userID)
            if !success {
                print("❌ Failed to start workout session")
            }
        }
    }
    
    private func pauseWorkout() {
        workoutSession.pauseWorkout()
        locationService.pauseTracking()
    }
    
    private func resumeWorkout() {
        workoutSession.resumeWorkout()
        locationService.resumeTracking()
    }
    
    private func endWorkout() {
        Task {
            locationService.stopTracking()
            
            if let completedWorkout = await workoutSession.endWorkout() {
                // 1. Save to local storage first
                await MainActor.run {
                    workoutStorage.saveWorkout(completedWorkout)
                    print("✅ Workout saved to local storage")
                }
                
                // 2. Store completed workout and show summary IMMEDIATELY
                await MainActor.run {
                    self.completedWorkout = completedWorkout
                    self.showingSummary = true
                }
                
                // 3. Save to HealthKit (background)
                healthKitService.saveWorkout(completedWorkout) { success in
                    print("Workout saved to HealthKit: \(success)")
                }
                
                // 4. Publish to Nostr (background - don't block UI)
                Task {
                    await publishWorkoutToNostr(completedWorkout)
                }
            }
        }
    }
    
    /// Publish completed workout to Nostr relays
    private func publishWorkoutToNostr(_ workout: Workout) async {
        guard let user = authService.currentUser else {
            print("❌ No authenticated user for Nostr publishing")
            return
        }
        
        // Check if NostrService is connected to relays
        if !nostrService.isConnected {
            print("⚠️ NostrService not connected to relays, attempting connection...")
            await nostrService.connect()
            
            // Wait briefly and check connection again
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            guard nostrService.isConnected else {
                print("❌ Failed to connect to Nostr relays for workout publishing")
                return
            }
        }
        
        // Publish workout event 
        let success = await nostrService.publishWorkoutEvent(workout)
        
        if success {
            print("✅ Successfully published workout to Nostr!")
            print("   🏃‍♂️ Activity: \(workout.activityType.displayName)")
            print("   📏 Distance: \(String(format: "%.2f", workout.distance/1000))km")
            print("   ⏱️ Duration: \(formatTime(workout.duration))")
            print("   🔗 Event published to Nostr relay")
        } else {
            print("❌ Failed to publish workout to Nostr relays")
        }
    }
}

// MARK: - Supporting Views and Extensions

struct WorkoutSummaryCard: View {
    let activityType: ActivityType
    let distance: Double
    let duration: TimeInterval
    let date: Date
    
    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: activityType.systemImageName)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activityType.displayName)
                    .font(.runstrBody)
                    .foregroundColor(.runstrWhite)
                
                Text(formatter.string(from: date))
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f km", distance))
                    .font(.runstrBody)
                    .foregroundColor(.runstrWhite)
                
                Text(formatTime(duration))
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
            }
        }
        .padding(.horizontal, RunstrSpacing.md)
        .padding(.vertical, RunstrSpacing.sm)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

extension ActivityType {
    static func from(hkWorkout: HKWorkout) -> ActivityType {
        switch hkWorkout.workoutActivityType {
        case .running:
            return .running
        case .walking:
            return .walking
        case .cycling:
            return .cycling
        default:
            return .running // Default fallback
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(WorkoutSession())
        .environmentObject(LocationService())
        .environmentObject(HealthKitService())
        .environmentObject(AuthenticationService())
        .environmentObject(NostrService())
        .environmentObject(WorkoutStorage())
}