import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var workoutSession: WorkoutSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var selectedActivityType: ActivityType = .running
    @State private var showingWorkoutView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Main content
                ScrollView {
                    VStack(spacing: 32) {
                        // Quick workout start buttons
                        workoutStartSection
                        
                        // Current workout stats (if active)
                        if workoutSession.isActive {
                            currentWorkoutSection
                        }
                        
                        // Recent workouts
                        recentWorkoutsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .background(Color.black)
            .foregroundColor(.white)
        }
        .sheet(isPresented: $showingWorkoutView) {
            WorkoutView(activityType: selectedActivityType)
        }
    }
    
    private var headerSection: some View {
        HStack {
            Text("RUNSTR")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(.white)
            
            Spacer()
            
            // Bitcoin balance
            HStack(spacing: 8) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(.white)
                    .font(.title3)
                
                Text("21,000")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .background(Color.black)
    }
    
    private var workoutStartSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Start Workout")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                ForEach(ActivityType.allCases, id: \.self) { activityType in
                    Button {
                        selectedActivityType = activityType
                        showingWorkoutView = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: activityType.systemImageName)
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                            
                            Text(activityType.displayName)
                                .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    private var currentWorkoutSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Active Workout")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DISTANCE")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f", workoutSession.currentDistance / 1000))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("km")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("TIME")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                        Text(formatTime(workoutSession.elapsedTime))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PACE")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f", workoutSession.currentPace))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("min/km")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if let heartRate = healthKitService.currentHeartRate {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("HEART RATE")
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundColor(.gray)
                            Text("\(Int(heartRate))")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("bpm")
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var recentWorkoutsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Recent")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 1) {
                ForEach(0..<3) { index in
                    WorkoutSummaryCard(
                        activityType: .running,
                        distance: 3.2,
                        duration: 1800,
                        satsEarned: 250,
                        date: Date().addingTimeInterval(-Double(index) * 86400)
                    )
                }
            }
        }
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
}

struct WorkoutSummaryCard: View {
    let activityType: ActivityType
    let distance: Double
    let duration: TimeInterval
    let satsEarned: Int
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
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.white)
                
                Text(formatter.string(from: date))
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f km", distance))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    Text("\(satsEarned)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.white.opacity(0.02))
        )
    }
}

#Preview {
    DashboardView()
        .environmentObject(WorkoutSession())
        .environmentObject(LocationService())
        .environmentObject(HealthKitService())
        .environmentObject(AuthenticationService())
}