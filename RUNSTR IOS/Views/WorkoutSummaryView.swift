import SwiftUI
import MapKit

struct WorkoutSummaryView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutStorage: WorkoutStorage
    @EnvironmentObject var nostrService: NostrService
    
    private var region: MKCoordinateRegion
    @State private var showShareSheet = false
    @State private var showNostrComposer = false
    @State private var nostrMessage = ""
    @State private var isPostingToNostr = false
    
    init(workout: Workout) {
        self.workout = workout
        
        // Initialize map region based on workout route
        if let route = workout.route, !route.isEmpty {
            let center = route[route.count / 2] // Middle of route
            self.region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        } else {
            self.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Route Map (temporarily disabled for debugging)
                    // if workout.route != nil && !workout.route!.isEmpty {
                    //     routeMapSection
                    // }
                    
                    // Main Stats
                    mainStatsSection
                    
                    // Secondary Stats
                    secondaryStatsSection
                    
                    // Rewards Section
                    rewardsSection
                    
                    // Nostr Posting Section (temporarily disabled for debugging)
                    // nostrPostingSection
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .background(Color.black)
            .foregroundColor(.white)
            .navigationTitle("Workout Complete!")
            .navigationBarTitleDisplayMode(.large)
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
        // Sheets temporarily disabled for debugging
        // .sheet(isPresented: $showShareSheet) {
        //     ShareSheet(workout: workout)
        // }
        // .sheet(isPresented: $showNostrComposer) {
        //     NostrComposerView(
        //         workout: workout,
        //         message: $nostrMessage,
        //         isPosting: $isPostingToNostr
        //     ) {
        //         Task {
        //             await postWorkoutToNostr()
        //         }
        //     }
        // }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
            
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
            
            Map(position: .constant(MapCameraPosition.region(region)))
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
            
            // Activity-specific third stat
            switch workout.activityType {
            case .running:
                StatCard(
                    title: "Pace",
                    value: workout.pace,
                    icon: "speedometer",
                    color: .orange
                )
            case .cycling:
                StatCard(
                    title: "Speed",
                    value: formatSpeed(),
                    icon: "speedometer",
                    color: .orange
                )
            case .walking:
                if let steps = workout.steps, steps > 0 {
                    StatCard(
                        title: "Steps",
                        value: "\(steps)",
                        icon: "figure.walk",
                        color: .orange
                    )
                } else {
                    StatCard(
                        title: "Pace",
                        value: workout.pace,
                        icon: "speedometer",
                        color: .orange
                    )
                }
            }
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
                
                // Elevation gain and loss - custom display for directional indicators
                let hasElevationGain = workout.elevationGain != nil && workout.elevationGain! > 0
                let hasElevationLoss = workout.elevationLoss != nil && workout.elevationLoss! > 0
                
                if hasElevationGain || hasElevationLoss {
                    ElevationStatView(
                        elevationGain: hasElevationGain ? workout.elevationGain! : nil,
                        elevationLoss: hasElevationLoss ? workout.elevationLoss! : nil
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
                    Text("\(workout.rewardAmount ?? 0) sats")
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
    
    private var nostrPostingSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Share to Nostr")
                    .font(.headline)
                Spacer()
            }
            
            Button {
                showNostrComposer = true
            } label: {
                HStack {
                    Image(systemName: "at")
                    Text("Post to Nostr")
                    if isPostingToNostr {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(12)
            }
            .disabled(isPostingToNostr)
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
                .background(Color.runstrGray)
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
    
    private func formatSpeed() -> String {
        // Calculate speed from distance and duration
        guard workout.duration > 0 else { return "0.0 km/h" } // Avoid division by zero
        let speedKmh = workout.distance / 1000 / (workout.duration / 3600)
        let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
        
        if useMetric {
            return String(format: "%.1f km/h", speedKmh)
        } else {
            let speedMph = speedKmh * 0.621371
            return String(format: "%.1f mph", speedMph)
        }
    }
    
    private func postWorkoutToNostr() async {
        isPostingToNostr = true
        
        // Create workout summary content matching the NostrService format
        let activityText: String
        switch workout.activityType {
        case .running:
            activityText = "run"
        case .cycling:
            activityText = "ride"
        case .walking:
            activityText = "walk"
        }
        
        var workoutContent = "Just completed a \(activityText) with RUNSTR! "
        
        // Add activity-specific emoji
        switch workout.activityType {
        case .running:
            workoutContent += "🏃‍♂️💨"
        case .cycling:
            workoutContent += "🚴‍♂️💨"
        case .walking:
            workoutContent += "🚶‍♂️💨"
        }
        
        workoutContent += """
        
        
        ⏱️ Duration: \(workout.durationFormatted)
        📏 Distance: \(workout.distanceFormatted)
        """
        
        // Add activity-specific metrics
        switch workout.activityType {
        case .running:
            workoutContent += "\n⚡ Pace: \(workout.pace)"
        case .cycling:
            // Calculate and show speed for cycling
            guard workout.duration > 0 else { break }
            let speedKmh = workout.distance / 1000 / (workout.duration / 3600)
            let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
            if useMetric {
                workoutContent += "\n🚴‍♂️ Speed: \(String(format: "%.1f", speedKmh)) km/h"
            } else {
                let speedMph = speedKmh * 0.621371
                workoutContent += "\n🚴‍♂️ Speed: \(String(format: "%.1f", speedMph)) mph"
            }
        case .walking:
            // Show steps for walking if available, otherwise show pace
            if let steps = workout.steps, steps > 0 {
                workoutContent += "\n👣 Steps: \(steps)"
            } else {
                workoutContent += "\n⚡ Pace: \(workout.pace)"
            }
        }
        
        // Add calories if available
        if let calories = workout.calories {
            workoutContent += "\n🔥 Calories: \(Int(calories)) kcal"
        }
        
        // Add elevation data if available
        if let elevationGain = workout.elevationGain, elevationGain > 0 {
            workoutContent += "\n\n🏔️ Elevation Gain: \(Int(elevationGain)) m"
        }
        
        // Add custom message if provided
        if !nostrMessage.isEmpty {
            workoutContent += "\n\n\(nostrMessage)"
        }
        
        workoutContent += "\n#RUNSTR #\(workout.activityType.displayName)"
        
        let success = await nostrService.publishTextNote(workoutContent)
        
        await MainActor.run {
            isPostingToNostr = false
            if success {
                showNostrComposer = false
                nostrMessage = "" // Clear the message
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

struct ElevationStatView: View {
    let elevationGain: Double?
    let elevationLoss: Double?
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mountain.2.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Elevation")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 1) {
                    if let gain = elevationGain {
                        HStack(spacing: 2) {
                            Text("↗")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("\(Int(gain))m")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
                    if let loss = elevationLoss {
                        HStack(spacing: 2) {
                            Text("↘")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("\(Int(loss))m")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
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
                        Text("₿ Earned: \(workout.rewardAmount ?? 0) sats")
                        Spacer()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                Button("Copy to Clipboard") {
                    let activityText: String
                    switch workout.activityType {
                    case .running:
                        activityText = "run"
                    case .cycling:
                        activityText = "ride"
                    case .walking:
                        activityText = "walk"
                    }
                    
                    var shareText = """
                    Just completed a \(activityText)!
                    📏 Distance: \(workout.distanceFormatted)
                    ⏱️ Time: \(workout.durationFormatted)
                    """
                    
                    // Add activity-specific metrics
                    switch workout.activityType {
                    case .running:
                        shareText += "\n⚡ Pace: \(workout.pace)"
                    case .cycling:
                        // Calculate and show speed for cycling
                        guard workout.duration > 0 else { break }
                        let speedKmh = workout.distance / 1000 / (workout.duration / 3600)
                        let useMetric = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
                        if useMetric {
                            shareText += "\n🚴‍♂️ Speed: \(String(format: "%.1f", speedKmh)) km/h"
                        } else {
                            let speedMph = speedKmh * 0.621371
                            shareText += "\n🚴‍♂️ Speed: \(String(format: "%.1f", speedMph)) mph"
                        }
                    case .walking:
                        // Show steps for walking if available, otherwise show pace
                        if let steps = workout.steps, steps > 0 {
                            shareText += "\n👣 Steps: \(steps)"
                        } else {
                            shareText += "\n⚡ Pace: \(workout.pace)"
                        }
                    }
                    
                    shareText += "\n₿ Earned: \(workout.rewardAmount ?? 0) sats with RUNSTR"
                    UIPasteboard.general.string = shareText
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
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

struct NostrComposerView: View {
    let workout: Workout
    @Binding var message: String
    @Binding var isPosting: Bool
    let onPost: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workout Summary")
                        .font(.headline)
                    
                    Text("""
                    🏃‍♂️ \(workout.activityType.displayName)
                    📏 Distance: \(workout.distanceFormatted)
                    ⏱️ Duration: \(workout.durationFormatted)
                    ⚡ Pace: \(workout.pace)
                    
                    Posted from RUNSTR iOS
                    """)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add your message (optional)")
                        .font(.headline)
                    
                    TextEditor(text: $message)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Button {
                    onPost()
                } label: {
                    HStack {
                        if isPosting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isPosting ? "Posting..." : "Post to Nostr")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .cornerRadius(12)
                }
                .disabled(isPosting)
            }
            .padding()
            .navigationTitle("Share to Nostr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isPosting)
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
    func createSampleWorkout() -> Workout {
        var workout = Workout(activityType: .running, userID: "test")
        workout.distance = 5200 // 5.2km
        workout.duration = 1500 // 25 minutes
        workout.averagePace = 4.8 // 4:48 min/km
        workout.calories = 320
        workout.averageHeartRate = 155
        workout.rewardAmount = 450
        return workout
    }
    
    return WorkoutSummaryView(workout: createSampleWorkout())
        .environmentObject(WorkoutStorage())
        .environmentObject(NostrService())
}