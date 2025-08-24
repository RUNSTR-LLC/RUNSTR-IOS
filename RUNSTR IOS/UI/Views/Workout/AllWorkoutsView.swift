import SwiftUI

enum WorkoutViewSource: String, CaseIterable {
    case all = "all"
    case local = "local"
    case nostr = "nostr"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .local: return "Local"
        case .nostr: return "Nostr"
        }
    }
}

struct AllWorkoutsView: View {
    @EnvironmentObject var workoutStorage: WorkoutStorage
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var unitPreferences: UnitPreferencesService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFilter: ActivityType? = nil
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var selectedSource: WorkoutViewSource = .all
    @State private var isLoadingNostr = false
    @State private var lastNostrRefresh: Date? = nil
    
    private var filteredWorkouts: [Workout] {
        // Combine workouts based on selected source
        var allWorkouts: [Workout]
        switch selectedSource {
        case .all:
            allWorkouts = workoutStorage.workouts + workoutStorage.nostrWorkouts
        case .local:
            allWorkouts = workoutStorage.workouts
        case .nostr:
            allWorkouts = workoutStorage.nostrWorkouts
        }
        
        // Filter by activity type if selected
        let workouts = selectedFilter == nil ? 
            allWorkouts :
            allWorkouts.filter { $0.activityType == selectedFilter! }
        
        // Sort workouts
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
            .onAppear {
                // Load cached Nostr workouts first
                workoutStorage.loadCachedNostrWorkouts()
                
                // Then fetch fresh data if needed
                Task {
                    await loadNostrWorkouts()
                }
            }
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
            }
            
            // Source toggle (Local/Nostr/All)
            HStack(spacing: RunstrSpacing.sm) {
                ForEach(WorkoutViewSource.allCases, id: \.self) { source in
                    Button {
                        selectedSource = source
                        if source == .nostr && workoutStorage.nostrWorkouts.isEmpty {
                            Task {
                                await loadNostrWorkouts()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if source == .nostr && isLoadingNostr {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .progressViewStyle(CircularProgressViewStyle(tint: selectedSource == source ? .black : .runstrWhite))
                            }
                            
                            Text(source.displayName)
                                .font(.runstrCaption)
                                .foregroundColor(selectedSource == source ? .black : .runstrWhite)
                        }
                        .padding(.horizontal, RunstrSpacing.md)
                        .padding(.vertical, RunstrSpacing.sm)
                        .background(selectedSource == source ? Color.white : Color.runstrGray.opacity(0.2))
                        .cornerRadius(RunstrRadius.sm)
                    }
                }
            }
            .padding(.horizontal, RunstrSpacing.md)
            
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
                        HStack {
                            WorkoutRowView(workout: workout, unitPreferences: unitPreferences)
                            
                            // Source indicator
                            if workout.source == .nostr {
                                Image(systemName: "globe")
                                    .font(.runstrCaption)
                                    .foregroundColor(.runstrGray)
                                    .padding(.trailing, RunstrSpacing.sm)
                            }
                        }
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
        .refreshable {
            await loadNostrWorkouts(forceRefresh: true)
        }
    }
    
    // MARK: - Nostr Loading Functions
    
    @MainActor
    private func loadNostrWorkouts(forceRefresh: Bool = false) async {
        // Don't load if we already have data and it's fresh (unless force refresh)
        if !forceRefresh, !workoutStorage.nostrWorkouts.isEmpty,
           let lastRefresh = lastNostrRefresh,
           Date().timeIntervalSince(lastRefresh) < 300 { // 5 minutes
            print("✅ Using cached Nostr workouts (last refresh: \(lastRefresh))")
            return
        }
        
        guard nostrService.userKeyPair != nil else {
            print("⚠️ No Nostr keys available - cannot fetch workout history")
            return
        }
        
        isLoadingNostr = true
        
        print("🔍 Fetching Nostr workout history...")
        let fetchedWorkouts = await nostrService.fetchUserWorkouts(limit: 50)
        
        // Cache the workouts in WorkoutStorage
        workoutStorage.cacheNostrWorkouts(fetchedWorkouts)
        lastNostrRefresh = Date()
        
        print("✅ Loaded \(workoutStorage.nostrWorkouts.count) Nostr workouts")
        
        isLoadingNostr = false
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
        .environmentObject(NostrService())
        .environmentObject(UnitPreferencesService())
}