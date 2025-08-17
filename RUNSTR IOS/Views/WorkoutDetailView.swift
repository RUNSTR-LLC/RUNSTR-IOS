import SwiftUI
import MapKit

struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var workoutStorage: WorkoutStorage
    @EnvironmentObject var unitPreferences: UnitPreferencesService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showShareOptions = false
    @State private var isPublishingPost = false
    @State private var isPublishingRecord = false
    @State private var publishPostSuccess = false
    @State private var publishRecordSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header with activity type and date
                    headerSection
                    
                    // Main metrics grid
                    metricsGrid
                    
                    // Map view if GPS data available
                    if !workout.locations.isEmpty {
                        mapSection
                    }
                    
                    // Pace chart
                    if workout.splits.count > 1 {
                        paceChartSection
                    }
                    
                    // Heart rate data if available
                    if let avgHR = workout.averageHeartRate {
                        heartRateSection(avgHR: avgHR)
                    }
                    
                    // Share/Export options
                    shareSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showShareOptions) {
            ShareOptionsView(workout: workout)
        }
        .alert("Published to Nostr", isPresented: $publishPostSuccess) {
            Button("OK") { }
        } message: {
            Text("Your workout has been published as a kind 1301 event")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: RunstrSpacing.sm) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.runstrWhite)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(workout.activityType.displayName)
                        .font(.runstrSubheadline)
                        .foregroundColor(.runstrWhite)
                    
                    Text(workout.startTime.formatted(.dateTime.weekday().month().day()))
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
            }
            
            Text(workout.startTime.formatted(.dateTime.hour().minute()))
                .font(.runstrTitle)
                .foregroundColor(.runstrWhite)
        }
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RunstrSpacing.md) {
            // Distance
            MetricCard(
                icon: "location.fill",
                title: "Distance",
                value: String(format: "%.2f", workout.distanceInPreferredUnits(unitService: unitPreferences)),
                unit: workout.distanceUnit(unitService: unitPreferences)
            )
            
            // Duration
            MetricCard(
                icon: "timer",
                title: "Duration",
                value: workout.durationFormatted,
                unit: ""
            )
            
            // Pace
            MetricCard(
                icon: "speedometer",
                title: "Avg Pace",
                value: String(format: "%.1f", workout.paceInPreferredUnits(unitService: unitPreferences)),
                unit: workout.paceUnit(unitService: unitPreferences)
            )
            
            // Calories
            if let calories = workout.calories {
                MetricCard(
                    icon: "flame.fill",
                    title: "Calories",
                    value: String(format: "%.0f", calories),
                    unit: "kcal"
                )
            }
            
            // Elevation
            if let elevation = workout.elevationGain {
                MetricCard(
                    icon: "triangle.fill",
                    title: "Elevation",
                    value: String(format: "%.0f", elevation),
                    unit: "m"
                )
            }
            
            // Steps
            if let steps = workout.steps {
                MetricCard(
                    icon: "shoeprints.fill",
                    title: "Steps",
                    value: String(format: "%.0f", steps),
                    unit: ""
                )
            }
        }
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
            Text("Route")
                .font(.runstrSubheadline)
                .foregroundColor(.runstrWhite)
            
            if let region = workout.mapRegion {
                Map(position: .constant(MapCameraPosition.region(region)))
                .frame(height: 200)
                .cornerRadius(RunstrRadius.sm)
                .allowsHitTesting(false)
            }
        }
    }
    
    private var paceChartSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
            Text("Pace by Kilometer")
                .font(.runstrSubheadline)
                .foregroundColor(.runstrWhite)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RunstrSpacing.xs) {
                    ForEach(Array(workout.splits.enumerated()), id: \.offset) { index, split in
                        VStack(spacing: 4) {
                            // Bar height based on pace (inverted - faster = taller)
                            let maxPace = workout.splits.map { $0.pace }.max() ?? 10
                            let minPace = workout.splits.map { $0.pace }.min() ?? 5
                            let normalizedHeight = 1 - ((split.pace - minPace) / (maxPace - minPace))
                            
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 30, height: CGFloat(normalizedHeight) * 100 + 20)
                            
                            Text("\(index + 1)")
                                .font(.runstrSmall)
                                .foregroundColor(.runstrGray)
                            
                            Text(String(format: "%.1f", split.pace))
                                .font(.runstrSmall)
                                .foregroundColor(.runstrWhite)
                        }
                    }
                }
                .padding(.vertical, RunstrSpacing.sm)
            }
            .runstrCard()
        }
    }
    
    private func heartRateSection(avgHR: Double) -> some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Heart Rate")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Average")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("\(Int(avgHR)) bpm")
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                }
                
                Spacer()
                
                if let maxHR = workout.maxHeartRate {
                    VStack(alignment: .leading) {
                        Text("Maximum")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                        Text("\(Int(maxHR)) bpm")
                            .font(.runstrBody)
                            .foregroundColor(.runstrWhite)
                    }
                }
            }
            .padding(RunstrSpacing.md)
            .runstrCard()
        }
    }
    
    private var shareSection: some View {
        VStack(spacing: RunstrSpacing.md) {
            Button {
                publishToNostr()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Publish to Nostr")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RunstrSpacing.md)
            }
            .buttonStyle(RunstrPrimaryButton())
            .disabled(isPublishingPost)
            
            Button {
                showShareOptions = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up.on.square")
                    Text("Export Workout")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RunstrSpacing.md)
            }
            .buttonStyle(RunstrSecondaryButton())
        }
    }
    
    private func publishToNostr() {
        isPublishingPost = true
        Task {
            let success = await nostrService.publishWorkoutEvent(workout)
            await MainActor.run {
                isPublishingPost = false
                if success {
                    publishPostSuccess = true
                }
            }
        }
    }
}

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
                Text(title)
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
            }
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.runstrSmall)
                        .foregroundColor(.runstrGray)
                }
            }
        }
        .padding(RunstrSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .runstrCard()
    }
}

struct ShareOptionsView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: RunstrSpacing.lg) {
                Text("Export Options")
                    .font(.runstrTitle)
                    .foregroundColor(.runstrWhite)
                
                Button {
                    exportAsJSON()
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Export as JSON")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RunstrSpacing.md)
                }
                .buttonStyle(RunstrSecondaryButton())
                
                Button {
                    exportAsGPX()
                } label: {
                    HStack {
                        Image(systemName: "map")
                        Text("Export as GPX")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RunstrSpacing.md)
                }
                .buttonStyle(RunstrSecondaryButton())
                .disabled(workout.locations.isEmpty)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.runstrGray)
            }
            .padding(RunstrSpacing.lg)
            .background(Color.runstrBackground)
        }
    }
    
    private func exportAsJSON() {
        // TODO: Implement JSON export
        dismiss()
    }
    
    private func exportAsGPX() {
        // TODO: Implement GPX export
        dismiss()
    }
}

#Preview {
    WorkoutDetailView(workout: Workout(
        activityType: .running,
        startTime: Date(),
        endTime: Date().addingTimeInterval(1800),
        distance: 5000,
        calories: 350,
        averageHeartRate: 145,
        maxHeartRate: 165,
        elevationGain: 50,
        steps: 6000,
        locations: []
    ))
    .environmentObject(NostrService())
    .environmentObject(WorkoutStorage())
}