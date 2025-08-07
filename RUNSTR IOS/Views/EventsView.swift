import SwiftUI

struct EventsView: View {
    @State private var selectedTab: EventTab = .discover
    @State private var selectedActivityType: ActivityType = .running
    @State private var showingWalletView = false
    @State private var showingSettingsView = false
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var authService: AuthenticationService
    
    // Mock wallet balance to match dashboard
    @State private var mockWalletBalance: Int = 2500
    
    var body: some View {
        NavigationView {
            eventsContent
        }
        .sheet(isPresented: $showingWalletView) {
            WalletView()
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsView()
        }
        .onAppear {
            Task {
                await eventService.fetchPublicEvents()
                if let currentUser = authService.currentUser {
                    await eventService.fetchUserRegistrations(userID: currentUser.id)
                }
            }
        }
    }
    
    private var eventsContent: some View {
        VStack(spacing: 0) {
            // Header with activity selector and settings
            headerSection
            
            // Tab selector
            HStack(spacing: 0) {
                ForEach(EventTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: RunstrSpacing.xs) {
                            Text(tab.displayName)
                                .font(.runstrBody)
                                .fontWeight(.medium)
                                .foregroundColor(selectedTab == tab ? .runstrWhite : .runstrGray)
                            
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(selectedTab == tab ? .runstrWhite : .clear)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, RunstrSpacing.md)
            .padding(.top, RunstrSpacing.sm)
            .background(Color.runstrBackground)
            
            // Content
            TabView(selection: $selectedTab) {
                EventDiscoveryView()
                    .environmentObject(eventService)
                    .environmentObject(authService)
                    .tag(EventTab.discover)
                
                MyEventsView()
                    .environmentObject(eventService)
                    .environmentObject(authService)
                    .tag(EventTab.myEvents)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .background(Color.runstrBackground)
        .navigationBarHidden(true)
    }
    
    private var headerSection: some View {
        HStack {
            // Dynamic activity selector
            Menu {
                ForEach(ActivityType.allCases, id: \.self) { activityType in
                    Button {
                        selectedActivityType = activityType
                    } label: {
                        HStack {
                            Image(systemName: activityType.systemImageName)
                            Text(activityType.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: RunstrSpacing.sm) {
                    Image(systemName: selectedActivityType.systemImageName)
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                    
                    Text(selectedActivityType.displayName.uppercased())
                        .font(.runstrCaption)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.down")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.vertical, RunstrSpacing.sm)
            }
            .runstrCard()
            
            Spacer()
            
            // Wallet balance button
            Button {
                showingWalletView = true
            } label: {
                Text("\(mockWalletBalance)")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.bold)
                    .padding(.horizontal, RunstrSpacing.md)
                    .padding(.vertical, RunstrSpacing.sm)
            }
            .runstrCard()
            
            // Create Event Button (for Organizations)
            if let currentUser = authService.currentUser, eventService.canCreateEvent(user: currentUser) {
                Button {
                    // TODO: Show event creation sheet
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.runstrWhite)
                }
            }
            
            // Settings button
            Button {
                showingSettingsView = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
            }
        }
        .padding(.horizontal, RunstrSpacing.md)
        .padding(.top, RunstrSpacing.md)
    }
}

enum EventTab: String, CaseIterable {
    case discover = "discover"
    case myEvents = "my_events"
    
    var displayName: String {
        switch self {
        case .discover: return "Discover"
        case .myEvents: return "My Events"
        }
    }
}

struct EventDiscoveryView: View {
    @State private var searchText = ""
    @State private var selectedDifficulty: EventDifficulty?
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and filters
            VStack(spacing: 12) {
                TextField("Search events...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .foregroundColor(.runstrWhite)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button {
                            selectedDifficulty = nil
                        } label: {
                            Text("All")
                                .font(.subheadline)
                                .foregroundColor(selectedDifficulty == nil ? .runstrBackground : .runstrWhite)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedDifficulty == nil ? Color.runstrWhite : Color.runstrGray.opacity(0.3))
                                .cornerRadius(20)
                        }
                        
                        ForEach(EventDifficulty.allCases, id: \.self) { difficulty in
                            Button {
                                selectedDifficulty = difficulty
                            } label: {
                                Text(difficulty.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(selectedDifficulty == difficulty ? .runstrBackground : .runstrWhite)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedDifficulty == difficulty ? Color.runstrWhite : Color.runstrGray.opacity(0.3))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .background(Color.runstrGray.opacity(0.1))
            
            // Events list
            ScrollView {
                LazyVStack(spacing: 16) {
                    if eventService.isLoading {
                        ProgressView("Loading events...")
                            .foregroundColor(.runstrWhite)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 50)
                    } else if filteredEvents.isEmpty {
                        VStack(spacing: 16) {
                            Text("No events available")
                                .foregroundColor(.runstrGray)
                                .padding(.top, 50)
                            
                            if let currentUser = authService.currentUser, eventService.canCreateEvent(user: currentUser) {
                                Text("Be the first to create an event!")
                                    .font(.subheadline)
                                    .foregroundColor(.runstrGray)
                            }
                        }
                    } else {
                        ForEach(filteredEvents) { event in
                            EventCard(event: event)
                                .environmentObject(eventService)
                                .environmentObject(authService)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var filteredEvents: [Event] {
        eventService.events.filter { event in
            (searchText.isEmpty || event.name.localizedCaseInsensitiveContains(searchText)) &&
            (selectedDifficulty == nil || event.difficulty == selectedDifficulty)
        }
    }
}

struct MyEventsView: View {
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if eventService.isLoading {
                    ProgressView("Loading your events...")
                        .foregroundColor(.runstrWhite)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                } else if myEvents.isEmpty {
                    VStack(spacing: 16) {
                        Text("You haven't joined any events yet")
                            .foregroundColor(.runstrGray)
                            .padding(.top, 50)
                        
                        Text("Explore events in the Discover tab to get started!")
                            .font(.subheadline)
                            .foregroundColor(.runstrGray)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ForEach(myEvents) { event in
                        EventCard(event: event, showProgress: true)
                            .environmentObject(eventService)
                            .environmentObject(authService)
                    }
                }
            }
            .padding()
        }
        .background(Color.runstrBackground)
    }
    
    private var myEvents: [Event] {
        // Filter events where user is registered
        return eventService.events.filter { event in
            eventService.eventRegistrations[event.id] != nil
        }
    }
}

struct EventCard: View {
    let event: Event
    let showProgress: Bool
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var authService: AuthenticationService
    @State private var isRegistering = false
    
    init(event: Event, showProgress: Bool = false) {
        self.event = event
        self.showProgress = showProgress
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.runstrWhite)
                    
                    Text(event.description)
                        .font(.subheadline)
                        .foregroundColor(.runstrGray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(event.difficulty.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.runstrBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(difficultyColor)
                        .cornerRadius(8)
                    
                    Text(timeRemainingText)
                        .font(.caption)
                        .foregroundColor(.runstrGray)
                }
            }
            
            // Goal and prize
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundColor(.runstrGray)
                    Text(goalText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.runstrWhite)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Prize Pool")
                        .font(.caption)
                        .foregroundColor(.runstrGray)
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrWhite)
                        Text("\(event.prizePool) sats")
                            .font(.runstrBody)
                            .fontWeight(.semibold)
                            .foregroundColor(.runstrWhite)
                    }
                }
            }
            
            // Progress (if showing)
            if showProgress {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your Progress")
                            .font(.caption)
                            .foregroundColor(.runstrGray)
                        
                        Spacer()
                        
                        Text(progressText)
                            .font(.caption)
                            .foregroundColor(.runstrGray)
                    }
                    
                    ProgressView(value: progressValue, total: event.targetValue)
                        .tint(.runstrWhite)
                }
            }
            
            // Participants and action button
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.runstrGray)
                    Text("\(event.participants.count) joined")
                        .font(.caption)
                        .foregroundColor(.runstrGray)
                }
                
