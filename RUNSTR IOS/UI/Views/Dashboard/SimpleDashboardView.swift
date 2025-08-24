import SwiftUI
import HealthKit

/// Ultra-simple dashboard that displays workouts from ALL fitness apps
struct SimpleDashboardView: View {
    @EnvironmentObject private var healthKit: SimpleHealthKitService
    @State private var selectedFilter: WorkoutFilter = .all
    
    private enum WorkoutFilter: String, CaseIterable {
        case all = "All"
        case running = "Running" 
        case walking = "Walking"
        case cycling = "Cycling"
        case recent = "Recent"
        
        var icon: String {
            switch self {
            case .all: return "figure.mixed.cardio"
            case .running: return "figure.run"
            case .walking: return "figure.walk"
            case .cycling: return "figure.outdoor.cycle"
            case .recent: return "clock"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // Stats header
                if !filteredWorkouts.isEmpty {
                    statsHeaderView
                        .padding()
                        .background(Color(.systemGroupedBackground))
                }
                
                // Filter picker
                filterPickerView
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                // Workouts list
                workoutsList
            }
            .navigationTitle("Dashboard")
            .task {
                await loadWorkouts()
            }
            .refreshable {
                await loadWorkouts()
            }
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeaderView: some View {
        HStack(spacing: 20) {
            SimpleStatCard(
                title: "Workouts",
                value: "\(filteredWorkouts.count)",
                icon: "figure.mixed.cardio"
            )
            
            SimpleStatCard(
                title: "Distance", 
                value: totalDistanceFormatted,
                icon: "ruler"
            )
            
            SimpleStatCard(
                title: "Time",
                value: totalTimeFormatted,
                icon: "clock"
            )
        }
    }
    
    // MARK: - Filter Picker
    
    private var filterPickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WorkoutFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.caption)
                            Text(filter.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedFilter == filter ? Color.accentColor : Color(.systemGray5)
                        )
                        .foregroundColor(
                            selectedFilter == filter ? .white : .primary
                        )
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Workouts List
    
    private var workoutsList: some View {
        Group {
            if healthKit.workouts.isEmpty && healthKit.isAuthorized {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No workouts found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Start a workout or use any fitness app\nto see your activity here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    NavigationLink("Start Workout") {
                        SimpleWorkoutView()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if !healthKit.isAuthorized {
                // Permission required
                VStack(spacing: 20) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("HealthKit Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Grant access to view workouts from all your fitness apps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Grant Access") {
                        Task {
                            let _ = await healthKit.requestAuthorization()
                            if healthKit.isAuthorized {
                                await loadWorkouts()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                // Workouts list
                List(filteredWorkouts, id: \.uuid) { workout in
                    SimpleWorkoutRowView(workout: workout)
                        .listRowBackground(Color(.systemBackground))
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredWorkouts: [HKWorkout] {
        switch selectedFilter {
        case .all:
            return healthKit.workouts
        case .running:
            return healthKit.getWorkouts(for: .running)
        case .walking:
            return healthKit.getWorkouts(for: .walking)
        case .cycling:
            return healthKit.getWorkouts(for: .cycling)
        case .recent:
            return healthKit.getRecentWorkouts()
        }
    }
    
    private var totalDistanceFormatted: String {
        let totalMeters = filteredWorkouts.compactMap { $0.totalDistance?.doubleValue(for: .meter()) }.reduce(0, +)
        let totalKm = totalMeters / 1000
        return String(format: "%.1f km", totalKm)
    }
    
    private var totalTimeFormatted: String {
        let totalSeconds = filteredWorkouts.map { $0.duration }.reduce(0, +)
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Actions
    
    private func loadWorkouts() async {
        if !healthKit.isAuthorized {
            let authorized = await healthKit.requestAuthorization()
            if !authorized {
                return
            }
        }
        
        await healthKit.loadAllWorkouts()
    }
}

// MARK: - Supporting Views

struct SimpleStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct SimpleWorkoutRowView: View {
    let workout: HKWorkout
    
    var body: some View {
        HStack {
            // Activity icon
            VStack {
                Text(workout.workoutActivityType.emoji)
                    .font(.title2)
                
                Text(workout.workoutActivityType.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                // Date and source app
                HStack {
                    Text(workout.startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    let sourceName = workout.sourceRevision.source.name
                    Text(sourceName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
                
                // Workout stats
                HStack(spacing: 16) {
                    Label(workout.distanceFormatted, systemImage: "ruler")
                    Label(workout.durationFormatted, systemImage: "clock")
                    Label(workout.caloriesFormatted, systemImage: "flame.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SimpleDashboardView()
        .environmentObject(SimpleHealthKitService())
}