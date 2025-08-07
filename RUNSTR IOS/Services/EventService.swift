import Foundation
import CloudKit
import Combine

class EventService: ObservableObject {
    // MARK: - Published Properties
    @Published var events: [Event] = []
    @Published var myEvents: [Event] = []
    @Published var eventRegistrations: [String: EventRegistration] = [:] // eventID -> registration
    @Published var eventProgress: [String: EventProgressCloudKit] = [:] // eventID -> progress
    @Published var eventLeaderboards: [String: [LeaderboardEntry]] = [:] // eventID -> leaderboard
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Internal Properties (accessible to extensions)
    let container: CKContainer
    let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()
    private var subscriptions: [CKSubscription] = []
    
    init() {
        container = CKContainer(identifier: "iCloud.com.runstr.ios")
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
        
        Task {
            await setupCloudKitSubscriptions()
            await loadInitialData()
        }
    }
    
    // MARK: - Event CRUD Operations
    
    /// Create a new event (Organization/Captain tier only)
    func createEvent(
        name: String,
        description: String,
        createdBy: String,
        startDate: Date,
        endDate: Date,
        goalType: EventGoalType,
        targetValue: Double,
        difficulty: EventDifficulty,
        eventType: EventType,
        prizePool: Int,
        maxParticipants: Int? = nil,
        entryRequirements: [EntryRequirement] = []
    ) async -> Result<Event, Error> {
        
        isLoading = true
        errorMessage = nil
        
        do {
            let event = Event(
                name: name,
                description: description,
                createdBy: createdBy,
                startDate: startDate,
                endDate: endDate,
                goalType: goalType,
                targetValue: targetValue,
                difficulty: difficulty,
                eventType: eventType,
                prizePool: prizePool
            )
            
            let record = event.toCKRecord(container: container)
            let savedRecord = try await publicDatabase.save(record)
            
            if let savedEvent = Event(record: savedRecord) {
                await MainActor.run {
                    events.append(savedEvent)
                    myEvents.append(savedEvent)
                    isLoading = false
                }
                
                print("✅ Event created successfully: \(savedEvent.name)")
                return .success(savedEvent)
            } else {
                throw EventServiceError.invalidEventData
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create event: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Failed to create event: \(error)")
            return .failure(error)
        }
    }
    
    /// Fetch all public events
    func fetchPublicEvents() async -> Result<[Event], Error> {
        isLoading = true
        errorMessage = nil
        
        do {
            let predicate = NSPredicate(value: true) // All public events
            let query = CKQuery(recordType: Event.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            let records = matchResults.compactMap { try? $0.1.get() }
            let fetchedEvents = records.compactMap { Event(record: $0) }
            
            await MainActor.run {
                events = fetchedEvents
                isLoading = false
            }
            
            print("✅ Fetched \(fetchedEvents.count) public events")
            return .success(fetchedEvents)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch events: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Failed to fetch public events: \(error)")
            return .failure(error)
        }
    }
    
    /// Fetch events created by a specific user
    func fetchMyCreatedEvents(userID: String) async -> Result<[Event], Error> {
        do {
            let predicate = NSPredicate(format: "createdBy == %@", userID)
            let query = CKQuery(recordType: Event.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
            
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            let records = matchResults.compactMap { try? $0.1.get() }
            let createdEvents = records.compactMap { Event(record: $0) }
            
            await MainActor.run {
                myEvents = createdEvents
            }
            
            print("✅ Fetched \(createdEvents.count) events created by user")
            return .success(createdEvents)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch my events: \(error.localizedDescription)"
            }
            print("❌ Failed to fetch my created events: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Event Registration
    
    /// Register for an event
    func registerForEvent(eventID: String, userID: String, userName: String, paymentAmount: Int = 0) async -> Result<EventRegistration, Error> {
        isLoading = true
        errorMessage = nil
        
        do {
            // Check if user is already registered
            if eventRegistrations[eventID] != nil {
                throw EventServiceError.alreadyRegistered
            }
            
            // Get event details to validate
            let eventRecordID = CKRecord.ID(recordName: eventID)
            let eventRecord = try await publicDatabase.record(for: eventRecordID)
            guard let event = Event(record: eventRecord) else {
                throw EventServiceError.eventNotFound
            }
            
            // Check if event is full
            if let maxParticipants = event.maxParticipants, 
               event.participants.count >= maxParticipants {
                throw EventServiceError.eventFull
            }
            
            // Check if event has already started or ended
            if event.hasEnded {
                throw EventServiceError.eventEnded
            }
            
            // Create registration
            let registration = EventRegistration(
                eventID: eventID,
                userID: userID,
                userName: userName,
                paymentAmount: paymentAmount
            )
            
            let registrationRecord = registration.toCKRecord(container: container)
            let savedRegistrationRecord = try await publicDatabase.save(registrationRecord)
            
            if let savedRegistration = EventRegistration(record: savedRegistrationRecord) {
                // Update event participants list
                var updatedEvent = event
                updatedEvent.participants.append(userID)
                let updatedEventRecord = updatedEvent.toCKRecord(container: container)
                try await publicDatabase.save(updatedEventRecord)
                
                // Create initial progress tracking
                let progress = EventProgressCloudKit(
                    eventID: eventID,
                    userID: userID,
                    userName: userName
                )
                let progressRecord = progress.toCKRecord(container: container)
                try await publicDatabase.save(progressRecord)
                
                await MainActor.run {
                    eventRegistrations[eventID] = savedRegistration
                    eventProgress[eventID] = progress
                    // Update local events array
                    if let index = events.firstIndex(where: { $0.id == eventID }) {
                        events[index] = updatedEvent
                    }
                    isLoading = false
                }
                
                print("✅ Successfully registered for event: \(event.name)")
                return .success(savedRegistration)
            } else {
                throw EventServiceError.invalidRegistrationData
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to register for event: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Failed to register for event: \(error)")
            return .failure(error)
        }
    }
    
    /// Fetch user's event registrations
    func fetchUserRegistrations(userID: String) async -> Result<[EventRegistration], Error> {
        do {
            let predicate = NSPredicate(format: "userID == %@", userID)
            let query = CKQuery(recordType: EventRegistration.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "registrationDate", ascending: false)]
            
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            let records = matchResults.compactMap { try? $0.1.get() }
            let registrations = records.compactMap { EventRegistration(record: $0) }
            
            await MainActor.run {
                for registration in registrations {
                    eventRegistrations[registration.eventID] = registration
                }
            }
            
            print("✅ Fetched \(registrations.count) registrations for user")
            return .success(registrations)
        } catch {
            print("❌ Failed to fetch user registrations: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Event Progress & Leaderboards
    
    /// Update event progress for a user based on workout data
    func updateEventProgress(eventID: String, userID: String, workouts: [Workout]) async -> Result<EventProgressCloudKit, Error> {
        do {
            // Get event details
            let eventRecordID = CKRecord.ID(recordName: eventID)
            let eventRecord = try await publicDatabase.record(for: eventRecordID)
            guard let event = Event(record: eventRecord) else {
                throw EventServiceError.eventNotFound
            }
            
            // Get current progress or create new
            let progressRecordID = CKRecord.ID(recordName: "\(eventID)_\(userID)")
            var progress: EventProgressCloudKit
            
            if let existingRecord = try? await publicDatabase.record(for: progressRecordID),
               let existingProgress = EventProgressCloudKit(record: existingRecord) {
                progress = existingProgress
            } else {
                progress = EventProgressCloudKit(eventID: eventID, userID: userID, userName: "User")
            }
            
            // Calculate new progress value based on workouts during event period
            let eventWorkouts = workouts.filter { workout in
                workout.startTime >= event.startDate && workout.startTime <= event.endDate
            }
            
            let newValue = calculateProgressValue(for: event.goalType, workouts: eventWorkouts)
            let oldValue = progress.currentValue
            progress.currentValue = newValue
            progress.workoutIDs = eventWorkouts.map { $0.id }
            progress.lastUpdated = Date()
            
            // Check if goal is completed
            if !progress.isCompleted && newValue >= event.targetValue {
                progress.isCompleted = true
                progress.completedDate = Date()
            }
            
            // Save updated progress
            let progressRecord = progress.toCKRecord(container: container)
            try await publicDatabase.save(progressRecord)
            
            await MainActor.run {
                eventProgress[eventID] = progress
            }
            
            // Update leaderboard if progress changed significantly
            if abs(newValue - oldValue) > 0.1 {
                let _ = await updateEventLeaderboard(eventID: eventID)
            }
            
            print("✅ Updated event progress for user \(userID): \(newValue)")
            return .success(progress)
            
        } catch {
            print("❌ Failed to update event progress: \(error)")
            return .failure(error)
        }
    }
    
    /// Update and fetch event leaderboard
    func updateEventLeaderboard(eventID: String) async -> Result<[LeaderboardEntry], Error> {
        do {
            // Fetch all progress entries for this event
            let predicate = NSPredicate(format: "eventID == %@", eventID)
            let query = CKQuery(recordType: EventProgressCloudKit.recordType, predicate: predicate)
            
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            let records = matchResults.compactMap { try? $0.1.get() }
            let progressEntries = records.compactMap { EventProgressCloudKit(record: $0) }
            
            // Sort by current value (descending for most goal types)
            let sortedEntries = progressEntries.sorted { entry1, entry2 in
                // For pace-based goals, lower is better
                return entry1.currentValue > entry2.currentValue
            }
            
            // Create leaderboard entries
            var leaderboardEntries: [LeaderboardEntry] = []
            for (index, progress) in sortedEntries.enumerated() {
                let entry = LeaderboardEntry(
                    id: "\(eventID)_\(progress.userID)",
                    userID: progress.userID,
                    userName: progress.userName,
                    currentValue: progress.currentValue,
                    rank: index + 1,
                    lastUpdated: progress.lastUpdated
                )
                leaderboardEntries.append(entry)
                
                // Save leaderboard entry to CloudKit
                let leaderboardRecord = entry.toCKRecord(eventID: eventID, container: container)
                try await publicDatabase.save(leaderboardRecord)
            }
            
            await MainActor.run {
                eventLeaderboards[eventID] = leaderboardEntries
            }
            
            print("✅ Updated leaderboard for event \(eventID) with \(leaderboardEntries.count) entries")
            return .success(leaderboardEntries)
            
        } catch {
            print("❌ Failed to update event leaderboard: \(error)")
            return .failure(error)
        }
    }
    
    /// Fetch event leaderboard
    func fetchEventLeaderboard(eventID: String) async -> Result<[LeaderboardEntry], Error> {
        do {
            let predicate = NSPredicate(format: "eventID == %@", eventID)
            let query = CKQuery(recordType: LeaderboardEntry.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "rank", ascending: true)]
            
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            let records = matchResults.compactMap { try? $0.1.get() }
            let leaderboard = records.compactMap { LeaderboardEntry(record: $0) }
            
            await MainActor.run {
                eventLeaderboards[eventID] = leaderboard
            }
            
            print("✅ Fetched leaderboard for event \(eventID) with \(leaderboard.count) entries")
            return .success(leaderboard)
        } catch {
            print("❌ Failed to fetch event leaderboard: \(error)")
            return .failure(error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func setupCloudKitSubscriptions() async {
        do {
            // Subscribe to event changes
            let eventPredicate = NSPredicate(value: true)
            let eventSubscription = CKQuerySubscription(
                recordType: Event.recordType,
                predicate: eventPredicate,
                subscriptionID: "event-changes-subscription",
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            let eventNotificationInfo = CKSubscription.NotificationInfo()
            eventNotificationInfo.shouldSendContentAvailable = true
            eventSubscription.notificationInfo = eventNotificationInfo
            
            let savedEventSub = try await publicDatabase.save(eventSubscription)
            subscriptions.append(savedEventSub)
            
            print("✅ CloudKit event subscriptions set up successfully")
        } catch {
            print("❌ Failed to set up CloudKit event subscriptions: \(error)")
        }
    }
    
    private func loadInitialData() async {
        // Load public events from CloudKit
        let _ = await fetchPublicEvents()
    }
    
    private func calculateProgressValue(for goalType: EventGoalType, workouts: [Workout]) -> Double {
        guard !workouts.isEmpty else { return 0.0 }
        
        switch goalType {
        case .totalDistance:
            return workouts.reduce(0) { $0 + $1.distance } / 1000 // Convert to km
        case .longestSingleRun:
            return (workouts.map { $0.distance }.max() ?? 0) / 1000 // Convert to km
        case .averagePace:
            let totalPace = workouts.reduce(0) { $0 + $1.averagePace }
            return workouts.isEmpty ? 0 : totalPace / Double(workouts.count)
        case .streakDays:
            return calculateStreakDays(from: workouts)
        case .totalWorkouts:
            return Double(workouts.count)
        case .fastestTime:
            return (workouts.map { $0.duration }.min() ?? Double.infinity) / 60 // Convert to minutes
        }
    }
    
    private func calculateStreakDays(from workouts: [Workout]) -> Double {
        let sortedDates = workouts.map { Calendar.current.startOfDay(for: $0.startTime) }
            .sorted()
        
        guard !sortedDates.isEmpty else { return 0.0 }
        
        var maxStreak = 1
        var currentStreak = 1
        
        for i in 1..<sortedDates.count {
            let daysDifference = Calendar.current.dateComponents([.day], 
                                                               from: sortedDates[i-1], 
                                                               to: sortedDates[i]).day ?? 0
            
            if daysDifference == 1 {
                currentStreak += 1
            } else {
                maxStreak = max(maxStreak, currentStreak)
                currentStreak = 1
            }
        }
        
        return Double(max(maxStreak, currentStreak))
    }
    
    // MARK: - Validation Methods
    
    func canCreateEvent(user: User) -> Bool {
        return user.subscriptionTier == .captain || user.subscriptionTier == .organization
    }
    
    func canJoinEvent(user: User) -> Bool {
        return user.subscriptionTier != .none // All paid tiers can join events
    }
    
    func getMaxEventsForUser(user: User) -> Int {
        switch user.subscriptionTier {
        case .none: return 0
        case .member: return Int.max // Can join unlimited events
        case .captain: return 10 // Can create up to 10 events
        case .organization: return Int.max // Unlimited
        }
    }
}

// MARK: - Error Types

enum EventServiceError: LocalizedError {
    case eventNotFound
    case eventFull
    case eventEnded
    case alreadyRegistered
    case invalidEventData
    case invalidRegistrationData
    case invalidProgressData
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return "Event not found"
        case .eventFull:
            return "Event is at maximum capacity"
        case .eventEnded:
            return "Event has already ended"
        case .alreadyRegistered:
            return "Already registered for this event"
        case .invalidEventData:
            return "Invalid event data"
        case .invalidRegistrationData:
            return "Invalid registration data"
        case .invalidProgressData:
            return "Invalid progress data"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}