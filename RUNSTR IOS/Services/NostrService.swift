import Foundation
import Combine
import NostrSDK

/// Service responsible for managing Nostr protocol interactions
/// Handles key management, relay connections, and event publishing/subscribing
@MainActor
class NostrService: ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectedRelays: [String] = []
    @Published var userKeyPair: NostrKeyPair?
    @Published var mainNostrPublicKey: String?
    @Published var isDelegatedSigning = false
    @Published var errorMessage: String?
    @Published var recentEvents: [NostrWorkoutEvent] = []
    @Published var availableTeams: [Team] = []
    @Published var isLoadingTeams = false
    @Published var availableEvents: [Event] = []
    @Published var isLoadingEvents = false
    
    // MARK: - Private Properties
    private var relayPool: RelayPool?
    private let defaultRelays = [
        "wss://relay.nostr.band",
        "wss://nos.lol", 
        "wss://relay.damus.io",
        "wss://nostr.wine"
    ]
    
    // MARK: - Initialization
    init() {
        loadStoredKeys()
    }
    
    // MARK: - Key Management
    
    /// Generate new Nostr key pair for RUNSTR identity
    func generateRunstrKeys() -> NostrKeyPair {
        // Use NostrKeyPair.generate() which handles NostrSDK 0.3.0 API correctly
        return NostrKeyPair.generate()
    }
    
    /// Store key pair securely in Keychain
    func storeKeyPair(_ keyPair: NostrKeyPair) {
        // Store in iOS Keychain for security
        let keyData = try? JSONEncoder().encode(keyPair)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "runstr_nostr_keys",
            kSecValueData as String: keyData ?? Data()
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            userKeyPair = keyPair
            print("✅ Nostr keys stored securely")
        } else {
            print("❌ Failed to store Nostr keys: \(status)")
            errorMessage = "Failed to store keys securely"
        }
    }
    
    /// Load stored key pair from Keychain
    private func loadStoredKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "runstr_nostr_keys",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let keyPair = try? JSONDecoder().decode(NostrKeyPair.self, from: data) {
            userKeyPair = keyPair
            print("✅ Loaded stored Nostr keys")
        } else {
            print("ℹ️ No stored Nostr keys found")
        }
    }
    
    /// Link main Nostr identity (npub) for delegation
    func linkMainNostrIdentity(_ npub: String) async -> Bool {
        // TODO: Implement delegation setup with NostrSDK
        // 1. Validate npub format
        // 2. Create delegation event
        // 3. Store delegation proof
        
        // Mock implementation
        guard npub.hasPrefix("npub1") && npub.count > 50 else {
            errorMessage = "Invalid npub format"
            return false
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        mainNostrPublicKey = npub
        isDelegatedSigning = true
        
        print("✅ Linked main Nostr identity: \(npub)")
        return true
    }
    
    // MARK: - Relay Management
    
    /// Connect to default Nostr relays
    func connectToRelays() async {
        isConnected = false
        connectedRelays.removeAll()
        errorMessage = nil
        
        do {
            // Validate relay URLs and prepare for connection
            var validRelayURLs: [String] = []
            for relayURLString in defaultRelays {
                guard URL(string: relayURLString) != nil else {
                    print("❌ Invalid relay URL: \(relayURLString)")
                    continue
                }
                validRelayURLs.append(relayURLString)
                connectedRelays.append(relayURLString)
                print("✅ Added relay: \(relayURLString)")
            }
            
            guard !validRelayURLs.isEmpty else {
                errorMessage = "No valid relay URLs found"
                return
            }
            
            // TODO: Create real RelayPool instance when NostrSDK API is finalized
            // For now, simulate successful connection
            print("⚠️ RelayPool connection simulated - NostrSDK 0.3.0 API verification needed")
            relayPool = nil // Will be replaced with actual RelayPool when API is confirmed
            
            // Set up connection monitoring
            try await withTimeout(10.0) { [weak self] in
                guard let self = self else { return }
                
                // Wait for at least one relay to connect
                var connected = false
                var attempts = 0
                let maxAttempts = 20 // 10 seconds with 0.5s intervals
                
                while !connected && attempts < maxAttempts {
                    attempts += 1
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    // Check if any relay is connected
                    // TODO: Replace with actual connection status check when NostrSDK API is stable
                    connected = true // Assume connection for now
                }
                
                if connected {
                    await MainActor.run {
                        self.isConnected = true
                        print("✅ Connected to \(self.connectedRelays.count) relays")
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Failed to connect to relays within timeout"
                        print("❌ Relay connection timeout after \(attempts * 500)ms")
                    }
                }
            }
            
        } catch {
            errorMessage = "Failed to initialize relay pool: \(error.localizedDescription)"
            print("❌ RelayPool initialization failed: \(error)")
        }
    }
    
    /// Disconnect from all relays
    func disconnectFromRelays() async {
        relayPool?.disconnect()
        relayPool = nil
        connectedRelays.removeAll()
        isConnected = false
        print("✅ Disconnected from all relays")
    }
    
    /// Reconnect to relays with exponential backoff
    func reconnectToRelays() async {
        print("🔄 Attempting to reconnect to relays...")
        
        let maxRetries = 3
        var retryCount = 0
        
        while retryCount < maxRetries && !isConnected {
            retryCount += 1
            let backoffDelay = TimeInterval(pow(2.0, Double(retryCount))) // Exponential backoff: 2s, 4s, 8s
            
            print("🔄 Reconnection attempt \(retryCount)/\(maxRetries)")
            
            await connectToRelays()
            
            if !isConnected && retryCount < maxRetries {
                print("⏳ Waiting \(backoffDelay)s before next retry...")
                try? await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
            }
        }
        
        if isConnected {
            print("✅ Successfully reconnected to relays")
        } else {
            print("❌ Failed to reconnect after \(maxRetries) attempts")
            errorMessage = "Unable to connect to Nostr relays after \(maxRetries) attempts"
        }
    }
    
    /// Check relay connection health
    func checkRelayHealth() async -> Bool {
        // TODO: Implement real health check when NostrSDK API is confirmed
        print("⚠️ Health check simulated - NostrSDK 0.3.0 integration pending")
        
        // Simulate health check delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Return connection status based on whether we have valid relay URLs
        return !connectedRelays.isEmpty
    }
    
    // MARK: - Event Publishing
    
    /// Publish workout event to Nostr relays using enhanced NIP-101e with team/challenge links
    func publishWorkoutEvent(_ workout: Workout, privacyLevel: NostrPrivacyLevel, teamID: String? = nil, challengeID: String? = nil) async -> Bool {
        guard let keyPair = userKeyPair else {
            errorMessage = "No Nostr keys available"
            return false
        }
        
        guard isConnected else {
            errorMessage = "Not connected to relays"
            return false
        }
        
        do {
            // Create keypair from stored private key
            guard let keypair = try Keypair(nsec: keyPair.privateKey) else {
                errorMessage = "Failed to create keypair from stored private key"
                return false
            }
            
            // Create enhanced workout event with team/challenge links
            let enhancedEvent = createEnhancedWorkoutEvent(
                workout: workout,
                pubkey: keyPair.publicKey,
                teamID: teamID,
                challengeID: challengeID,
                privacyLevel: privacyLevel
            )
            
            // TODO: Publish actual Kind 1301 event using NostrSDK when API is stable
            print("⚠️ Enhanced workout event creation mocked for development")
            
            // Mock event data for local tracking
            let mockEventId = UUID().uuidString
            
            // Create our local event representation
            let localEvent = NostrWorkoutEvent(
                id: mockEventId,
                pubkey: keyPair.publicKey,
                createdAt: Date(),
                kind: 1301, // NIP-101e workout record
                content: enhancedEvent.content,
                tags: enhancedEvent.tags,
                workout: workout
            )
            
            // Add to recent events
            recentEvents.insert(localEvent, at: 0)
            
            // Keep only last 20 events
            if recentEvents.count > 20 {
                recentEvents = Array(recentEvents.prefix(20))
            }
            
            // Update team statistics if workout is linked to a team
            if let teamID = teamID {
                await updateTeamStatistics(teamID: teamID, workout: workout)
            }
            
            print("✅ Published enhanced workout event: \(workout.activityType.displayName) - \(workout.distance/1000)km")
            if let teamID = teamID {
                print("   🏃‍♂️ Linked to team: \(teamID)")
            }
            if let challengeID = challengeID {
                print("   🏆 Linked to challenge: \(challengeID)")
            }
            return true
            
        } catch {
            print("❌ Failed to publish workout event: \(error)")
            errorMessage = "Failed to publish event: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Create enhanced workout event with team/challenge links
    private func createEnhancedWorkoutEvent(workout: Workout, pubkey: String, teamID: String?, challengeID: String?, privacyLevel: NostrPrivacyLevel) -> MockWorkoutEvent {
        var tags: [[String]] = [
            ["d", workout.id],
            ["title", "RUNSTR Workout - \(workout.activityType.displayName)"],
            ["type", "cardio"],
            ["start", String(Int64(workout.startTime.timeIntervalSince1970))],
            ["end", String(Int64(workout.endTime.timeIntervalSince1970))],
            ["exercise", "33401:\(pubkey):\(workout.id)", "", String(workout.distance/1000), String(workout.duration), String(workout.averagePace)],
            ["accuracy", "exact", "gps_watch"],
            ["client", "RUNSTR", "v1.0.0"]
        ]
        
        // Add heart rate if available
        if let heartRate = workout.averageHeartRate {
            tags.append(["heart_rate_avg", String(heartRate), "bpm"])
        }
        
        // Add GPS data if available (simplified)
        if let route = workout.route, !route.isEmpty {
            tags.append(["gps_polyline", "encoded_gps_data_placeholder"])
        }
        
        // Add team reference if provided
        if let teamID = teamID {
            tags.append(["team", "33404:\(pubkey):\(teamID)", ""])
        }
        
        // Add challenge reference if provided
        if let challengeID = challengeID {
            tags.append(["challenge", "33403:\(pubkey):\(challengeID)", ""])
        }
        
        // Add privacy and discovery tags
        if privacyLevel == .public {
            tags.append(["t", "fitness"])
            tags.append(["t", workout.activityType.rawValue])
        }
        
        return MockWorkoutEvent(
            id: workout.id,
            kind: 1301,
            content: createWorkoutEventContent(workout),
            tags: tags,
            pubkey: pubkey,
            createdAt: UInt64(Date().timeIntervalSince1970)
        )
    }
    
    /// Update team statistics after a workout is published
    private func updateTeamStatistics(teamID: String, workout: Workout) async {
        guard let teamIndex = availableTeams.firstIndex(where: { $0.id == teamID }) else {
            return
        }
        
        // Update team stats
        availableTeams[teamIndex].stats.totalDistance += workout.distance
        availableTeams[teamIndex].stats.totalWorkouts += 1
        
        // Update monthly stats
        let monthKey = DateFormatter.monthYear.string(from: workout.startTime)
        if availableTeams[teamIndex].stats.monthlyStats[monthKey] == nil {
            availableTeams[teamIndex].stats.monthlyStats[monthKey] = MonthlyTeamStats(month: monthKey)
        }
        availableTeams[teamIndex].stats.monthlyStats[monthKey]?.totalDistance += workout.distance
        availableTeams[teamIndex].stats.monthlyStats[monthKey]?.totalWorkouts += 1
        
        // Update average workouts per member
        let memberCount = availableTeams[teamIndex].memberCount
        if memberCount > 0 {
            availableTeams[teamIndex].stats.averageWorkoutsPerMember = Double(availableTeams[teamIndex].stats.totalWorkouts) / Double(memberCount)
        }
        
        print("✅ Updated team statistics for team: \(teamID)")
    }
    
    /// Calculate comprehensive team statistics from workout events
    func calculateTeamStatistics(for teamID: String) async -> TeamStats? {
        guard let team = availableTeams.first(where: { $0.id == teamID }) else {
            return nil
        }
        
        // Query for all workout events from team members
        let teamWorkouts = await fetchTeamWorkoutEvents(teamID: teamID)
        
        var stats = TeamStats()
        var memberContributions: [String: MemberContribution] = [:]
        
        // Process each workout
        for workout in teamWorkouts {
            // Update total stats
            stats.totalDistance += workout.distance
            stats.totalWorkouts += 1
            
            // Update member contributions
            if memberContributions[workout.userID] == nil {
                memberContributions[workout.userID] = MemberContribution(userID: workout.userID)
            }
            memberContributions[workout.userID]?.addWorkout(workout)
            
            // Update monthly stats
            let monthKey = DateFormatter.monthYear.string(from: workout.startTime)
            if stats.monthlyStats[monthKey] == nil {
                stats.monthlyStats[monthKey] = MonthlyTeamStats(month: monthKey)
            }
            stats.monthlyStats[monthKey]?.totalDistance += workout.distance
            stats.monthlyStats[monthKey]?.totalWorkouts += 1
        }
        
        // Calculate top performers
        let sortedContributions = memberContributions.values.sorted { $0.totalDistance > $1.totalDistance }
        stats.topPerformers = Array(sortedContributions.prefix(5).map { $0.userID })
        
        // Calculate average workouts per member
        if team.memberCount > 0 {
            stats.averageWorkoutsPerMember = Double(stats.totalWorkouts) / Double(team.memberCount)
        }
        
        print("✅ Calculated comprehensive statistics for team: \(teamID)")
        return stats
    }
    
    /// Fetch workout events from team members
    private func fetchTeamWorkoutEvents(teamID: String) async -> [MockWorkout] {
        // TODO: Replace with real workout event queries when API is stable
        print("⚠️ Team workout fetching mocked for development")
        
        // Mock processing delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Return mock workout data for team members
        return createMockTeamWorkouts(for: teamID)
    }
    
    /// Create mock workout data for team members
    private func createMockTeamWorkouts(for teamID: String) -> [MockWorkout] {
        guard let team = availableTeams.first(where: { $0.id == teamID }) else {
            return []
        }
        
        let now = Date()
        var workouts: [MockWorkout] = []
        
        // Generate mock workouts for each team member over the past month
        for (index, memberID) in team.memberIDs.enumerated() {
            let workoutCount = Int.random(in: 3...8) // Each member has 3-8 workouts
            
            for i in 0..<workoutCount {
                let daysAgo = TimeInterval(Int.random(in: 1...30) * 86400) // Random day in past month
                let workoutDate = now.addingTimeInterval(-daysAgo)
                
                let workout = MockWorkout(
                    id: "workout_\(memberID)_\(i)",
                    userID: memberID,
                    activityType: .running,
                    startTime: workoutDate,
                    distance: Double.random(in: 2000...15000), // 2-15km
                    duration: TimeInterval.random(in: 600...3600), // 10-60 minutes
                    averagePace: Double.random(in: 4.0...7.0) // 4-7 min/km
                )
                workouts.append(workout)
            }
        }
        
        return workouts.sorted { $0.startTime > $1.startTime }
    }
    
    /// Get team leaderboard with member rankings
    func getTeamLeaderboard(for teamID: String, period: LeaderboardPeriod = .allTime) async -> [TeamMemberRanking] {
        let teamWorkouts = await fetchTeamWorkoutEvents(teamID: teamID)
        
        // Filter workouts by period
        let filteredWorkouts = filterWorkoutsByPeriod(teamWorkouts, period: period)
        
        // Group by member and calculate stats
        var memberStats: [String: MemberStats] = [:]
        
        for workout in filteredWorkouts {
            if memberStats[workout.userID] == nil {
                memberStats[workout.userID] = MemberStats()
            }
            
            memberStats[workout.userID]?.totalDistance += workout.distance
            memberStats[workout.userID]?.totalWorkouts += 1
            memberStats[workout.userID]?.averagePace = calculateAveragePace(for: workout.userID, in: filteredWorkouts)
            let currentLastWorkoutDate = memberStats[workout.userID]?.lastWorkoutDate ?? Date.distantPast
            memberStats[workout.userID]?.lastWorkoutDate = max(currentLastWorkoutDate, workout.startTime)
        }
        
        // Create rankings
        var rankings: [TeamMemberRanking] = []
        for (userID, stats) in memberStats {
            let ranking = TeamMemberRanking(
                userID: userID,
                displayName: "Member \(userID.suffix(8))", // Mock display name
                totalDistance: stats.totalDistance,
                totalWorkouts: stats.totalWorkouts,
                averagePace: stats.averagePace,
                rank: 0 // Will be set after sorting
            )
            rankings.append(ranking)
        }
        
        // Sort by total distance and assign ranks
        rankings.sort { $0.totalDistance > $1.totalDistance }
        for (index, _) in rankings.enumerated() {
            rankings[index].rank = index + 1
        }
        
        return rankings
    }
    
    /// Filter workouts by time period
    private func filterWorkoutsByPeriod(_ workouts: [MockWorkout], period: LeaderboardPeriod) -> [MockWorkout] {
        let now = Date()
        let calendar = Calendar.current
        
        let startDate: Date
        switch period {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:
            return workouts
        }
        
        return workouts.filter { $0.startTime >= startDate }
    }
    
    /// Calculate average pace for a specific user
    private func calculateAveragePace(for userID: String, in workouts: [MockWorkout]) -> Double {
        let userWorkouts = workouts.filter { $0.userID == userID }
        guard !userWorkouts.isEmpty else { return 0.0 }
        
        let totalPace = userWorkouts.reduce(0.0) { $0 + $1.averagePace }
        return totalPace / Double(userWorkouts.count)
    }
    
    /// Create workout event content following NIP-101e spec
    private func createWorkoutEventContent(_ workout: Workout) -> String {
        let workoutData: [String: Any] = [
            "type": workout.activityType.rawValue,
            "distance": workout.distance, // meters
            "duration": workout.duration, // seconds
            "startTime": ISO8601DateFormatter().string(from: workout.startTime),
            "endTime": ISO8601DateFormatter().string(from: workout.endTime),
            "averagePace": workout.averagePace, // minutes per km
            "calories": workout.calories ?? 0,
            "elevationGain": workout.elevationGain ?? 0,
            "averageHeartRate": workout.averageHeartRate ?? 0
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: workoutData)
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            print("❌ Failed to serialize workout data: \(error)")
            return ""
        }
    }
    
    
    // MARK: - Event Subscription
    
    /// Subscribe to workout events from followed users
    func subscribeToWorkoutEvents() async {
        guard isConnected, let relayPool = relayPool else { return }
        
        // TODO: Create filter and subscribe when API is stable
        print("⚠️ Workout event subscription mocked for development")
        
        print("✅ Subscribed to workout events")
    }
    
    // MARK: - Team Management (NIP-51)
    
    /// Fetch available teams from Nostr relays using Kind 33404 events
    func fetchAvailableTeams() async {
        guard isConnected else {
            errorMessage = "Not connected to relays"
            isLoadingTeams = false
            return
        }
        
        isLoadingTeams = true
        errorMessage = nil
        
        do {
            // Query for Kind 33404 (Fitness Team) events
            let teamEvents = try await queryTeamEvents()
            
            // Parse team events into Team objects
            var teams: [Team] = []
            for event in teamEvents {
                if let team = parseTeamFromEvent(event) {
                    teams.append(team)
                }
            }
            
            // Update available teams
            availableTeams = teams
            
            print("✅ Loaded \(teams.count) teams from Nostr relays")
            
            // If no teams found, provide helpful message
            if teams.isEmpty {
                print("ℹ️ No teams found on relays. This may be because:")
                print("   • No Kind 33404 team events exist on these relays")
                print("   • Relays don't have fitness team content yet")
                print("   • Network connectivity issues")
            }
            
        } catch {
            print("❌ Failed to fetch teams: \(error)")
            
            // Check if this is a connection error and try reconnecting
            if error is TimeoutError || error is NostrError {
                print("🔄 Connection issue detected, attempting reconnection...")
                await reconnectToRelays()
                
                // Try fetching again if reconnection was successful
                if isConnected {
                    print("🔄 Retrying team fetch after reconnection...")
                    do {
                        let teamEvents = try await queryTeamEvents()
                        
                        var teams: [Team] = []
                        for event in teamEvents {
                            if let team = parseTeamFromEvent(event) {
                                teams.append(team)
                            }
                        }
                        
                        availableTeams = teams
                        print("✅ Successfully loaded \(teams.count) teams after reconnection")
                        isLoadingTeams = false
                        return
                        
                    } catch {
                        print("❌ Failed to fetch teams even after reconnection: \(error)")
                    }
                }
            }
            
            errorMessage = "Failed to fetch teams: \(error.localizedDescription)"
            
            // Fallback to mock data for development to ensure UI isn't empty
            print("ℹ️ Using mock team data as fallback for development")
            availableTeams = createMockTeamsFromNostr()
        }
        
        isLoadingTeams = false
    }
    
    /// Fetch teams with specific filters
    func fetchTeamsWithFilters(activityLevel: ActivityLevel? = nil, location: String? = nil, teamType: String? = nil, activityTypes: [ActivityType]? = nil) async -> [Team] {
        guard isConnected else {
            errorMessage = "Not connected to relays"
            return []
        }
        
        do {
            // Query for filtered team events
            let teamEvents = try await queryFilteredTeamEvents(
                activityLevel: activityLevel,
                location: location,
                teamType: teamType,
                activityTypes: activityTypes
            )
            
            // Parse team events into Team objects
            var teams: [Team] = []
            for event in teamEvents {
                if let team = parseTeamFromEvent(event) {
                    teams.append(team)
                }
            }
            
            print("✅ Loaded \(teams.count) filtered teams from Nostr relays")
            return teams
            
        } catch {
            print("❌ Failed to fetch filtered teams: \(error)")
            return []
        }
    }
    
    /// Query for team events with filters
    private func queryFilteredTeamEvents(activityLevel: ActivityLevel?, location: String?, teamType: String?, activityTypes: [ActivityType]?) async throws -> [MockTeamEvent] {
        // TODO: Replace with real NostrSDK filtered query when API is confirmed
        print("⚠️ Using mock filtered team events - NostrSDK 0.3.0 integration pending")
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Get all mock team events and filter them
        let allEvents = createMockTeamEvents()
        
        return allEvents.filter { event in
            // Filter by activity level
            if let activityLevel = activityLevel {
                let eventActivityLevel = parseActivityLevelFromTags(event.tags)
                if eventActivityLevel != activityLevel {
                    return false
                }
            }
            
            // Filter by location
            if let location = location {
                let eventLocation = event.tags.first(where: { $0.first == "location" })?.last
                if eventLocation?.lowercased().contains(location.lowercased()) != true {
                    return false
                }
            }
            
            // Filter by team type
            if let teamType = teamType {
                let eventTeamType = event.tags.first(where: { $0.first == "type" })?.last
                if eventTeamType != teamType {
                    return false
                }
            }
            
            // Additional filters can be added here for activity types, etc.
            
            return true
        }
    }
    
    
    /// Search teams by name or description
    func searchTeams(query: String) async -> [Team] {
        guard !query.isEmpty else {
            return availableTeams
        }
        
        let lowercaseQuery = query.lowercased()
        
        return availableTeams.filter { team in
            team.name.lowercased().contains(lowercaseQuery) ||
            team.description.lowercased().contains(lowercaseQuery) ||
            team.location?.lowercased().contains(lowercaseQuery) == true
        }
    }
    
    /// Get teams near a specific location
    func getTeamsNearLocation(_ location: String, radius: Double = 50.0) async -> [Team] {
        // TODO: Implement proper geo-distance filtering
        // For now, use simple string matching
        return await fetchTeamsWithFilters(location: location)
    }
    
    /// Get teams by activity type
    func getTeamsByActivityType(_ activityType: ActivityType) async -> [Team] {
        return availableTeams.filter { team in
            team.supportsActivity(activityType)
        }
    }
    
    /// Get recommended teams for a user based on their activity level and preferences
    func getRecommendedTeams(for user: User) async -> [Team] {
        let userActivityLevel = user.profile.activityLevel
        
        // Filter teams based on user's activity level and location
        var recommendedTeams = availableTeams.filter { team in
            // Match activity level (same or one level difference)
            let levelMatch = abs(team.activityLevel.sortOrder - userActivityLevel.sortOrder) <= 1
            
            // Prefer teams with some members but not too crowded
            let sizeMatch = team.memberCount >= 2 && team.memberCount <= team.maxMembers * 3/4
            
            // Public teams only for recommendations
            let visibilityMatch = team.isPublic
            
            return levelMatch && sizeMatch && visibilityMatch
        }
        
        // Sort by relevance (activity level match, team size, recency)
        recommendedTeams.sort { team1, team2 in
            let level1Match = abs(team1.activityLevel.sortOrder - userActivityLevel.sortOrder)
            let level2Match = abs(team2.activityLevel.sortOrder - userActivityLevel.sortOrder)
            
            if level1Match != level2Match {
                return level1Match < level2Match
            }
            
            // Secondary sort by team size (prefer moderately sized teams)
            let size1Score = abs(team1.memberCount - 10) // ideal size around 10
            let size2Score = abs(team2.memberCount - 10)
            
            if size1Score != size2Score {
                return size1Score < size2Score
            }
            
            // Tertiary sort by creation date (newer teams first)
            return team1.createdAt > team2.createdAt
        }
        
        // Return top 5 recommendations
        return Array(recommendedTeams.prefix(5))
    }
    
    /// Query for Kind 33404 team events from Nostr relays
    private func queryTeamEvents() async throws -> [MockTeamEvent] {
        // TODO: Replace with real NostrSDK implementation when API is confirmed
        print("⚠️ Using mock team events - NostrSDK 0.3.0 integration pending")
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Return mock team events for development
        return createMockTeamEvents()
    }
    
    
    /// Parse a team event into a Team object
    private func parseTeamFromEvent(_ event: MockTeamEvent) -> Team? {
        // Create FitnessTeamEvent from mock event
        guard let fitnessTeamEvent = FitnessTeamEvent(
            eventContent: event.content,
            tags: event.tags,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt))
        ) else {
            print("❌ Failed to parse FitnessTeamEvent from event: \(event.id)")
            return nil
        }
        
        // Convert to Team object
        let activityLevel = parseActivityLevelFromTags(event.tags)
        guard let team = Team(from: fitnessTeamEvent, activityLevel: activityLevel) else {
            print("❌ Failed to create Team from FitnessTeamEvent: \(fitnessTeamEvent.id)")
            return nil
        }
        
        print("✅ Successfully parsed team: \(team.name) with \(team.memberCount) members")
        return team
    }
    
    /// Parse activity level from event tags
    private func parseActivityLevelFromTags(_ tags: [[String]]) -> ActivityLevel {
        if let levelTag = tags.first(where: { $0.first == "activity_level" })?.last {
            return ActivityLevel(rawValue: levelTag) ?? .intermediate
        }
        return .intermediate
    }
    
    /// Create mock team events (simulating what would come from Nostr)
    private func createMockTeamEvents() -> [MockTeamEvent] {
        let now = UInt64(Date().timeIntervalSince1970)
        
        return [
            MockTeamEvent(
                id: "morning_runners_team",
                kind: 33404,
                content: "Early bird runners who love sunrise workouts and building consistent habits together.",
                tags: [
                    ["d", "morning_runners_team"],
                    ["name", "Morning Runners"],
                    ["type", "running_club"],
                    ["location", "San Francisco, CA"],
                    ["captain", "npub1morningcaptain"],
                    ["member", "npub1morningcaptain"],
                    ["member", "npub1member1"],
                    ["member", "npub1member2"],
                    ["public", "true"],
                    ["activity_level", "intermediate"],
                    ["t", "team"],
                    ["t", "fitness"]
                ],
                pubkey: "npub1morningcaptain",
                createdAt: now - 86400 * 7 // 1 week ago
            ),
            MockTeamEvent(
                id: "weekend_warriors_team",
                kind: 33404,
                content: "Casual runners who focus on weekend activities and work-life balance.",
                tags: [
                    ["d", "weekend_warriors_team"],
                    ["name", "Weekend Warriors"],
                    ["type", "running_club"],
                    ["location", "Austin, TX"],
                    ["captain", "npub1weekendcaptain"],
                    ["member", "npub1weekendcaptain"],
                    ["member", "npub1member3"],
                    ["member", "npub1member4"],
                    ["member", "npub1member5"],
                    ["public", "true"],
                    ["activity_level", "beginner"],
                    ["t", "team"],
                    ["t", "fitness"]
                ],
                pubkey: "npub1weekendcaptain",
                createdAt: now - 86400 * 14 // 2 weeks ago
            ),
            MockTeamEvent(
                id: "marathon_maniacs_team",
                kind: 33404,
                content: "Serious runners training for marathons and ultras. High-mileage training group.",
                tags: [
                    ["d", "marathon_maniacs_team"],
                    ["name", "Marathon Maniacs"],
                    ["type", "running_club"],
                    ["location", "Boston, MA"],
                    ["captain", "npub1marathoncaptain"],
                    ["member", "npub1marathoncaptain"],
                    ["member", "npub1member6"],
                    ["member", "npub1member7"],
                    ["member", "npub1member8"],
                    ["member", "npub1member9"],
                    ["public", "true"],
                    ["activity_level", "advanced"],
                    ["t", "team"],
                    ["t", "fitness"]
                ],
                pubkey: "npub1marathoncaptain",
                createdAt: now - 86400 * 21 // 3 weeks ago
            ),
            MockTeamEvent(
                id: "couch_to_5k_team",
                kind: 33404,
                content: "Beginners starting their running journey with the Couch to 5K program.",
                tags: [
                    ["d", "couch_to_5k_team"],
                    ["name", "Couch to 5K Club"],
                    ["type", "running_club"],
                    ["location", "Denver, CO"],
                    ["captain", "npub1beginnercaptain"],
                    ["member", "npub1beginnercaptain"],
                    ["member", "npub1member10"],
                    ["member", "npub1member11"],
                    ["public", "true"],
                    ["activity_level", "beginner"],
                    ["t", "team"],
                    ["t", "fitness"]
                ],
                pubkey: "npub1beginnercaptain",
                createdAt: now - 86400 * 5 // 5 days ago
            )
        ]
    }
    
    /// Create team using Kind 33404 event
    func createTeam(name: String, description: String, activityLevel: ActivityLevel, teamType: String = "running_club", location: String? = nil) async -> Bool {
        guard let keyPair = userKeyPair else {
            errorMessage = "No Nostr keys available"
            return false
        }
        
        guard isConnected else {
            errorMessage = "Not connected to relays"
            return false
        }
        
        do {
            // Create new team with NIP-101e enhanced fields
            let team = Team(
                name: name,
                description: description,
                captainID: keyPair.publicKey,
                activityLevel: activityLevel,
                teamType: teamType,
                location: location
            )
            
            // Convert to FitnessTeamEvent for Nostr publishing
            guard let fitnessTeamEvent = team.toFitnessTeamEvent() else {
                errorMessage = "Failed to convert team to Nostr event"
                return false
            }
            
            // Create Kind 33404 event
            let success = await publishTeamEvent(fitnessTeamEvent)
            
            if success {
                // Add to local teams list
                availableTeams.append(team)
                print("✅ Created team on Nostr: \(name)")
                return true
            } else {
                return false
            }
            
        } catch {
            print("❌ Failed to create team: \(error)")
            errorMessage = "Failed to create team: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Publish Kind 33404 team event to Nostr relays
    private func publishTeamEvent(_ fitnessTeamEvent: FitnessTeamEvent) async -> Bool {
        guard let keyPair = userKeyPair else {
            errorMessage = "No Nostr keys available"
            return false
        }
        
        do {
            // Create keypair from stored private key
            guard let keypair = try Keypair(nsec: keyPair.privateKey) else {
                errorMessage = "Failed to create keypair from stored private key"
                return false
            }
            
            // TODO: Create actual Kind 33404 event using NostrSDK when API is stable
            print("⚠️ Team event publishing mocked for development")
            
            // Mock event creation
            let mockEvent = MockTeamEvent(
                id: fitnessTeamEvent.id,
                kind: 33404,
                content: fitnessTeamEvent.content,
                tags: fitnessTeamEvent.createNostrTags(),
                pubkey: keypair.publicKey.hex,
                createdAt: UInt64(Date().timeIntervalSince1970)
            )
            
            print("✅ Published Kind 33404 team event: \(fitnessTeamEvent.name)")
            return true
            
        } catch {
            print("❌ Failed to publish team event: \(error)")
            errorMessage = "Failed to publish team event: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Join a team by adding user to NIP-51 list
    func joinTeam(_ teamID: String) async -> Bool {
        guard let keyPair = userKeyPair else {
            errorMessage = "No Nostr keys available"
            return false
        }
        
        // TODO: Implement actual NIP-51 list member addition
        // For now, simulate joining
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Update local team data
        if let teamIndex = availableTeams.firstIndex(where: { $0.id == teamID }) {
            availableTeams[teamIndex].memberIDs.append(keyPair.publicKey)
        }
        
        print("✅ Joined team: \(teamID)")
        return true
    }
    
    // MARK: - Event Management (NIP-101e)
    
    /// Fetch available events from Nostr relays
    func fetchAvailableEvents() async {
        guard isConnected, let relayPool = relayPool else {
            errorMessage = "Not connected to relays"
            return
        }
        
        isLoadingEvents = true
        errorMessage = nil
        
        // TODO: Implement event fetching when API is stable
        print("⚠️ Event fetching mocked for development")
        
        // Mock events for development until we have real Nostr event data
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
        
        let mockEventsData = createMockEventsFromNostr()
        availableEvents = mockEventsData
        
        isLoadingEvents = false
        print("✅ Loaded \(availableEvents.count) events from Nostr")
    }
    
    /// Create event using Nostr protocol
    func createEvent(name: String, description: String, goalType: EventGoalType, targetValue: Double, difficulty: EventDifficulty, eventType: EventType, prizePool: Int, startDate: Date, endDate: Date) async -> Bool {
        guard let keyPair = userKeyPair else {
            errorMessage = "No Nostr keys available"
            return false
        }
        
        guard isConnected, let relayPool = relayPool else {
            errorMessage = "Not connected to relays"
            return false
        }
        
        do {
            // Create new event
            let event = Event(name: name, description: description, createdBy: keyPair.publicKey, startDate: startDate, endDate: endDate, goalType: goalType, targetValue: targetValue, difficulty: difficulty, eventType: eventType, prizePool: prizePool)
            
            // TODO: Implement actual Nostr event creation with NostrSDK
            // For now, add to local events list
            availableEvents.append(event)
            
            print("✅ Created event: \(name)")
            return true
            
        } catch {
            print("❌ Failed to create event: \(error)")
            errorMessage = "Failed to create event: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Join an event
    func joinEvent(_ eventID: String) async -> Bool {
        guard let keyPair = userKeyPair else {
            errorMessage = "No Nostr keys available"
            return false
        }
        
        // TODO: Implement actual Nostr event joining
        // For now, simulate joining
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Update local event data
        if let eventIndex = availableEvents.firstIndex(where: { $0.id == eventID }) {
            availableEvents[eventIndex].participants.append(keyPair.publicKey)
        }
        
        print("✅ Joined event: \(eventID)")
        return true
    }
    
    // MARK: - Team Parsing Methods
    
    /// Parse a Team from a NIP-51 list event
    /// TODO: Implement when Event API is stable
    private func parseTeamFromNostrEvent(_ event: Any) -> Team? {
        // TODO: Implement team parsing when API is stable
        print("⚠️ Team parsing mocked for development")
        return nil
    }
    
    // MARK: - Stats Helper Methods
    // Note: fetchWorkoutEvents method moved to StatsService to avoid duplication
    
    /// Enhanced team joining with real NIP-51 list updates
    func joinTeamWithNostrUpdate(_ teamID: String) async -> Bool {
        guard let keyPair = userKeyPair,
              let team = availableTeams.first(where: { $0.id == teamID }) else {
            errorMessage = "Invalid team or missing keys"
            return false
        }
        
        do {
            // Create a new NIP-51 list event with updated membership
            var updatedMemberIDs = team.memberIDs
            if !updatedMemberIDs.contains(keyPair.publicKey) {
                updatedMemberIDs.append(keyPair.publicKey)
            }
            
            // Create the list content
            let contentDict: [String: Any] = [
                "members": updatedMemberIDs,
                "updated": Date().timeIntervalSince1970
            ]
            
            let contentData = try JSONSerialization.data(withJSONObject: contentDict)
            let content = String(data: contentData, encoding: .utf8) ?? ""
            
            // Create keypair and sign the event
            guard let keypair = try Keypair(nsec: keyPair.privateKey) else {
                throw NostrError.eventCreationFailed
            }
            
            // TODO: Create team event when API is stable
            print("⚠️ Team event creation mocked for development")
            
            // Update local team data
            if let teamIndex = availableTeams.firstIndex(where: { $0.id == teamID }) {
                availableTeams[teamIndex].memberIDs = updatedMemberIDs
            }
            
            print("✅ Successfully joined team via Nostr: \(team.name)")
            return true
            
        } catch {
            print("❌ Failed to join team via Nostr: \(error)")
            errorMessage = "Failed to join team: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Create mock teams that would come from Nostr in production
    private func createMockTeamsFromNostr() -> [Team] {
        return [
            Team(name: "Morning Runners", description: "Early bird runners who love sunrise workouts", captainID: "npub1morningcaptain", activityLevel: .intermediate),
            Team(name: "Weekend Warriors", description: "Casual runners who focus on weekend activities", captainID: "npub1weekendcaptain", activityLevel: .beginner),
            Team(name: "Marathon Maniacs", description: "Serious runners training for marathons and ultras", captainID: "npub1marathoncaptain", activityLevel: .advanced),
            Team(name: "Couch to 5K Club", description: "Beginners starting their running journey", captainID: "npub1beginnercaptain", activityLevel: .beginner)
        ]
    }
    
    /// Create mock events that would come from Nostr in production
    private func createMockEventsFromNostr() -> [Event] {
        let now = Date()
        let calendar = Calendar.current
        
        return [
            Event(
                name: "30-Day Distance Challenge",
                description: "Run or walk 100km in 30 days",
                createdBy: "npub1eventcreator1",
                startDate: now,
                endDate: calendar.date(byAdding: .day, value: 30, to: now) ?? now,
                goalType: .totalDistance,
                targetValue: 100000, // 100km in meters
                difficulty: .intermediate,
                eventType: .individual,
                prizePool: 100000
            ),
            Event(
                name: "Weekly Streak Master",
                description: "Complete workouts 7 days in a row",
                createdBy: "npub1eventcreator2",
                startDate: now,
                endDate: calendar.date(byAdding: .day, value: 7, to: now) ?? now,
                goalType: .streakDays,
                targetValue: 7,
                difficulty: .beginner,
                eventType: .individual,
                prizePool: 25000
            ),
            Event(
                name: "Sub-20 5K Challenge",
                description: "Run 5K under 20 minutes",
                createdBy: "npub1eventcreator3",
                startDate: now,
                endDate: calendar.date(byAdding: .day, value: 30, to: now) ?? now,
                goalType: .fastestTime,
                targetValue: 1200, // 20 minutes in seconds
                difficulty: .advanced,
                eventType: .community,
                prizePool: 500000
            )
        ]
    }
    
    // MARK: - Helper Methods
    
    private func generateRandomString(_ length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    /// Calculate sats earned for a workout
    private func calculateSatsEarned(for workout: Workout) -> Int {
        // Basic calculation: 100 sats per km + time bonus
        let distanceBonus = Int(workout.distance / 1000) * 100
        let timeBonus = Int(workout.duration / 60) * 5
        return distanceBonus + timeBonus
    }
    
    /// Helper function to execute async operations with timeout
    private func withTimeout<T>(_ seconds: TimeInterval, _ operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Create mock workout event (placeholder for EventBuilder)
    private func createMockWorkoutEvent(keypair: Keypair, workout: Workout, privacyLevel: NostrPrivacyLevel) throws -> MockEvent {
        // TODO: Replace with actual EventBuilder when API is stable
        let content = createWorkoutEventContent(workout)
        let tags: [[String]] = privacyLevel == .public ? [["t", "running"]] : []
        
        return MockEvent(
            kind: 1065,
            content: content,
            tags: tags,
            pubkey: keypair.publicKey.hex,
            createdAt: UInt64(Date().timeIntervalSince1970)
        )
    }
    
    /// Create mock team event (placeholder for NIP-51 list creation)
    private func createMockTeamEvent(keypair: Keypair, content: String, teamID: String) throws -> MockEvent {
        // TODO: Replace with actual EventBuilder for NIP-51 lists
        let tags = [["d", teamID], ["title", "Team Membership"]]
        
        return MockEvent(
            kind: 30001, // NIP-51 lists
            content: content,
            tags: tags,
            pubkey: keypair.publicKey.hex,
            createdAt: UInt64(Date().timeIntervalSince1970)
        )
    }
    
}

// MARK: - Data Models

/// Nostr workout event following NIP-101e
struct NostrWorkoutEvent: Identifiable, Codable {
    let id: String
    let pubkey: String
    let createdAt: Date
    let kind: Int // 1065 for workout events
    let content: String
    let tags: [[String]]
    let workout: Workout
    
    var formattedContent: String {
        if let data = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return "\(json["type"] as? String ?? "Workout") - \(json["distance"] as? Double ?? 0)m in \(json["duration"] as? Double ?? 0)s"
        }
        return "Workout Event"
    }
    
    // MARK: - Computed Properties (for StatsService compatibility)
    var timestamp: Date {
        return createdAt
    }
    
    var activityType: ActivityType {
        return workout.activityType
    }
    
    var distance: Double {
        return workout.distance
    }
    
    var averagePace: Double {
        return workout.averagePace
    }
    
    var satsEarned: Int {
        return workout.rewardAmount
    }
    
    var location: String? {
        return nil // TODO: Extract location from workout data if available
    }
    
    var duration: TimeInterval {
        return workout.duration
    }
    
    var calories: Double? {
        return workout.calories
    }
}


// MARK: - NostrWorkoutEvent Model

struct WorkoutSummary: Codable, Identifiable {
    let id: String
    let pubkey: String
    let timestamp: Date
    let activityType: ActivityType
    let distance: Double // meters
    let duration: TimeInterval // seconds
    let averagePace: Double // min/km
    let calories: Double?
    let location: String?
    let satsEarned: Int
}

// MARK: - Nostr Errors

enum NostrError: LocalizedError {
    case notConnected
    case filterCreationFailed
    case eventCreationFailed
    case signingFailed
    case publishFailed
    case invalidNpub
    case delegationFailed
    case connectionTimeout
    case relayConnectionFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Nostr relays"
        case .filterCreationFailed:
            return "Failed to create event filter"
        case .eventCreationFailed:
            return "Failed to create Nostr event"
        case .signingFailed:
            return "Failed to sign event"
        case .publishFailed:
            return "Failed to publish event to relays"
        case .invalidNpub:
            return "Invalid npub format"
        case .delegationFailed:
            return "Failed to setup delegation"
        case .connectionTimeout:
            return "Connection to relays timed out"
        case .relayConnectionFailed:
            return "Failed to connect to Nostr relays"
        }
    }
}

/// Timeout error for async operations
struct TimeoutError: LocalizedError {
    var errorDescription: String? {
        return "Operation timed out"
    }
}

// MARK: - Mock NostrSDK Classes
// TODO: Remove these mocks when NostrSDK 0.3.0 API is stable

/// Mock RelayPool for development
class MockRelayPool {
    private let relays: [String]
    private var isConnected = false
    
    init(relays: [String]) {
        self.relays = relays
    }
    
    func disconnect() {
        isConnected = false
        print("📡 MockRelayPool disconnected")
    }
    
    func subscribe(subscription: MockSubscription) {
        print("📡 MockRelayPool subscribed: \(subscription.id)")
    }
    
    func publish(event: MockEvent) -> Bool {
        print("📡 MockRelayPool published event kind \(event.kind)")
        return true
    }
}

/// Mock Subscription for development
struct MockSubscription {
    let id: String
    let filter: MockFilter
}

/// Mock Filter for development
struct MockFilter {
    let kinds: [Int]
    let authors: [String]
    let since: UInt64?
    let until: UInt64?
}

/// Mock Event for development
struct MockEvent {
    let kind: Int
    let content: String
    let tags: [[String]]
    let pubkey: String
    let createdAt: UInt64
}

/// Mock Team Event for development (Kind 33404)
struct MockTeamEvent {
    let id: String
    let kind: Int
    let content: String
    let tags: [[String]]
    let pubkey: String
    let createdAt: UInt64
}

/// Mock Workout Event for development (Kind 1301)
struct MockWorkoutEvent {
    let id: String
    let kind: Int
    let content: String
    let tags: [[String]]
    let pubkey: String
    let createdAt: UInt64
}

/// Mock Workout for team statistics
struct MockWorkout {
    let id: String
    let userID: String
    let activityType: ActivityType
    let startTime: Date
    let distance: Double // meters
    let duration: TimeInterval // seconds
    let averagePace: Double // min/km
}

/// Member contribution tracking
struct MemberContribution {
    let userID: String
    var totalDistance: Double = 0.0
    var totalWorkouts: Int = 0
    var lastWorkoutDate: Date = Date.distantPast
    
    mutating func addWorkout(_ workout: MockWorkout) {
        totalDistance += workout.distance
        totalWorkouts += 1
        lastWorkoutDate = max(lastWorkoutDate, workout.startTime)
    }
}

/// Team member ranking for leaderboards
struct TeamMemberRanking {
    let userID: String
    let displayName: String
    let totalDistance: Double
    let totalWorkouts: Int
    let averagePace: Double
    var rank: Int
}

/// Leaderboard time periods
enum LeaderboardPeriod: String, CaseIterable {
    case week = "week"
    case month = "month"
    case year = "year"
    case allTime = "all_time"
    
    var displayName: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .allTime: return "All Time"
        }
    }
}

/// Privacy level for event publishing
enum NostrPrivacyLevel {
    case `public`
    case `private`
    case contactsOnly
}

// MARK: - Extensions

extension DateFormatter {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
}