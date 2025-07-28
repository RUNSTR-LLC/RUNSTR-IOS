import SwiftUI
import MapKit

struct WorkoutView: View {
    let activityType: ActivityType
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var workoutSession: WorkoutSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var cashuService: CashuService
    @EnvironmentObject var streakService: StreakService
    
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
            if !workoutSession.isActive {
                startWorkout()
            }
        }
        .onChange(of: locationService.currentLocation) { _, location in
            if let location = location {
                region.center = location.coordinate
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
                    Text("Sats Earned")
                        .font(.caption)
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundColor(.orange)
                        Text("\(calculateCurrentReward())")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
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
    
    private func startWorkout() {
        guard let userID = authService.currentUser?.id else { return }
        
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
                
                // 2. Update streak and award Cashu tokens
                await awardWorkoutReward(for: completedWorkout)
                
                // 3. Create Nostr event (if connected)
                // TODO: Implement Nostr event publishing
                
                // 4. Update user stats
                // TODO: Update user statistics
            }
            
            dismiss()
        }
    }
    
    /// Award Cashu tokens based on workout performance and streak
    private func awardWorkoutReward(for workout: Workout) async {
        guard let user = authService.currentUser else {
            print("❌ No authenticated user for reward")
            return
        }
        
        // Calculate base workout reward
        let workoutReward = calculateWorkoutReward(workout)
        
        // Update streak and get streak reward
        streakService.recordWorkout(date: workout.startTime)
        let streakReward = streakService.streakRewardEarned
        
        // Check for weekly completion bonus
        let weeklyBonus = streakService.hasCompletedWeeklyChallenge() ? streakService.getWeeklyCompletionBonus() : 0
        
        let totalReward = workoutReward + streakReward + weeklyBonus
        
        guard totalReward > 0 else {
            print("❌ No reward calculated for workout")
            return
        }
        
        do {
            // Mint Cashu tokens for workout reward
            if workoutReward > 0 {
                let workoutTokens = try await cashuService.requestTokens(amount: workoutReward)
                print("✅ Minted \(workoutReward) sats for workout completion")
            }
            
            // Mint additional tokens for streak
            if streakReward > 0 {
                let streakTokens = try await cashuService.requestTokens(amount: streakReward)
                print("🔥 Minted \(streakReward) sats for day \(streakService.currentStreak) streak!")
            }
            
            // Mint weekly completion bonus
            if weeklyBonus > 0 {
                let bonusTokens = try await cashuService.requestTokens(amount: weeklyBonus)
                print("🏆 Minted \(weeklyBonus) sats for completing weekly challenge!")
            }
            
            // Update user stats
            if var currentUser = authService.currentUser {
                currentUser.stats.recordWorkout(workout, streakReward: streakReward + weeklyBonus)
                currentUser.stats.updateStreak(current: streakService.currentStreak, longest: streakService.currentStreak)
                
                if weeklyBonus > 0 {
                    currentUser.stats.recordWeeklyStreakCompletion(bonus: weeklyBonus)
                }
                
                // Save updated user (this would normally go through AuthenticationService)
                // authService.updateCurrentUser(currentUser)
            }
            
            print("✅ Total reward: \(totalReward) sats (\(workoutReward) workout + \(streakReward) streak + \(weeklyBonus) bonus)")
            print("🏃‍♂️ Distance: \(String(format: "%.2f", workout.distance/1000))km")
            print("⏱️ Duration: \(formatTime(workout.duration))")
            print("🔥 Streak: \(streakService.getStreakStatusMessage())")
            
        } catch {
            print("❌ Failed to award workout reward: \(error)")
        }
    }
    
    /// Calculate reward amount based on workout metrics
    private func calculateWorkoutReward(_ workout: Workout) -> Int {
        let distanceKm = workout.distance / 1000
        let durationMinutes = workout.duration / 60
        
        // Base reward calculation
        let distanceReward = Int(distanceKm * 50) // 50 sats per km
        let timeReward = Int(durationMinutes * 5) // 5 sats per minute
        let baseReward = max(100, distanceReward + timeReward) // Minimum 100 sats
        
        // Bonus multipliers
        var bonusMultiplier = 1.0
        
        // Distance bonus
        if distanceKm >= 10.0 {
            bonusMultiplier += 0.5 // 50% bonus for 10k+
        } else if distanceKm >= 5.0 {
            bonusMultiplier += 0.25 // 25% bonus for 5k+
        }
        
        // Pace bonus (under 5 min/km is good pace)
        if workout.averagePace < 5.0 {
            bonusMultiplier += 0.3 // 30% bonus for good pace
        }
        
        return Int(Double(baseReward) * bonusMultiplier)
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
    
    private func calculateCurrentReward() -> Int {
        let baseReward = Int(workoutSession.currentDistance / 100) // 1 sat per 100m
        let timeReward = Int(workoutSession.elapsedTime / 300) // 1 sat per 5 minutes
        return max(100, baseReward + timeReward)
    }
}

#Preview {
    WorkoutView(activityType: .running)
        .environmentObject(WorkoutSession())
        .environmentObject(LocationService())
        .environmentObject(HealthKitService())
        .environmentObject(AuthenticationService())
}