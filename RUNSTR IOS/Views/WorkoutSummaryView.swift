import SwiftUI
import MapKit

struct WorkoutSummaryView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutStorage: WorkoutStorage
    
    @State private var region: MKCoordinateRegion
    @State private var showShareSheet = false
    
    init(workout: Workout) {
        self.workout = workout
        
        // Initialize map region based on workout route
        if let route = workout.route, !route.isEmpty {
            let center = route[route.count / 2] // Middle of route
            self._region = State(initialValue: MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            self._region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Route Map (if available)
                    if workout.route != nil && !workout.route!.isEmpty {
                        routeMapSection
                    }
                    
                    // Main Stats
                    mainStatsSection
                    
                    // Secondary Stats
                    secondaryStatsSection
                    
                    // Rewards Section
                    rewardsSection
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .background(Color.black)
            .foregroundColor(.white)
            .navigationTitle("Workout Complete!")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .onAppear {
            // Save workout to local storage
            workoutStorage.saveWorkout(workout)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(workout: workout)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Great job!")
                .font(.title)
                .fontWeight(.bold)
            
            Text(workout.activityType.displayName)
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(DateFormatter.workoutDate.string(from: workout.startTime))
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var routeMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Route")
                    .font(.headline)
                Spacer()
            }
            
            Map(coordinateRegion: $region)
                .frame(height: 200)
                .cornerRadius(12)
                .overlay(
                    // Route overlay would go here in production
                    Rectangle()
                        .fill(Color.clear)
                        .cornerRadius(12)
                )
        }
    }
    
    private var mainStatsSection: some View {
        HStack(spacing: 40) {
            StatCard(
                title: "Distance",
                value: workout.distanceFormatted,
                icon: "location.fill",
                color: .blue
            )
            
            StatCard(
                title: "Time",
                value: workout.durationFormatted,
                icon: "clock.fill",
                color: .green
            )
            
            StatCard(
                title: "Pace",
                value: workout.pace,
                icon: "speedometer",
                color: .orange
            )
        }
    }
    
    private var secondaryStatsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                if let calories = workout.calories {
                    SecondaryStatView(
                        title: "Calories",
                        value: "\(Int(calories))",
                        unit: "kcal",
                        icon: "flame.fill"
                    )
                }
                
                if let heartRate = workout.averageHeartRate {
                    SecondaryStatView(
                        title: "Avg Heart Rate",
                        value: "\(Int(heartRate))",
                        unit: "bpm",
                        icon: "heart.fill"
                    )
                }
                
                if let elevation = workout.elevationGain, elevation > 0 {
                    SecondaryStatView(
                        title: "Elevation",
                        value: "\(Int(elevation))",
                        unit: "m",
                        icon: "mountain.2.fill"
                    )
                }
            }
        }
    }
    
    private var rewardsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Bitcoin Rewards")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(workout.rewardAmount) sats")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Earned this workout")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button {
                showShareSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Workout")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Button {
                // View workout details or stats
                // This could navigate to a detailed view
            } label: {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("View Details")
                }
                .font(.headline)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SecondaryStatView: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack(spacing: 2) {
                    Text(value)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct ShareSheet: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Share your workout achievement!")
                    .font(.headline)
                    .padding()
                
                // Workout summary for sharing
                VStack(spacing: 16) {
                    HStack {
                        Text("🏃‍♂️ \(workout.activityType.displayName)")
                        Spacer()
                    }
                    
                    HStack {
                        Text("📏 Distance: \(workout.distanceFormatted)")
                        Spacer()
                    }
                    
                    HStack {
                        Text("⏱️ Time: \(workout.durationFormatted)")
                        Spacer()
                    }
                    
                    HStack {
                        Text("⚡ Pace: \(workout.pace)")
                        Spacer()
                    }
                    
                    HStack {
                        Text("₿ Earned: \(workout.rewardAmount) sats")
                        Spacer()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                Button("Copy to Clipboard") {
                    let shareText = """
                    Just completed a \(workout.activityType.displayName)!
                    📏 Distance: \(workout.distanceFormatted)
                    ⏱️ Time: \(workout.durationFormatted)
                    ⚡ Pace: \(workout.pace)
                    ₿ Earned: \(workout.rewardAmount) sats with RUNSTR
                    """
                    UIPasteboard.general.string = shareText
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.orange)
                .cornerRadius(12)
                .padding()
            }
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension DateFormatter {
    static let workoutDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    let sampleWorkout = Workout(activityType: .running, userID: "test")
    
    // Configure sample workout with realistic data
    var workout = sampleWorkout
    workout.distance = 5200 // 5.2km
    workout.duration = 1500 // 25 minutes
    workout.averagePace = 4.8 // 4:48 min/km
    workout.calories = 320
    workout.averageHeartRate = 155
    workout.rewardAmount = 450
    
    return WorkoutSummaryView(workout: workout)
        .environmentObject(WorkoutStorage())
}