                Spacer()
                
                Button(action: handleButtonAction) {
                    if isRegistering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .runstrBackground))
                            .scaleEffect(0.8)
                    } else {
                        Text(buttonText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.runstrBackground)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isUserRegistered ? Color.runstrGray : Color.runstrWhite)
                .cornerRadius(20)
                .disabled(isRegistering || event.hasEnded || !canJoin)
            }
        }
        .padding()
        .background(Color.runstrGray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Computed Properties
    
    private var difficultyColor: Color {
        switch event.difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .elite: return .red
        }
    }
    
    private var timeRemainingText: String {
        if event.hasEnded {
            return "Ended"
        } else if event.isActive {
            return "\(event.daysRemaining) days left"
        } else {
            return "Starts in \(event.daysRemaining) days"
        }
    }
    
    private var goalText: String {
        let value = Int(event.targetValue)
        return "\(value) \(event.goalType.unit)"
    }
    
    private var isUserRegistered: Bool {
        return eventService.eventRegistrations[event.id] != nil
    }
    
    private var canJoin: Bool {
        guard let currentUser = authService.currentUser else { return false }
        return eventService.canJoinEvent(user: currentUser) && !event.hasEnded
    }
    
    private var buttonText: String {
        if event.hasEnded {
            return "Ended"
        } else if isUserRegistered {
            return showProgress ? "View Details" : "Registered"
        } else {
            return "Join Event"
        }
    }
    
    private var progressValue: Double {
        eventService.eventProgress[event.id]?.currentValue ?? 0.0
    }
    
    private var progressText: String {
        let current = eventService.eventProgress[event.id]?.currentValue ?? 0.0
        let target = Int(event.targetValue)
        return "\(String(format: "%.1f", current))/\(target) \(event.goalType.unit)"
    }
    
    // MARK: - Actions
    
    private func handleButtonAction() {
        guard let currentUser = authService.currentUser else { return }
        
        if isUserRegistered || showProgress {
            // TODO: Show event details view
            print("Show event details for \(event.name)")
        } else {
            // Register for event
            Task {
                await registerForEvent(user: currentUser)
            }
        }
    }
    
    @MainActor
    private func registerForEvent(user: User) async {
        isRegistering = true
        
        let result = await eventService.registerForEvent(
            eventID: event.id,
            userID: user.id,
            userName: user.runstrNostrPublicKey, // Using RUNSTR npub as display name for now
            paymentAmount: 0 // Free events for now
        )
        
        switch result {
        case .success(let registration):
            print("✅ Successfully registered for event: \(event.name)")
        case .failure(let error):
            print("❌ Failed to register for event: \(error)")
            // TODO: Show error alert
        }
        
        isRegistering = false
    }
}


#Preview {
    EventsView()
}