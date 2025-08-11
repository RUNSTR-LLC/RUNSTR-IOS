import SwiftUI
import MapKit

struct WorkoutView: View {
    let activityType: ActivityType
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var workoutSession: WorkoutSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var workoutStorage: WorkoutStorage
    
    @State private var showingSummary = false
    @State private var completedWorkout: Workout?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Map view
                mapSection
                
                // Stats section
                statsSection
                
                // Control buttons
                controlsSection
            }
            .navigationTitle(activityType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        Task {
                            if workoutSession.isActive {
                                _ = await workoutSession.endWorkout()
                            }
                            dismiss()
                        }
                    }
                }
            }
            .background(Color.black)
            .foregroundColor(.white)
        }
        .onAppear {
            print("🏃 WorkoutView appeared with activity type: \(activityType.displayName)")
            
            // Configure WorkoutSession with required services
            workoutSession.configure(healthKitService: healthKitService, locationService: locationService)
            
            // Request permissions before starting workout
            Task {
                await requestPermissions()
                
                if !workoutSession.isActive {
                    print("🏃 Starting workout session...")
                    startWorkout()
                } else {
                    print("🏃 Workout session already active")
                }
            }
        }
        .onChange(of: locationService.currentLocation) { _, location in
            if let location = location {
                region.center = location.coordinate
            }
        }
        .fullScreenCover(isPresented: $showingSummary) {
            if let workout = completedWorkout {
                WorkoutSummaryView(workout: workout)
                    .environmentObject(workoutStorage)
                    .environmentObject(nostrService)
                    .onDisappear {
                        // When summary is dismissed, dismiss the workout view too
                        dismiss()
                    }
            }
        }
    }
    
    private var mapSection: some View {
        Map(coordinateRegion: $region, showsUserLocation: true)
        .frame(height: 300)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var statsSection: some View {
        VStack(spacing: 20) {
            // Primary stats
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.2f", workoutSession.currentDistance / 1000))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("km")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 4) {
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatTime(workoutSession.elapsedTime))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .padding(.vertical)
            
            // Secondary stats
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Text("Pace")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatPace(workoutSession.currentPace))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text("min/km")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if let heartRate = healthKitService.currentHeartRate {
                    VStack(spacing: 4) {
                        Text("Heart Rate")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(Int(heartRate))")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        Text("bpm")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(spacing: 4) {
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(healthKitService.currentCalories))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text("kcal")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Pause/Resume or Start button
            Button {
                if workoutSession.isActive {
                    if workoutSession.isPaused {
                        resumeWorkout()
                    } else {
                        pauseWorkout()
                    }
                } else {
                    startWorkout()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: workoutSession.isPaused ? "play.fill" : "pause.fill")
                    Text(workoutSession.isPaused ? "Resume" : "Pause")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(workoutSession.isPaused ? Color.green : Color.orange)
                .cornerRadius(28)
            }
            
            // End workout button
            if workoutSession.isActive {
                Button {
                    endWorkout()
                } label: {
                    Text("Finish Workout")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.red)
                        .cornerRadius(28)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }
    
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
        // Use a test user ID if no user is logged in
        let userID = authService.currentUser?.id ?? "test-user-123"
        
        print("🎯 Starting workout with userID: \(userID)")
        
        Task {
            locationService.startTracking()
            let success = await workoutSession.startWorkout(activityType: activityType, userID: userID)
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
                // 1. Save to HealthKit
                healthKitService.saveWorkout(completedWorkout) { success in
                    print("Workout saved to HealthKit: \(success)")
                }
                
                // 2. Update user stats
                await awardWorkoutReward(for: completedWorkout)
                
                // 3. Create Nostr event (if connected)
                await publishWorkoutToNostr(completedWorkout)
                
                // 4. Store completed workout and show summary
                self.completedWorkout = completedWorkout
                self.showingSummary = true
            } else {
                // If workout failed to complete, just dismiss
                dismiss()
            }
        }
    }
    
    /// Update user stats after workout completion
    private func awardWorkoutReward(for workout: Workout) async {
        guard var currentUser = authService.currentUser else {
            print("❌ No authenticated user for stats update")
            return
        }
        
        // Update user stats
        currentUser.stats.recordWorkout(workout)
        
        // Simple streak logic - increment if workout was today, reset if gap
        let daysSinceLastWorkout = currentUser.stats.daysSinceLastWorkout()
        if daysSinceLastWorkout <= 1 {
            currentUser.stats.currentStreak += 1
        } else {
            currentUser.stats.currentStreak = 1
        }
        
        currentUser.stats.longestStreak = max(currentUser.stats.longestStreak, currentUser.stats.currentStreak)
        
        print("✅ Updated user stats:")
        print("🏃‍♂️ Distance: \(String(format: "%.2f", workout.distance/1000))km")
        print("⏱️ Duration: \(formatTime(workout.duration))")
        print("🔥 Streak: \(currentUser.stats.currentStreak) days")
        
        // Save updated user (this would normally go through AuthenticationService)
        // authService.updateCurrentUser(currentUser)
    }
    
    
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
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace.isFinite else { return "--:--" }
        
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
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
        
        // Publish workout event with public privacy level
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

#Preview {
    WorkoutView(activityType: .running)
        .environmentObject(WorkoutSession())
        .environmentObject(LocationService())
        .environmentObject(HealthKitService())
        .environmentObject(AuthenticationService())
        .environmentObject(NostrService())
        .environmentObject(WorkoutStorage())
}