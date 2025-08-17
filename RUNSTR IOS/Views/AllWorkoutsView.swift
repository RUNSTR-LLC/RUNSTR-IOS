import SwiftUI

struct AllWorkoutsView: View {
    @EnvironmentObject var workoutStorage: WorkoutStorage
    @EnvironmentObject var unitPreferences: UnitPreferencesService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFilter: ActivityType? = nil
    @State private var sortOrder: SortOrder = .dateDescending
    
    private var filteredWorkouts: [Workout] {
        let workouts = selectedFilter == nil ? 
            workoutStorage.workouts :
            workoutStorage.getWorkouts(for: selectedFilter!)
        
        switch sortOrder {
        case .dateDescending:
            return workouts.sorted { $0.startTime > $1.startTime }
        case .dateAscending:
            return workouts.sorted { $0.startTime < $1.startTime }
        case .distanceDescending:
            return workouts.sorted { $0.distance > $1.distance }
        case .durationDescending:
            return workouts.sorted { $0.duration > $1.duration }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with filters
                headerSection
                
                // Workouts list
                if filteredWorkouts.isEmpty {
                    emptyState
                } else {
                    workoutsList
                }
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: RunstrSpacing.md) {
            // Title and close button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.runstrWhite)
                }
                
                Spacer()
                
                Text("All Workouts")
                    .font(.runstrTitle)
                    .foregroundColor(.runstrWhite)
                
                Spacer()
                
                // Invisible spacer for centering
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RunstrSpacing.sm) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedFilter == nil
                    ) {
                        selectedFilter = nil
                    }
                    
                    ForEach(ActivityType.allCases, id: \.self) { activityType in
                        FilterChip(
                            title: activityType.displayName,
                            isSelected: selectedFilter == activityType
                        ) {
                            selectedFilter = activityType
                        }
                    }
                }
                .padding(.horizontal, RunstrSpacing.md)
            }
            
            // Sort options
            HStack {
                Text("Sort by:")
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
                
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(order.displayName) {
                            sortOrder = order
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sortOrder.displayName)
                            .font(.runstrCaption)
                            .foregroundColor(.runstrWhite)
                        Image(systemName: "chevron.down")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                }
                
                Spacer()
                
                Text("\(filteredWorkouts.count) workouts")
                    .font(.runstrCaption)
                    .foregroundColor(.runstrGray)
            }
            .padding(.horizontal, RunstrSpacing.md)
        }
        .padding(.top, RunstrSpacing.md)
        .background(Color.runstrBackground)
    }
    
    private var emptyState: some View {
        VStack(spacing: RunstrSpacing.lg) {
            Spacer()
            
            Image(systemName: selectedFilter?.systemImageName ?? "figure.run")
                .font(.system(size: 60))
                .foregroundColor(.runstrGray)
            
            Text(selectedFilter == nil ? "No workouts yet" : "No \(selectedFilter!.displayName.lowercased()) workouts")
                .font(.runstrSubheadline)
                .foregroundColor(.runstrWhite)
            
            Text("Start a workout to see it appear here")
                .font(.runstrBody)
                .foregroundColor(.runstrGray)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(RunstrSpacing.lg)
    }
    
    private var workoutsList: some View {
        ScrollView {
            LazyVStack(spacing: RunstrSpacing.xs) {
                ForEach(filteredWorkouts, id: \.id) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        WorkoutRowView(workout: workout, unitPreferences: unitPreferences)
                            .padding(.horizontal, RunstrSpacing.md)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if workout.id != filteredWorkouts.last?.id {
                        Divider()
                            .background(Color.runstrGray.opacity(0.3))
                            .padding(.horizontal, RunstrSpacing.md)
                    }
                }
            }
            .padding(.vertical, RunstrSpacing.sm)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.runstrCaption)
                .foregroundColor(isSelected ? .black : .runstrWhite)
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.vertical, RunstrSpacing.sm)
                .background(isSelected ? Color.white : Color.runstrGray.opacity(0.2))
                .cornerRadius(RunstrRadius.sm)
        }
    }
}

enum SortOrder: CaseIterable {
    case dateDescending
    case dateAscending
    case distanceDescending
    case durationDescending
    
    var displayName: String {
        switch self {
        case .dateDescending: return "Newest First"
        case .dateAscending: return "Oldest First"
        case .distanceDescending: return "Longest Distance"
        case .durationDescending: return "Longest Duration"
        }
    }
}

#Preview {
    AllWorkoutsView()
        .environmentObject(WorkoutStorage())
}