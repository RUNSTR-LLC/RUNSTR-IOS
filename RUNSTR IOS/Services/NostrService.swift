import Foundation
import Combine
import NostrSDK
import Network
import CoreLocation

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
    @Published var nip46ConnectionManager: NIP46ConnectionManager?
    
    // MARK: - Private Properties
    private var relayPool: RelayPool?
    private var relays: [Relay] = []
    private let defaultRelays = [
        "wss://relay.nostr.band",
        "wss://nos.lol", 
        "wss://relay.damus.io",
        "wss://nostr.wine"
    ]
    private var subscriptions: [String: Subscription] = [:]
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "network_monitor")
    private var isNetworkAvailable = true
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    // MARK: - Initialization
    init() {
        loadStoredKeys()
        setupNetworkMonitoring()
    }
    
    /// Set NIP-46 connection manager for remote signing
    func setNIP46ConnectionManager(_ manager: NIP46ConnectionManager) {
        nip46ConnectionManager = manager
        isDelegatedSigning = manager.isConnected
        mainNostrPublicKey = manager.userPublicKey
        print("✅ NIP-46 connection manager configured")
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
    
    /// Link main Nostr identity (npub) for delegation via DM authorization
    func linkMainNostrIdentity(_ npub: String) async -> Bool {
        // TODO: Implement with proper NostrSDK 0.3.0 API
        errorMessage = "NIP-46 delegation not yet implemented"
        return false
    }
    
    /// Create delegation authorization message content
    private func createDelegationAuthorizationMessage() -> String {
        guard let keyPair = userKeyPair else { return "" }
        
        let message = """
        🏃‍♂️ RUNSTR Delegation Request
        
        Hello! This is a request from the RUNSTR fitness app to authorize workout data publishing on your behalf.
        
        RUNSTR App Identity: \(keyPair.publicKey)
        
        What this enables:
        • Automatic workout publishing to your Nostr identity
        • Your workout data will appear under your main npub
        • You maintain full control and can revoke at any time
        
        To APPROVE delegation:
        Reply to this DM with: "APPROVE RUNSTR DELEGATION"
        
        To DENY delegation:
        Reply to this DM with: "DENY RUNSTR DELEGATION"
        
        Security Note:
        - RUNSTR will only publish fitness-related events (Kind 1301)
        - Your private keys remain secure and are never shared
        - You can revoke this delegation at any time
        
        Learn more: https://runstr.app/delegation
        """
        
        return message
    }
    
    /// Check for delegation approval responses
    func checkDelegationApproval() async -> Bool {
        guard let keyPair = userKeyPair,
              let mainNpub = mainNostrPublicKey,
              let relayPool = relayPool, isConnected else {
            return false
        }
        
        do {
            // Parse main public key
            guard let mainPublicKey = try? PublicKey.parse(npub: mainNpub) else {
                return false
            }
            
            // Create filter for DMs from main npub to RUNSTR npub
            let filter = Filter()
            filter.kinds = [.directMessage] // Kind 4 for DMs
            filter.authors = [mainPublicKey]
            
            // Convert RUNSTR npub to public key for filtering
            guard let runstrPublicKey = try? PublicKey.parse(npub: keyPair.publicKey) else {
                return false
            }
            
            // Add recipient filter (p tag pointing to RUNSTR npub)
            // Note: This might need adjustment based on the actual nostr-sdk-ios API
            filter.since = Timestamp.fromSecs(secs: UInt64(Date().timeIntervalSince1970 - 3600)) // Last hour
            
            // Subscribe to get recent DMs
            let subscriptionId = "delegation_check_\(UUID().uuidString)"
            let subscription = try await createManagedSubscription(filters: [filter], subscriptionId: subscriptionId)
            
            // Check for approval/denial messages
            let timeout: TimeInterval = 5.0
            let startTime = Date()
            
            while Date().timeIntervalSince(startTime) < timeout {
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 second
                
                let events = try await subscription.getEvents()
                
                for event in events {
                    let content = event.content.uppercased()
                    
                    if content.contains("APPROVE RUNSTR DELEGATION") {
                        isDelegatedSigning = true
                        await closeSubscription(subscriptionId)
                        print("✅ Delegation approved by main npub!")
                        return true
                    } else if content.contains("DENY RUNSTR DELEGATION") {
                        mainNostrPublicKey = nil
                        isDelegatedSigning = false
                        await closeSubscription(subscriptionId)
                        print("❌ Delegation denied by main npub")
                        return false
                    }
                }
            }
            
            // Close subscription
            await closeSubscription(subscriptionId)
            
            return false
            
        } catch {
            print("❌ Failed to check delegation approval: \(error)")
            return false
        }
    }
    
    /// Revoke delegation authorization
    func revokeDelegation() async -> Bool {
        guard let mainNpub = mainNostrPublicKey else {
            errorMessage = "No main identity linked"
            return false
        }
        
        // Clear delegation status
        mainNostrPublicKey = nil
        isDelegatedSigning = false
        
        print("✅ Delegation revoked for: \(mainNpub)")
        return true
    }
    
    // MARK: - Relay Management
    
    /// Connect to default Nostr relays using real nostr-sdk-ios Client
    func connectToRelays() async {
        isConnected = false
        connectedRelays.removeAll()
        errorMessage = nil
        
        do {
            // Create relays from URLs
            relays.removeAll()
            for relayURLString in defaultRelays {
                guard let url = URL(string: relayURLString) else {
                    print("❌ Invalid relay URL: \(relayURLString)")
                    continue
                }
                
                do {
                    let relay = try Relay(url: url)
                    relays.append(relay)
                    print("✅ Added relay: \(relayURLString)")
                } catch {
                    print("❌ Failed to create relay \(relayURLString): \(error)")
                }
            }
            
            guard !relays.isEmpty else {
                errorMessage = "No valid relays found"
                return
            }
            
            // Create and configure relay pool
            relayPool = RelayPool(relays: Set(relays))
            guard let relayPool = relayPool else {
                errorMessage = "Failed to create relay pool"
                return
            }
            
            // In NostrSDK 0.3.0, we use the RelayPool directly for most operations
            // The client property is kept for compatibility with existing code patterns
            // but most operations go through the relay pool
            
            // Connect to relays
            await relayPool.connect()
            
            // Update connected relays list
            await MainActor.run {
                connectedRelays = relays.map { $0.url.absoluteString }
            }
            
            // Wait for connection establishment
            try await withTimeout(10.0) { [weak self] in
                guard let self = self else { return }
                
                var attempts = 0
                let maxAttempts = 20 // 10 seconds with 0.5s intervals
                
                while attempts < maxAttempts {
                    attempts += 1
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    // Check connection status by trying to get relay information
                    let connectedCount = self.connectedRelays.count
                    if connectedCount > 0 {
                        await MainActor.run {
                            self.isConnected = true
                            print("✅ Connected to \(connectedCount) relays")
                        }
                        return
                    }
                }
                
                await MainActor.run {
                    self.errorMessage = "Failed to connect to relays within timeout"
                    print("❌ Relay connection timeout after \(attempts * 500)ms")
                }
            }
            
        } catch {
            errorMessage = "Failed to initialize Nostr client: \(error.localizedDescription)"
            print("❌ Client initialization failed: \(error)")
        }
    }
    
    /// Disconnect from all relays
    func disconnectFromRelays() async {
        // Stop network monitoring
        networkMonitor.cancel()
        
        // Close all subscriptions gracefully
        await closeAllSubscriptions()
        
        await relayPool?.disconnect()
        relayPool = nil
        relays.removeAll()
        subscriptions.removeAll()
        connectedRelays.removeAll()
        isConnected = false
        reconnectAttempts = 0
        print("✅ Disconnected from all relays")
    }
    
    /// Reconnect to relays with exponential backoff (enhanced with network monitoring)
    func reconnectToRelays() async {
        guard isNetworkAvailable else {
            print("⚠️ Network unavailable, skipping reconnection attempt")
            return
        }
        
        print("🔄 Attempting to reconnect to relays... (attempt \(reconnectAttempts + 1)/\(maxReconnectAttempts))")
        
        while reconnectAttempts < maxReconnectAttempts && !isConnected && isNetworkAvailable {
            reconnectAttempts += 1
            let backoffDelay = TimeInterval(min(pow(2.0, Double(reconnectAttempts)), 60.0)) // Cap at 60s
            
            print("🔄 Reconnection attempt \(reconnectAttempts)/\(maxReconnectAttempts)")
            
            await connectToRelays()
            
            if !isConnected && reconnectAttempts < maxReconnectAttempts {
                print("⏳ Waiting \(backoffDelay)s before next retry...")
                try? await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
            }
        }
        
        if isConnected {
            print("✅ Successfully reconnected to relays")
            reconnectAttempts = 0 // Reset on successful connection
        } else {
            print("❌ Failed to reconnect after \(maxReconnectAttempts) attempts")
            errorMessage = "Unable to connect to Nostr relays after \(maxReconnectAttempts) attempts"
        }
    }
    
    /// Check relay connection health (enhanced with proper validation)
    func checkRelayHealth() async -> Bool {
        guard let relayPool = relayPool, !connectedRelays.isEmpty, isNetworkAvailable else {
            return false
        }
        
        do {
            // Send a simple NIP-01 REQ to test connectivity
            let healthCheckFilter = Filter()
            healthCheckFilter.kinds = [.metadata] // Kind 0 for profile metadata
            healthCheckFilter.limit = 1
            
            let subscriptionId = "health_check_\(UUID().uuidString)"
            let subscription = try relayPool.subscribe(filters: [healthCheckFilter], subscriptionId: subscriptionId)
            
            // Wait briefly for any response
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            
            // Close the health check subscription
            try await subscription.unsubscribe()
            
            print("✅ Relay health check passed")
            return true
            
        } catch {
            print("❌ Relay health check failed: \(error)")
            
            // If health check fails, attempt reconnection
            Task {
                await reconnectToRelays()
            }
            return false
        }
    }
    
    // MARK: - Event Publishing
    
    /// Publish workout event to Nostr relays using Kind 1301 (NIP-1301 workout record)
    func publishWorkoutEvent(_ workout: Workout, privacyLevel: NostrPrivacyLevel, teamID: String? = nil, challengeID: String? = nil) async -> Bool {
        guard let relayPool = relayPool, isConnected else {
            errorMessage = "Not connected to relays"
            return false
        }
        
        do {
            // Check if we should use NIP-46 remote signing
            if let connectionManager = nip46ConnectionManager, connectionManager.canSign {
                return await publishWorkoutEventWithRemoteSigning(workout, privacyLevel: privacyLevel, teamID: teamID, challengeID: challengeID)
            }
            
            // Fallback to local signing
            guard let keyPair = userKeyPair else {
                errorMessage = "No Nostr keys available"
                return false
            }
            
            // Create keypair from stored private key
            let keypair: Keypair
            do {
                keypair = try Keypair(nsec: keyPair.privateKey)!
            } catch {
                errorMessage = "Failed to create keypair from stored private key: \(error.localizedDescription)"
                return false
            }
            
            // Create workout event content
            let workoutContent = createWorkoutEventContent(workout)
            
            // Build tags for Kind 1301 event
            var tags: [[String]] = [
                ["d", workout.id],
                ["title", "RUNSTR Workout - \(workout.activityType.displayName)"],
                ["type", "cardio"],
                ["start", String(Int64(workout.startTime.timeIntervalSince1970))],
                ["end", String(Int64(workout.endTime.timeIntervalSince1970))],
                ["exercise", "33401:\(keyPair.publicKey):\(workout.id)", "", String(workout.distance/1000), String(workout.duration), String(workout.averagePace)],
                ["accuracy", "exact", "gps_watch"],
                ["client", "RUNSTR", "v1.0.0"]
            ]
            
            // Add heart rate if available
            if let heartRate = workout.averageHeartRate {
                tags.append(["heart_rate_avg", String(heartRate), "bpm"])
            }
            
            // Add GPS data if available (simplified for now)
            if let route = workout.route, !route.isEmpty {
                tags.append(["gps_polyline", "encoded_gps_data_placeholder"])
            }
            
            // Add team reference if provided
            if let teamID = teamID {
                tags.append(["team", "33404:\(keyPair.publicKey):\(teamID)", ""])
            }
            
            // Add challenge reference if provided
            if let challengeID = challengeID {
                tags.append(["challenge", "33403:\(keyPair.publicKey):\(challengeID)", ""])
            }
            
            // Add privacy and discovery tags
            if privacyLevel == .public {
                tags.append(["t", "fitness"])
                tags.append(["t", workout.activityType.rawValue])
            }
            
            // Build the event using EventBuilder with custom kind 1301
            let eventBuilder = EventBuilder()
                .kind(kind: .custom(1301)) // Kind 1301 for workout records
                .content(content: workoutContent)
            
            // Add all tags to the event
            for tag in tags {
                let _ = eventBuilder.addTags(tags: [Tag(standardTags: tag)])
            }
            
            // Build and sign the event
            let unsignedEvent = try eventBuilder.toUnsignedEvent(publicKey: keypair.publicKey)
            let signedEvent = try unsignedEvent.sign(keypair: keypair)
            
            // Publish to relays
            await relayPool.publishEvent(signedEvent)
            
            // Create our local event representation for tracking
            let localEvent = NostrWorkoutEvent(
                id: signedEvent.id.toHex(),
                pubkey: keyPair.publicKey,
                createdAt: Date(timeIntervalSince1970: TimeInterval(signedEvent.createdAt.asSecs())),
                kind: 1301, // NIP-1301 workout record
                content: workoutContent,
                tags: tags,
                workout: workout
            )
            
            // Add to recent events
            await MainActor.run {
                recentEvents.insert(localEvent, at: 0)
                
                // Keep only last 20 events
                if recentEvents.count > 20 {
                    recentEvents = Array(recentEvents.prefix(20))
                }
            }
            
            // Update team statistics if workout is linked to a team
            if let teamID = teamID {
                await updateTeamStatistics(teamID: teamID, workout: workout)
            }
            
            print("✅ Published workout event to Nostr: \(workout.activityType.displayName) - \(String(format: "%.2f", workout.distance/1000))km")
            print("   📝 Event ID: \(signedEvent.id.toHex())")
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
    
    /// Publish workout event using NIP-46 remote signing
    private func publishWorkoutEventWithRemoteSigning(_ workout: Workout, privacyLevel: NostrPrivacyLevel, teamID: String? = nil, challengeID: String? = nil) async -> Bool {
        guard let connectionManager = nip46ConnectionManager else {
            errorMessage = "No NIP-46 connection manager available"
            return false
        }
        
        guard let relayPool = relayPool, isConnected else {
            errorMessage = "Not connected to relays"
            return false
        }
        
        do {
            // Sign the workout event remotely using NIP-46
            let signedEvent = try await connectionManager.signWorkoutEvent(workout: workout, privacyLevel: privacyLevel)
            
            // Publish to relays
            await relayPool.publishEvent(signedEvent)
            
            // Create our local event representation for tracking
            let localEvent = NostrWorkoutEvent(
                id: signedEvent.id.toHex(),
                pubkey: connectionManager.userPublicKey ?? "unknown",
                createdAt: Date(timeIntervalSince1970: TimeInterval(signedEvent.createdAt.asSecs())),
                kind: 1301, // NIP-1301 workout record
                content: signedEvent.content,
                tags: signedEvent.tags.map { $0.asVec() },
                workout: workout
            )
            
            // Add to recent events
            await MainActor.run {
                recentEvents.insert(localEvent, at: 0)
                
                // Keep only last 20 events
                if recentEvents.count > 20 {
                    recentEvents = Array(recentEvents.prefix(20))
                }
            }
            
            // Update team statistics if workout is linked to a team
            if let teamID = teamID {
                await updateTeamStatistics(teamID: teamID, workout: workout)
            }
            
            print("✅ Published workout event via NIP-46 remote signing: \(workout.activityType.displayName) - \(String(format: "%.2f", workout.distance/1000))km")
            print("   📝 Event ID: \(signedEvent.id.toHex())")
            if let teamID = teamID {
                print("   🏃‍♂️ Linked to team: \(teamID)")
            }
            if let challengeID = challengeID {
                print("   🏆 Linked to challenge: \(challengeID)")
            }
            return true
            
        } catch {
            print("❌ Failed to publish workout event via NIP-46: \(error)")
            errorMessage = "Failed to publish event via remote signing: \(error.localizedDescription)"
            return false
        }
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
        
        // Process each workout event
        for workoutEvent in teamWorkouts {
            let workout = workoutEvent.workout
            let userID = workoutEvent.pubkey
            
            // Update total stats
            stats.totalDistance += workout.distance
            stats.totalWorkouts += 1
            
            // Update member contributions
            if memberContributions[userID] == nil {
                memberContributions[userID] = MemberContribution(userID: userID)
            }
            memberContributions[userID]?.addNostrWorkout(workoutEvent)
            
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
    private func fetchTeamWorkoutEvents(teamID: String) async -> [NostrWorkoutEvent] {
        guard let team = availableTeams.first(where: { $0.id == teamID }) else {
            return []
        }
        
        do {
            // Query for workout events from team members
            let workoutEvents = try await queryWorkoutEvents(
                since: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
                until: Date(),
                authors: team.memberIDs.map { "npub1\($0)" }, // Convert member IDs to npub format
                limit: 200
            )
            
            return workoutEvents
            
        } catch {
            print("❌ Failed to fetch team workout events: \(error)")
            return []
        }
    }
    
    
    /// Get team leaderboard with member rankings
    func getTeamLeaderboard(for teamID: String, period: LeaderboardPeriod = .allTime) async -> [TeamMemberRanking] {
        let teamWorkouts = await fetchTeamWorkoutEvents(teamID: teamID)
        
        // Filter workouts by period
        let filteredWorkouts = filterNostrWorkoutsByPeriod(teamWorkouts, period: period)
        
        // Group by member and calculate stats
        var memberStats: [String: MemberStats] = [:]
        
        for workoutEvent in filteredWorkouts {
            let userID = workoutEvent.pubkey
            let workout = workoutEvent.workout
            
            if memberStats[userID] == nil {
                memberStats[userID] = MemberStats()
            }
            
            memberStats[userID]?.totalDistance += workout.distance
            memberStats[userID]?.totalWorkouts += 1
            memberStats[userID]?.averagePace = calculateAveragePaceForNostrWorkouts(for: userID, in: filteredWorkouts)
            let currentLastWorkoutDate = memberStats[userID]?.lastWorkoutDate ?? Date.distantPast
            memberStats[userID]?.lastWorkoutDate = max(currentLastWorkoutDate, workout.startTime)
        }
        
        // Create rankings
        var rankings: [TeamMemberRanking] = []
        for (userID, stats) in memberStats {
            let ranking = TeamMemberRanking(
                userID: userID,
                displayName: "Member \(userID.suffix(8))", // Use pubkey suffix as display name
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
    
    /// Filter Nostr workout events by time period
    private func filterNostrWorkoutsByPeriod(_ workouts: [NostrWorkoutEvent], period: LeaderboardPeriod) -> [NostrWorkoutEvent] {
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
        
        return workouts.filter { $0.workout.startTime >= startDate }
    }
    
    /// Calculate average pace for a specific user from Nostr workout events
    private func calculateAveragePaceForNostrWorkouts(for userID: String, in workouts: [NostrWorkoutEvent]) -> Double {
        let userWorkouts = workouts.filter { $0.pubkey == userID }
        guard !userWorkouts.isEmpty else { return 0.0 }
        
        let totalPace = userWorkouts.reduce(0.0) { $0 + $1.workout.averagePace }
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
    
    
    // MARK: - Event Subscription and Querying
    
    /// Query workout events from relays for a specific time period
    func queryWorkoutEvents(since: Date? = nil, until: Date? = nil, authors: [String]? = nil, limit: Int = 100) async throws -> [NostrWorkoutEvent] {
        guard let relayPool = relayPool, isConnected else {
            throw NostrError.notConnected
        }
        
        do {
            // Create filter for Kind 1301 workout events
            let filter = Filter()
            filter.kinds = [.custom(1301)] // Kind 1301 for workout records
            
            if let since = since {
                filter.since = Timestamp.fromSecs(secs: UInt64(since.timeIntervalSince1970))
            }
            
            if let until = until {
                filter.until = Timestamp.fromSecs(secs: UInt64(until.timeIntervalSince1970))
            }
            
            if let authors = authors {
                // Convert npub strings to PublicKey objects
                let publicKeys = try authors.compactMap { npub in
                    try? PublicKey.parse(hex: npub)
                }
                filter.authors = publicKeys
            }
            
            filter.limit = UInt32(limit)
            
            // Create subscription
            let subscriptionId = UUID().uuidString
            let subscription = try relayPool.subscribe(filters: [filter], subscriptionId: subscriptionId)
            
            // Store subscription for management
            subscriptions[subscriptionId] = subscription
            
            // Wait for events to arrive
            var workoutEvents: [NostrWorkoutEvent] = []
            let timeout: TimeInterval = 10.0 // 10 second timeout
            let startTime = Date()
            
            while Date().timeIntervalSince(startTime) < timeout {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                
                // Get events from subscription
                let events = try await subscription.getEvents()
                
                for event in events {
                    // Parse event as workout event
                    if let workoutEvent = parseWorkoutEvent(from: event) {
                        workoutEvents.append(workoutEvent)
                    }
                }
                
                // Break if we have enough events or subscription is complete
                if workoutEvents.count >= limit {
                    break
                }
            }
            
            // Close subscription
            try await subscription.unsubscribe()
            subscriptions.removeValue(forKey: subscriptionId)
            
            print("✅ Queried \(workoutEvents.count) workout events from relays")
            return workoutEvents
            
        } catch {
            print("❌ Failed to query workout events: \(error)")
            throw error
        }
    }
    
    /// Parse a Nostr event into a NostrWorkoutEvent (enhanced with robust error handling)
    private func parseWorkoutEvent(from event: Event) -> NostrWorkoutEvent? {
        // Validate event kind (Kind 1301 for workout records)
        guard event.kind.asU32() == 1301 else {
            print("⚠️ Skipping non-workout event: kind \(event.kind.asU32())")
            return nil
        }
        
        // Extract and validate tags
        let tags = event.tags.map { $0.asVec() }
        guard let dTag = tags.first(where: { $0.first == "d" })?.last else {
            print("❌ Missing required 'd' tag in workout event")
            return nil
        }
        
        // Parse workout data from content (JSON with fallback parsing)
        guard let contentData = event.content.data(using: .utf8) else {
            print("❌ Invalid UTF-8 content in workout event")
            return nil
        }
        
        guard let workoutData = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            print("❌ Failed to parse JSON content in workout event")
            return nil
        }
        
        // Enhanced parsing with flexible field handling
        guard let activityTypeString = workoutData["type"] as? String,
              let activityType = ActivityType(rawValue: activityTypeString) else {
            print("❌ Invalid or missing activity type: \(workoutData["type"] ?? "nil")")
            return nil
        }
        
        // Distance can be stored in meters or kilometers
        guard let distanceValue = workoutData["distance"] as? Double else {
            print("❌ Missing distance value in workout event")
            return nil
        }
        let distance = distanceValue < 100 ? distanceValue * 1000 : distanceValue // Convert km to meters if needed
        
        // Duration parsing with multiple format support
        guard let duration = workoutData["duration"] as? TimeInterval else {
            print("❌ Missing duration value in workout event")
            return nil
        }
        
        // Flexible timestamp parsing
        let startTime: Date
        if let startTimeString = workoutData["startTime"] as? String,
           let startTimeDate = ISO8601DateFormatter().date(from: startTimeString) {
            startTime = startTimeDate
        } else if let startTimeStamp = workoutData["start_time"] as? Int64 {
            startTime = Date(timeIntervalSince1970: TimeInterval(startTimeStamp))
        } else if let startTimeStamp = workoutData["startTime"] as? TimeInterval {
            startTime = Date(timeIntervalSince1970: startTimeStamp)
        } else {
            print("❌ Missing or invalid start time in workout event")
            return nil
        }
        
        let endTime: Date
        if let endTimeString = workoutData["endTime"] as? String,
           let endTimeDate = ISO8601DateFormatter().date(from: endTimeString) {
            endTime = endTimeDate
        } else {
            endTime = startTime.addingTimeInterval(duration)
        }
        
        // Enhanced parsing of optional fields with error handling
        let averagePace = parseDouble(from: workoutData, key: "averagePace") ?? parseDouble(from: workoutData, key: "pace") ?? 0.0
        let calories = parseDouble(from: workoutData, key: "calories")
        let averageHeartRate = parseDouble(from: workoutData, key: "averageHeartRate") ?? parseDouble(from: workoutData, key: "heart_rate_avg")
        let maxHeartRate = parseDouble(from: workoutData, key: "maxHeartRate") ?? parseDouble(from: workoutData, key: "heart_rate_max")
        let elevationGain = parseDouble(from: workoutData, key: "elevationGain") ?? parseDouble(from: workoutData, key: "elevation_gain")
        
        // Parse route data if available
        let route = parseRouteData(from: workoutData, tags: tags)
        
        // Parse additional metadata from tags
        let rewardAmount = parseWorkoutMetadata(from: tags)
        
        // Create workout object with comprehensive data
        let workout = Workout(
            id: dTag,
            userID: event.author.toHex(),
            activityType: activityType,
            startTime: startTime,
            endTime: endTime,
            distance: distance,
            duration: duration,
            averagePace: averagePace,
            calories: calories,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            elevationGain: elevationGain,
            route: route,
            weather: nil, // TODO: Parse weather data if available
            nostrEventID: event.id.toHex(),
            rewardAmount: rewardAmount
        )
        
        let nostrWorkoutEvent = NostrWorkoutEvent(
            id: event.id.toHex(),
            pubkey: event.author.toHex(),
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt.asSecs())),
            kind: Int(event.kind.asU32()),
            content: event.content,
            tags: tags,
            workout: workout
        )
        
        print("✅ Successfully parsed workout event: \(activityType.displayName) - \(String(format: "%.2f", distance/1000))km")
        return nostrWorkoutEvent
    }
    
    /// Helper to safely parse double values from workout data
    private func parseDouble(from data: [String: Any], key: String) -> Double? {
        if let value = data[key] as? Double {
            return value
        } else if let value = data[key] as? String, let doubleValue = Double(value) {
            return doubleValue
        } else if let value = data[key] as? Int {
            return Double(value)
        }
        return nil
    }
    
    /// Parse route data from workout content and tags
    private func parseRouteData(from workoutData: [String: Any], tags: [[String]]) -> [CLLocationCoordinate2D]? {
        // Look for GPS polyline in tags
        if let gpsPolylineTag = tags.first(where: { $0.first == "gps_polyline" }),
           gpsPolylineTag.count > 1,
           gpsPolylineTag[1] != "encoded_gps_data_placeholder" {
            // TODO: Implement actual polyline decoding
            print("📍 Found GPS polyline data (decoding not yet implemented)")
            return nil
        }
        
        // Look for route data in JSON content
        if let routeArray = workoutData["route"] as? [[String: Any]] {
            var route: [CLLocationCoordinate2D] = []
            for routePoint in routeArray {
                if let latitude = parseDouble(from: routePoint, key: "latitude"),
                   let longitude = parseDouble(from: routePoint, key: "longitude") {
                    let altitude = parseDouble(from: routePoint, key: "altitude")
                    let timestamp = parseDouble(from: routePoint, key: "timestamp").map { Date(timeIntervalSince1970: $0) }
                    
                    route.append(CLLocationCoordinate2D(
                        latitude: latitude,
                        longitude: longitude
                    ))
                }
            }
            
            if !route.isEmpty {
                print("📍 Parsed \(route.count) route points")
                return route
            }
        }
        
        return nil
    }
    
    /// Parse workout metadata from tags
    private func parseWorkoutMetadata(from tags: [[String]]) -> Int {
        var rewardAmount = 0
        
        // Look for reward/sats tags
        if let rewardTag = tags.first(where: { $0.first == "reward" || $0.first == "sats" }),
           rewardTag.count > 1,
           let reward = Int(rewardTag[1]) {
            rewardAmount = reward
        }
        
        return rewardAmount
    }
    
    /// Fetch workout events for a specific npub and timeframe (for StatsService)
    func fetchWorkoutEvents(for npub: String, timeframe: TimeFrame) async -> [NostrWorkoutEvent] {
        let (since, until) = timeframe.dateRange
        
        do {
            let events = try await queryWorkoutEvents(
                since: since,
                until: until,
                authors: [npub],
                limit: 500
            )
            
            print("✅ Fetched \(events.count) workout events for npub: \(npub.prefix(8))...")
            return events
            
        } catch {
            print("❌ Failed to fetch workout events for \(npub.prefix(8))...: \(error)")
            return []
        }
    }
    
    /// Subscribe to workout events from followed users in real-time (enhanced with active monitoring)
    func subscribeToWorkoutEvents(authors: [String]? = nil) async {
        guard let relayPool = relayPool, isConnected else {
            print("❌ Cannot subscribe: not connected to relays")
            return
        }
        
        do {
            // Create filter for real-time Kind 1301 workout events
            let filter = Filter()
            filter.kinds = [.custom(1301)]
            filter.since = Timestamp.now()
            
            // Filter by specific authors if provided
            if let authors = authors {
                let publicKeys = try authors.compactMap { npub in
                    try? PublicKey.parse(npub: npub)
                }
                filter.authors = publicKeys
                print("📡 Subscribing to workout events from \(publicKeys.count) specific authors")
            } else {
                print("📡 Subscribing to all workout events")
            }
            
            let subscriptionId = "workout_events_realtime"
            
            // Close existing subscription if any
            await closeSubscription(subscriptionId)
            
            // Create new managed subscription
            let subscription = try await createManagedSubscription(
                filters: [filter],
                subscriptionId: subscriptionId
            )
            
            print("✅ Subscribed to real-time workout events")
            
            // Start background task to monitor incoming events
            startWorkoutEventMonitoring(subscription: subscription, subscriptionId: subscriptionId)
            
        } catch {
            print("❌ Failed to subscribe to workout events: \(error)")
            errorMessage = "Failed to subscribe to real-time events: \(error.localizedDescription)"
        }
    }
    
    /// Start monitoring workout events from subscription
    private func startWorkoutEventMonitoring(subscription: Subscription, subscriptionId: String) {
        Task {
            print("🔍 Starting workout event monitoring...")
            
            while subscriptions[subscriptionId] != nil && isConnected {
                do {
                    // Check for new events every 2 seconds
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    
                    let events = try await subscription.getEvents()
                    
                    for event in events {
                        if let workoutEvent = parseWorkoutEvent(from: event) {
                            await MainActor.run {
                                // Add to recent events at the top
                                if !recentEvents.contains(where: { $0.id == workoutEvent.id }) {
                                    recentEvents.insert(workoutEvent, at: 0)
                                    
                                    // Keep only last 50 events
                                    if recentEvents.count > 50 {
                                        recentEvents = Array(recentEvents.prefix(50))
                                    }
                                    
                                    print("📥 New workout event: \(workoutEvent.workout.activityType.displayName) from \(workoutEvent.pubkey.prefix(8))...")
                                    
                                    // Notify UI about new event (could trigger push notification)
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("NewWorkoutEvent"),
                                        object: workoutEvent
                                    )
                                }
                            }
                        }
                    }
                    
                } catch {
                    print("❌ Error monitoring workout events: \(error)")
                    
                    // If error persists, try to reconnect
                    if !isConnected {
                        print("🔄 Connection lost, attempting to resubscribe...")
                        try? await Task.sleep(nanoseconds: 5_000_000_000) // Wait 5 seconds
                        
                        if isConnected {
                            await subscribeToWorkoutEvents()
                        }
                        break
                    }
                }
            }
            
            print("⏹️ Workout event monitoring stopped")
        }
    }
    
    /// Subscribe to team activity updates in real-time
    func subscribeToTeamActivity(teamIDs: [String]) async {
        guard let relayPool = relayPool, isConnected else {
            print("❌ Cannot subscribe: not connected to relays")
            return
        }
        
        do {
            // Create filter for team-related events
            let filter = Filter()
            filter.kinds = [.custom(1301), .custom(33404)] // Workout events and team events
            filter.since = Timestamp.now()
            
            // Add team-specific filtering via tags
            // This is a simplified approach - in production you'd want more sophisticated filtering
            
            let subscriptionId = "team_activity_realtime"
            
            // Close existing subscription
            await closeSubscription(subscriptionId)
            
            // Create new subscription
            let subscription = try await createManagedSubscription(
                filters: [filter],
                subscriptionId: subscriptionId
            )
            
            print("✅ Subscribed to real-time team activity")
            
            // Start background monitoring
            startTeamActivityMonitoring(subscription: subscription, subscriptionId: subscriptionId, teamIDs: teamIDs)
            
        } catch {
            print("❌ Failed to subscribe to team activity: \(error)")
            errorMessage = "Failed to subscribe to team activity: \(error.localizedDescription)"
        }
    }
    
    /// Monitor team activity events
    private func startTeamActivityMonitoring(subscription: Subscription, subscriptionId: String, teamIDs: [String]) {
        Task {
            print("🔍 Starting team activity monitoring for \(teamIDs.count) teams...")
            
            while subscriptions[subscriptionId] != nil && isConnected {
                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000) // Check every 3 seconds
                    
                    let events = try await subscription.getEvents()
                    
                    for event in events {
                        let tags = event.tags.map { $0.asVec() }
                        
                        // Check if this event is related to our teams
                        let isTeamRelated = teamIDs.contains { teamID in
                            tags.contains { tag in
                                tag.contains(teamID) || tag.contains("33404:\(event.author.toHex()):\(teamID)")
                            }
                        }
                        
                        if isTeamRelated {
                            if event.kind.asU32() == 1301 {
                                // Handle workout event
                                if let workoutEvent = parseWorkoutEvent(from: event) {
                                    print("👥 Team workout event: \(workoutEvent.workout.activityType.displayName)")
                                    
                                    // Post notification for team activity
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("TeamWorkoutEvent"),
                                        object: workoutEvent
                                    )
                                }
                            } else if event.kind.asU32() == 33404 {
                                // Handle team update event
                                if let team = parseTeamFromEvent(event) {
                                    print("👥 Team update: \(team.name)")
                                    
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("TeamUpdateEvent"),
                                        object: team
                                    )
                                }
                            }
                        }
                    }
                    
                } catch {
                    print("❌ Error monitoring team activity: \(error)")
                    
                    if !isConnected {
                        print("🔄 Connection lost, will resubscribe when reconnected")
                        break
                    }
                }
            }
            
            print("⏹️ Team activity monitoring stopped")
        }
    }
    
    /// Stop all real-time subscriptions
    func stopRealtimeSubscriptions() async {
        await closeSubscription("workout_events_realtime")
        await closeSubscription("team_activity_realtime")
        print("✅ Stopped all real-time subscriptions")
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
            
            // No fallback to mock data - show empty state
            availableTeams = []
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
    private func queryFilteredTeamEvents(activityLevel: ActivityLevel?, location: String?, teamType: String?, activityTypes: [ActivityType]?) async throws -> [Event] {
        guard let relayPool = relayPool, isConnected else {
            throw NostrError.notConnected
        }
        
        do {
            // Create filter for Kind 33404 (Fitness Team) events
            let filter = Filter()
            filter.kinds = [.custom(33404)]
            filter.limit = 100
            
            // Add location filter if provided
            if let location = location {
                // Add search by location tag
                filter.search = location
            }
            
            // Create subscription for filtered team events
            let subscriptionId = "filtered_team_events_\(UUID().uuidString)"
            let subscription = try relayPool.subscribe(filters: [filter], subscriptionId: subscriptionId)
            
            // Store subscription for management
            subscriptions[subscriptionId] = subscription
            
            // Wait for events to arrive
            var teamEvents: [Event] = []
            let timeout: TimeInterval = 10.0
            let startTime = Date()
            
            while Date().timeIntervalSince(startTime) < timeout {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                
                let events = try await subscription.getEvents()
                
                for event in events {
                    // Verify this is a team event and apply filters
                    let tags = event.tags.map { $0.asVec() }
                    
                    if tags.contains(where: { $0.first == "t" && $0.last == "team" }) {
                        var matchesFilters = true
                        
                        // Filter by activity level
                        if let activityLevel = activityLevel {
                            let eventActivityLevel = parseActivityLevelFromTags(tags)
                            if eventActivityLevel != activityLevel {
                                matchesFilters = false
                            }
                        }
                        
                        // Filter by team type
                        if let teamType = teamType {
                            let eventTeamType = tags.first(where: { $0.first == "type" })?.last
                            if eventTeamType != teamType {
                                matchesFilters = false
                            }
                        }
                        
                        if matchesFilters {
                            teamEvents.append(event)
                        }
                    }
                }
                
                if teamEvents.count >= 50 {
                    break
                }
            }
            
            // Close subscription
            try await subscription.unsubscribe()
            subscriptions.removeValue(forKey: subscriptionId)
            
            return teamEvents
            
        } catch {
            print("❌ Failed to query filtered team events: \(error)")
            throw error
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
    private func queryTeamEvents() async throws -> [Event] {
        guard let relayPool = relayPool, isConnected else {
            throw NostrError.notConnected
        }
        
        do {
            // Create filter for Kind 33404 (Fitness Team) events
            let filter = Filter()
            filter.kinds = [.custom(33404)] // Kind 33404 for fitness teams
            filter.limit = 100 // Limit to 100 teams for now
            
            // Create subscription for team events
            let subscriptionId = "team_events_\(UUID().uuidString)"
            let subscription = try await createManagedSubscription(filters: [filter], subscriptionId: subscriptionId)
            
            // Wait for events to arrive
            var teamEvents: [Event] = []
            let timeout: TimeInterval = 10.0 // 10 second timeout
            let startTime = Date()
            
            while Date().timeIntervalSince(startTime) < timeout {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                
                // Get events from subscription
                let events = try await subscription.getEvents()
                
                for event in events {
                    // Verify this is a team event by checking for required tags
                    let tags = event.tags.map { $0.asVec() }
                    if tags.contains(where: { $0.first == "t" && $0.last == "team" }) {
                        teamEvents.append(event)
                    }
                }
                
                // Break if we have a reasonable number of teams
                if teamEvents.count >= 50 {
                    break
                }
            }
            
            // Close subscription
            await closeSubscription(subscriptionId)
            
            print("✅ Queried \(teamEvents.count) team events from relays")
            return teamEvents
            
        } catch {
            print("❌ Failed to query team events: \(error)")
            throw error
        }
    }
    
    
    /// Parse a team event into a Team object (enhanced with robust parsing)
    private func parseTeamFromEvent(_ event: Event) -> Team? {
        // Validate event kind (Kind 33404 for fitness teams)
        guard event.kind.asU32() == 33404 else {
            print("⚠️ Skipping non-team event: kind \(event.kind.asU32())")
            return nil
        }
        
        // Extract and validate tags
        let tags = event.tags.map { $0.asVec() }
        
        // Validate that this is indeed a team event
        guard tags.contains(where: { $0.first == "t" && $0.last == "team" }) else {
            print("❌ Missing team tag in Kind 33404 event")
            return nil
        }
        
        // Extract team name from content or tags
        let teamName: String
        if !event.content.isEmpty {
            // Try parsing JSON content first
            if let contentData = event.content.data(using: .utf8),
               let contentJson = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
               let name = contentJson["name"] as? String, !name.isEmpty {
                teamName = name
            } else {
                // Use content as plain text name
                teamName = event.content
            }
        } else if let nameTag = tags.first(where: { $0.first == "name" })?.last {
            teamName = nameTag
        } else {
            print("❌ Missing team name in team event")
            return nil
        }
        
        // Parse team description
        let description: String
        if let descTag = tags.first(where: { $0.first == "description" })?.last {
            description = descTag
        } else if let contentData = event.content.data(using: .utf8),
                  let contentJson = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
                  let desc = contentJson["description"] as? String {
            description = desc
        } else {
            description = "No description provided"
        }
        
        // Parse activity level
        let activityLevel = parseActivityLevelFromTags(tags)
        
        // Parse team type
        let teamType = tags.first(where: { $0.first == "type" })?.last ?? "running_club"
        
        // Parse location
        let location = tags.first(where: { $0.first == "location" })?.last
        
        // Parse maximum members
        let maxMembers: Int
        if let maxMembersTag = tags.first(where: { $0.first == "max_members" })?.last,
           let maxMembersValue = Int(maxMembersTag) {
            maxMembers = maxMembersValue
        } else {
            maxMembers = 100 // Default maximum
        }
        
        // Parse member list from NIP-51 style p tags
        var memberIDs: [String] = []
        for tag in tags {
            if tag.first == "p" && tag.count > 1 {
                memberIDs.append(tag[1])
            }
        }
        
        // Parse visibility settings
        let isPublic = !tags.contains { $0.first == "private" }
        
        // Parse join requirements
        let joinRequirements = parseJoinRequirements(from: tags)
        
        // Parse additional metadata
        let metadata = parseTeamMetadata(from: tags, content: event.content)
        
        // Create the team object
        let team = Team(
            id: event.id.toHex(),
            name: teamName,
            description: description,
            captainID: event.author.toHex(),
            memberIDs: memberIDs,
            activityLevel: activityLevel,
            maxMembers: maxMembers,
            isPublic: isPublic,
            teamType: teamType,
            location: location,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt.asSecs())),
            joinRequirements: joinRequirements,
            stats: TeamStats() // Will be populated separately
        )
        
        print("✅ Successfully parsed team: \(teamName) with \(memberIDs.count) members")
        print("   📍 Location: \(location ?? "Not specified")")
        print("   🏃‍♂️ Activity Level: \(activityLevel.displayName)")
        print("   👥 Max Members: \(maxMembers)")
        
        return team
    }
    
    /// Parse join requirements from team event tags
    private func parseJoinRequirements(from tags: [[String]]) -> [String] {
        var requirements: [String] = []
        
        for tag in tags {
            if tag.first == "requirement" && tag.count > 1 {
                requirements.append(tag[1])
            }
        }
        
        // Default requirements if none specified
        if requirements.isEmpty {
            requirements = ["Complete at least 1 workout per week"]
        }
        
        return requirements
    }
    
    /// Parse additional team metadata from tags and content
    private func parseTeamMetadata(from tags: [[String]], content: String) -> (badges: [String], rules: [String]) {
        var badges: [String] = []
        var rules: [String] = []
        
        // Parse badges from tags
        for tag in tags {
            if tag.first == "badge" && tag.count > 1 {
                badges.append(tag[1])
            }
        }
        
        // Parse rules from tags
        for tag in tags {
            if tag.first == "rule" && tag.count > 1 {
                rules.append(tag[1])
            }
        }
        
        // Try to parse additional data from JSON content
        if let contentData = content.data(using: .utf8),
           let contentJson = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
            
            if let contentBadges = contentJson["badges"] as? [String] {
                badges.append(contentsOf: contentBadges)
            }
            
            if let contentRules = contentJson["rules"] as? [String] {
                rules.append(contentsOf: contentRules)
            }
        }
        
        return (badges: badges, rules: rules)
    }
    
    /// Parse activity level from event tags
    private func parseActivityLevelFromTags(_ tags: [[String]]) -> ActivityLevel {
        if let levelTag = tags.first(where: { $0.first == "activity_level" })?.last {
            return ActivityLevel(rawValue: levelTag) ?? .intermediate
        }
        return .intermediate
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
        
        guard let relayPool = relayPool, isConnected else {
            errorMessage = "Not connected to relays"
            return false
        }
        
        do {
            // Create keypair from stored private key
            let keypair: Keypair
            do {
                keypair = try Keypair(nsec: keyPair.privateKey)!
            } catch {
                errorMessage = "Failed to create keypair from stored private key: \(error.localizedDescription)"
                return false
            }
            
            // Build the team event using EventBuilder
            let eventBuilder = EventBuilder()
                .kind(kind: .custom(33404)) // Kind 33404 for fitness teams
                .content(content: fitnessTeamEvent.content)
            
            // Add all tags to the event
            let tags = fitnessTeamEvent.createNostrTags()
            for tag in tags {
                let _ = eventBuilder.addTags(tags: [Tag(standardTags: tag)])
            }
            
            // Build and sign the event
            let unsignedEvent = try eventBuilder.toUnsignedEvent(publicKey: keypair.publicKey)
            let signedEvent = try unsignedEvent.sign(keypair: keypair)
            
            // Publish to relays
            await relayPool.publishEvent(signedEvent)
            
            print("✅ Published Kind 33404 team event to Nostr: \(fitnessTeamEvent.name)")
            print("   📝 Event ID: \(signedEvent.id.toHex())")
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
        
        do {
            // Query for Kind 33403 (Event) events from Nostr relays
            let eventEvents = try await queryEventEvents()
            
            // Parse event events into Event objects
            var events: [Event] = []
            for event in eventEvents {
                if let parsedEvent = parseEventFromNostrEvent(event) {
                    events.append(parsedEvent)
                }
            }
            
            availableEvents = events
            print("✅ Loaded \(events.count) events from Nostr relays")
            
        } catch {
            print("❌ Failed to fetch events: \(error)")
            errorMessage = "Failed to fetch events: \(error.localizedDescription)"
            availableEvents = []
        }
        
        isLoadingEvents = false
        print("✅ Loaded \(availableEvents.count) events from Nostr")
    }
    
    /// Query for Kind 33403 event events from Nostr relays
    private func queryEventEvents() async throws -> [Event] {
        guard let relayPool = relayPool, isConnected else {
            throw NostrError.notConnected
        }
        
        do {
            // Create filter for Kind 33403 (Event) events
            let filter = Filter()
            filter.kinds = [.custom(33403)] // Kind 33403 for events
            filter.limit = 50 // Limit to 50 events
            
            // Create subscription for event events
            let subscriptionId = "event_events_\(UUID().uuidString)"
            let subscription = try relayPool.subscribe(filters: [filter], subscriptionId: subscriptionId)
            
            // Store subscription for management
            subscriptions[subscriptionId] = subscription
            
            // Wait for events to arrive
            var eventEvents: [Event] = []
            let timeout: TimeInterval = 10.0
            let startTime = Date()
            
            while Date().timeIntervalSince(startTime) < timeout {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                
                let events = try await subscription.getEvents()
                
                for event in events {
                    // Verify this is an event by checking for required tags
                    let tags = event.tags.map { $0.asVec() }
                    if tags.contains(where: { $0.first == "t" && $0.last == "event" }) {
                        eventEvents.append(event)
                    }
                }
                
                if eventEvents.count >= 25 {
                    break
                }
            }
            
            // Close subscription
            try await subscription.unsubscribe()
            subscriptions.removeValue(forKey: subscriptionId)
            
            print("✅ Queried \(eventEvents.count) event events from relays")
            return eventEvents
            
        } catch {
            print("❌ Failed to query event events: \(error)")
            throw error
        }
    }
    
    /// Parse an Event from a Nostr event
    private func parseEventFromNostrEvent(_ nostrEvent: Event) -> Event? {
        let tags = nostrEvent.tags.map { $0.asVec() }
        
        // Extract event details from tags
        guard let nameTag = tags.first(where: { $0.first == "name" })?.last,
              let goalTypeTag = tags.first(where: { $0.first == "goal_type" })?.last,
              let targetValueTag = tags.first(where: { $0.first == "target_value" })?.last,
              let targetValue = Double(targetValueTag),
              let difficultyTag = tags.first(where: { $0.first == "difficulty" })?.last,
              let eventTypeTag = tags.first(where: { $0.first == "event_type" })?.last,
              let prizePoolTag = tags.first(where: { $0.first == "prize_pool" })?.last,
              let prizePool = Int(prizePoolTag),
              let startDateTag = tags.first(where: { $0.first == "start_date" })?.last,
              let startDateTimestamp = TimeInterval(startDateTag),
              let endDateTag = tags.first(where: { $0.first == "end_date" })?.last,
              let endDateTimestamp = TimeInterval(endDateTag) else {
            return nil
        }
        
        let goalType = EventGoalType(rawValue: goalTypeTag) ?? .totalDistance
        let difficulty = EventDifficulty(rawValue: difficultyTag) ?? .intermediate
        let eventType = EventType(rawValue: eventTypeTag) ?? .individual
        
        let startDate = Date(timeIntervalSince1970: startDateTimestamp)
        let endDate = Date(timeIntervalSince1970: endDateTimestamp)
        
        return Event(
            name: nameTag,
            description: nostrEvent.content,
            createdBy: nostrEvent.author.hex,
            startDate: startDate,
            endDate: endDate,
            goalType: goalType,
            targetValue: targetValue,
            difficulty: difficulty,
            eventType: eventType,
            prizePool: prizePool
        )
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
    
    
    // MARK: - Subscription Management
    
    /// Create a managed subscription with automatic cleanup
    private func createManagedSubscription(filters: [Filter], subscriptionId: String) async throws -> Subscription {
        guard let relayPool = relayPool, isConnected else {
            throw NostrError.notConnected
        }
        
        do {
            let subscription = try relayPool.subscribe(filters: filters, subscriptionId: subscriptionId)
            subscriptions[subscriptionId] = subscription
            
            print("✅ Created managed subscription: \(subscriptionId)")
            return subscription
            
        } catch {
            print("❌ Failed to create subscription \(subscriptionId): \(error)")
            throw error
        }
    }
    
    /// Close and remove a specific subscription
    private func closeSubscription(_ subscriptionId: String) async {
        guard let subscription = subscriptions[subscriptionId] else {
            return
        }
        
        do {
            try await subscription.unsubscribe()
            subscriptions.removeValue(forKey: subscriptionId)
            print("✅ Closed subscription: \(subscriptionId)")
        } catch {
            print("⚠️ Error closing subscription \(subscriptionId): \(error)")
            // Remove from tracking even if close failed to prevent memory leaks
            subscriptions.removeValue(forKey: subscriptionId)
        }
    }
    
    /// Close all active subscriptions
    private func closeAllSubscriptions() async {
        let activeSubscriptions = Array(subscriptions.keys)
        
        await withTaskGroup(of: Void.self) { group in
            for subscriptionId in activeSubscriptions {
                group.addTask {
                    await self.closeSubscription(subscriptionId)
                }
            }
        }
        
        print("✅ Closed all \(activeSubscriptions.count) subscriptions")
    }
    
    /// Clean up stale subscriptions (older than specified duration)
    private func cleanupStaleSubscriptions(olderThan duration: TimeInterval = 300) async { // 5 minutes default
        let currentTime = Date()
        let staleThreshold = currentTime.addingTimeInterval(-duration)
        
        // For now, we'll close all subscriptions as we don't track creation time
        // In a production app, you'd want to track subscription creation times
        let subscriptionCount = subscriptions.count
        if subscriptionCount > 10 { // Arbitrary threshold
            print("🧹 Cleaning up \(subscriptionCount) subscriptions to prevent resource buildup")
            await closeAllSubscriptions()
        }
    }
    
    // MARK: - Network Monitoring
    
    /// Setup network monitoring to handle connection changes
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                
                let wasNetworkAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied
                
                if self.isNetworkAvailable && !wasNetworkAvailable {
                    print("🌐 Network became available, attempting reconnection...")
                    self.reconnectAttempts = 0 // Reset attempts on network recovery
                    await self.reconnectToRelays()
                } else if !self.isNetworkAvailable && wasNetworkAvailable {
                    print("⚠️ Network became unavailable")
                    await MainActor.run {
                        self.isConnected = false
                        self.errorMessage = "Network connection lost"
                    }
                }
            }
        }
        
        networkMonitor.start(queue: networkQueue)
        print("✅ Network monitoring started")
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


/// Member contribution tracking
struct MemberContribution {
    let userID: String
    var totalDistance: Double = 0.0
    var totalWorkouts: Int = 0
    var lastWorkoutDate: Date = Date.distantPast
    
    mutating func addWorkout(_ workout: Workout) {
        totalDistance += workout.distance
        totalWorkouts += 1
        lastWorkoutDate = max(lastWorkoutDate, workout.startTime)
    }
    
    mutating func addNostrWorkout(_ workoutEvent: NostrWorkoutEvent) {
        let workout = workoutEvent.workout
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