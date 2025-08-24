import SwiftUI
import HealthKit

/// Ultra-simple workout view that lets iOS handle all the complexity
struct SimpleWorkoutView: View {
    @EnvironmentObject private var healthKit: SimpleHealthKitService
    @State private var selectedActivity: HKWorkoutActivityType = .running
    @State private var isStartingWorkout = false
    
    // Supported activity types (keep it simple)
    private let activityTypes: [HKWorkoutActivityType] = [.running, .walking, .cycling]
    
    var body: some View {
        VStack(spacing: 30) {
            
            if healthKit.isWorkoutActive {
                // Active workout view
                activeWorkoutView
            } else {
                // Start workout view
                startWorkoutView
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Workout")
        .task {
            // Load existing workouts when view appears
            if healthKit.isAuthorized && healthKit.workouts.isEmpty {
                await healthKit.loadAllWorkouts()
            }
        }
    }
    
    // MARK: - Active Workout View
    
    private var activeWorkoutView: some View {
        VStack(spacing: 40) {
            
            // Activity indicator
            VStack(spacing: 16) {
                Text(selectedActivity.emoji)
                    .font(.system(size: 80))
                
                Text("iOS is tracking your \(selectedActivity.name.lowercased())")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // Live workout stats
            VStack(spacing: 20) {
                Text("🟢 Active Tracking")
                    .font(.headline)
                    .foregroundColor(.green)
                
                // Live stats
                HStack(spacing: 40) {
                    VStack {
                        Text("\(Int(healthKit.currentDistance))m")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text(formatTime(healthKit.currentDuration))
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Tracking automatically...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // End workout button
            Button {
                Task {
                    await endWorkout()
                }
            } label: {
                Text("End Workout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.red)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Start Workout View
    
    private var startWorkoutView: some View {
        VStack(spacing: 40) {
            
            // Header
            VStack(spacing: 16) {
                Text("🏃‍♂️")
                    .font(.system(size: 60))
                
                Text("Start Workout")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Choose your activity and let iOS handle the rest")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Activity selection
            VStack(spacing: 16) {
                Text("Activity")
                    .font(.headline)
                
                Picker("Activity", selection: $selectedActivity) {
                    ForEach(activityTypes, id: \.self) { activity in
                        HStack {
                            Text(activity.emoji)
                            Text(activity.name)
                        }
                        .tag(activity)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Start button
            Button {
                Task {
                    await startWorkout()
                }
            } label: {
                HStack {
                    if isStartingWorkout {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(selectedActivity.emoji)
                        Text("Start \(selectedActivity.name)")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(healthKit.isAuthorized ? Color.green : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!healthKit.isAuthorized || isStartingWorkout)
            
            // Permission status
            if !healthKit.isAuthorized {
                VStack(spacing: 8) {
                    Text("⚠️ HealthKit permissions required")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Button("Grant Permissions") {
                        Task {
                            await healthKit.requestAuthorization()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startWorkout() async {
        isStartingWorkout = true
        
        // Request permissions if needed
        if !healthKit.isAuthorized {
            let authorized = await healthKit.requestAuthorization()
            if !authorized {
                isStartingWorkout = false
                return
            }
        }
        
        // Start the workout - iOS does everything
        let success = await healthKit.startWorkout(activityType: selectedActivity)
        
        isStartingWorkout = false
        
        if success {
            print("✅ Workout started successfully")
        } else {
            print("❌ Failed to start workout")
        }
    }
    
    private func endWorkout() async {
        let workout = await healthKit.endWorkout()
        
        if let workout = workout {
            print("✅ Workout completed: \(workout.distanceFormatted), \(workout.durationFormatted)")
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationView {
        SimpleWorkoutView()
            .environmentObject(SimpleHealthKitService())
    }
}