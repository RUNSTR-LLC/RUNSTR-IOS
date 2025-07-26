import SwiftUI
import MapKit

struct WorkoutView: View {
    let activityType: ActivityType
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var workoutSession: WorkoutSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var authService: AuthenticationService
    
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
                        if workoutSession.isActive {
                            _ = workoutSession.endWorkout()
                        }
                        dismiss()
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
        
        locationService.startTracking()
        workoutSession.startWorkout(activityType: activityType, userID: userID)
        
        _ = healthKitService.startWorkoutSession(activityType: activityType)
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
        locationService.stopTracking()
        
        if let completedWorkout = workoutSession.endWorkout() {
            // Here you would:
            // 1. Save to HealthKit
            // 2. Create Nostr event
            // 3. Award sats
            // 4. Update user stats
            
            healthKitService.saveWorkout(completedWorkout) { success in
                print("Workout saved to HealthKit: \(success)")
            }
        }
        
        dismiss()
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