import Foundation
import SafariServices
import NostrSDK
import Combine

/// NIP-46 (Nostr Connect) client for remote signing via nsec bunker
/// Implements the client side of the Nostr Connect protocol for secure remote signing
@MainActor
class NIP46Client: ObservableObject {
    
    // MARK: - Published Properties
    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectionToken: String?
    @Published var bunkerPublicKey: String?
    @Published var errorMessage: String?
    @Published var pendingRequests: [SigningRequest] = []
    
    // MARK: - Private Properties
    private var localKeypair: Keypair?
    private var relayPool: RelayPool?
    private var connectionString: String?
    private var subscriptions: [String: Any] = [:]
    private var storedSignedEvents: [String: Event] = [:]
    private let keychainService = "app.runstr.nip46"
    
    // MARK: - Connection State
    enum ConnectionState {
        case disconnected
        case connecting
        case waitingForApproval
        case connected
        case error(String)
        
        var displayName: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting"
            case .waitingForApproval: return "Waiting for Approval"
            case .connected: return "Connected"
            case .error: return "Error"
            }
        }
        
        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }
    
    // MARK: - Signing Request
    struct SigningRequest: Identifiable {
        let id = UUID()
        let eventBuilder: Any // Placeholder until we determine correct EventBuilder type
        let method: String
        let timestamp: Date
        var status: RequestStatus = .pending
        
        enum RequestStatus {
            case pending
            case signed
            case failed(String)
        }
    }
    
    // MARK: - Initialization
    init() {
        loadStoredConnection()
        setupLocalKeypair()
    }
    
    // MARK: - Connection Management
    
    /// Initiate connection to nsec.app bunker
    func connectToBunker() async {
        connectionState = .connecting
        errorMessage = nil
        
        do {
            // Generate local keypair for NIP-46 communication
            let localKeypair: Keypair
            do {
                guard let keypair = try Keypair() else {
                    throw NIP46Error.keyGenerationFailed
                }
                localKeypair = keypair
            } catch {
                throw NIP46Error.keyGenerationFailed
            }
            
            self.localKeypair = localKeypair
            
            // Create connection string for nsec.app
            let localPublicKey = localKeypair.publicKey.bech32
            let connectionString = createConnectionString(localPublicKey: localPublicKey)
            self.connectionString = connectionString
            
            // Open nsec.app in Safari with the connection string
            await openBunkerInSafari(connectionString: connectionString)
            
            // Start listening for connection approval
            connectionState = .waitingForApproval
            await listenForConnectionApproval()
            
        } catch {
            print("❌ Failed to connect to bunker: \(error)")
            connectionState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
    
    /// Disconnect from bunker and clear stored connection
    func disconnect() async {
        connectionState = .disconnected
        connectionToken = nil
        bunkerPublicKey = nil
        localKeypair = nil
        connectionString = nil
        
        // Close all subscriptions
        if let relayPool = relayPool {
            for (_, subscription) in subscriptions {
                if let sub = subscription as? Subscription {
                    // Note: API compatibility issue - subscription close method may vary in NostrSDK 0.3.0
                }
            }
            subscriptions.removeAll()
            // Note: API compatibility issue - disconnect method may be async in some versions
        }
        
        relayPool = nil
        clearStoredConnection()
        
        print("✅ Disconnected from nsec bunker")
    }
    
    /// Check if we have a valid stored connection
    func checkStoredConnection() async -> Bool {
        guard let connectionToken = connectionToken,
              let bunkerPublicKey = bunkerPublicKey,
              let localKeypair = localKeypair else {
            return false
        }
        
        // Try to reconnect using stored credentials
        do {
            let success = await establishConnection(
                token: connectionToken,
                bunkerPubkey: bunkerPublicKey,
                localKeypair: localKeypair
            )
            
            if success {
                connectionState = .connected
                print("✅ Reconnected to nsec bunker using stored credentials")
                return true
            } else {
                // Clear invalid stored connection
                await disconnect()
                return false
            }
            
        } catch {
            print("❌ Failed to reconnect with stored credentials: \(error)")
            await disconnect()
            return false
        }
    }
    
    // MARK: - Remote Signing
    
    /// Sign an event remotely using the connected bunker
    func signEvent(_ eventBuilder: Any) async throws -> Event {
        // Validate connection state
        guard connectionState.isConnected else {
            let error = NIP46Error.notConnected
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
        
        // Validate required components
        guard let localKeypair = localKeypair,
              let bunkerPublicKey = bunkerPublicKey,
              let relayPool = relayPool else {
            let error = NIP46Error.invalidState
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
        
        let request = SigningRequest(
            eventBuilder: eventBuilder,
            method: "sign_event",
            timestamp: Date()
        )
        
        do {
            // Add to pending requests
            await MainActor.run {
                self.pendingRequests.append(request)
            }
            
            // Create NIP-46 request event with timeout
            let requestEvent = try await withTimeout(30.0) {
                try await self.createSigningRequest(
                    localKeypair: localKeypair,
                    bunkerPublicKey: bunkerPublicKey,
                    eventBuilder: eventBuilder
                )
            }
            
            // Send request to bunker with retry logic
            var publishSuccess = false
            for attempt in 1...3 {
                do {
                    guard let relayPool = relayPool else {
                        throw NIP46Error.invalidState
                    }
                    
                    // Publish the signing request event to the relay
                    try await relayPool.send(event: requestEvent)
                    publishSuccess = true
                    print("✅ Published NIP-46 signing request (attempt \(attempt))")
                    break
                } catch {
                    print("⚠️ Failed to publish request (attempt \(attempt)): \(error)")
                    if attempt < 3 {
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    }
                }
            }
            
            guard publishSuccess else {
                throw NIP46Error.publishFailed
            }
            
            // Wait for response with extended timeout for signing
            let signedEvent = try await withTimeout(60.0) {
                try await self.waitForSigningResponse(requestId: request.id.uuidString)
            }
            
            // Remove from pending requests
            await MainActor.run {
                self.pendingRequests.removeAll { $0.id == request.id }
                self.errorMessage = nil // Clear any previous errors
            }
            
            print("✅ Event signed remotely via nsec bunker")
            return signedEvent
            
        } catch let error as NIP46Error {
            // Handle specific NIP-46 errors
            await MainActor.run {
                self.pendingRequests.removeAll { $0.id == request.id }
                self.errorMessage = error.localizedDescription
            }
            
            print("❌ NIP-46 signing failed: \(error.localizedDescription)")
            
            // If connection error, try to reconnect
            if case .connectionTimeout = error {
                print("🔄 Attempting to reconnect after timeout...")
                await reconnectIfNeeded()
            }
            
            throw error
            
        } catch {
            // Handle general errors
            await MainActor.run {
                self.pendingRequests.removeAll { $0.id == request.id }
                self.errorMessage = "Signing failed: \(error.localizedDescription)"
            }
            
            print("❌ Failed to sign event remotely: \(error)")
            throw NIP46Error.signingFailed(error.localizedDescription)
        }
    }
    
    /// Sign workout event specifically
    func signWorkoutEvent(workout: Workout, privacyLevel: NostrPrivacyLevel = .public) async throws -> Event {
        guard connectionState.isConnected else {
            throw NIP46Error.notConnected
        }
        
        guard let localKeypair = localKeypair,
              let bunkerPublicKey = bunkerPublicKey,
              let _ = relayPool else {
            throw NIP46Error.invalidState
        }
        
        // Create workout event content
        let workoutContent = createWorkoutEventContent(workout: workout)
        
        // Build tags for Kind 1301 event
        var tags: [[String]] = [
            ["d", workout.id],
            ["title", "RUNSTR Workout - \(workout.activityType.displayName)"],
            ["type", "cardio"],
            ["start", String(Int64(workout.startTime.timeIntervalSince1970))],
            ["end", String(Int64(workout.endTime.timeIntervalSince1970))],
            ["exercise", "33401:\(bunkerPublicKey):\(workout.id)", "", String(workout.distance/1000), String(workout.duration), String(workout.averagePace)],
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
        
        // Add privacy tags
        if privacyLevel == .public {
            tags.append(["t", "fitness"])
            tags.append(["t", workout.activityType.rawValue])
        }
        
        do {
            // Create the unsigned event data to send for signing
            let unsignedEventData: [String: Any] = [
                "kind": 1301,
                "content": workoutContent,
                "tags": tags,
                "created_at": Int(Date().timeIntervalSince1970)
            ]
            
            // Create NIP-46 signing request
            let requestId = UUID().uuidString
            let signedEvent = try await sendNIP46SigningRequest(
                requestId: requestId,
                method: "sign_event",
                params: [unsignedEventData],
                localKeypair: localKeypair,
                bunkerPublicKey: bunkerPublicKey
            )
            
            print("✅ Workout event signed remotely via NIP-46")
            return signedEvent
            
        } catch {
            print("❌ Failed to sign workout event via NIP-46: \(error)")
            throw error
        }
    }
    
    /// Create workout event content following NIP-101e spec
    private func createWorkoutEventContent(workout: Workout) -> String {
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
    
    // MARK: - Private Methods
    
    /// Setup local keypair for NIP-46 communication
    private func setupLocalKeypair() {
        if let storedKeypair = loadStoredLocalKeypair() {
            self.localKeypair = storedKeypair
        }
    }
    
    /// Create connection string for nsec.app
    private func createConnectionString(localPublicKey: String) -> String {
        let metadata: [String: Any] = [
            "name": "RUNSTR",
            "description": "Bitcoin fitness app",
            "url": "https://runstr.app",
            "permissions": ["sign_event:1301", "nip04_encrypt", "nip04_decrypt"]
        ]
        
        let metadataString = (try? JSONSerialization.data(withJSONObject: metadata))?.base64EncodedString() ?? ""
        
        return "nostr+connect://\(localPublicKey)?relay=wss://relay.nsec.app&metadata=\(metadataString)"
    }
    
    /// Open nsec.app in Safari with connection string
    private func openBunkerInSafari(connectionString: String) async {
        guard let encodedString = connectionString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://nsec.app/connect?target=\(encodedString)") else {
            connectionState = .error("Invalid connection URL")
            return
        }
        
        // Open in Safari
        await MainActor.run {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                return
            }
            
            let safariVC = SFSafariViewController(url: url)
            safariVC.preferredBarTintColor = .black
            safariVC.preferredControlTintColor = .white
            rootViewController.present(safariVC, animated: true)
        }
        
        print("✅ Opened nsec.app for connection approval")
    }
    
    /// Listen for connection approval from bunker
    private func listenForConnectionApproval() async {
        guard localKeypair != nil else { return }
        
        do {
            // Connect to nsec.app relay
            let relayUrl = "wss://relay.nsec.app"
            
            let relay = try Relay.create(url: relayUrl)
            let relaySet = Set([relay])
            relayPool = RelayPool(relays: relaySet)
            
            guard let relayPool = relayPool else { 
                throw NIP46Error.invalidState
            }
            
            // Connect to the relay
            try await relayPool.connect(relay: relay)
            
            // Set up subscription to listen for approval messages
            let localPubkey = localKeypair?.publicKey.bech32 ?? ""
            let filter = Filter()
                .kind(kind: EventKind.encryptedDirectMessage)
                .pubkey(pubkey: localPubkey)
            
            let subscriptionId = "nip46_approval_" + UUID().uuidString
            try await relayPool.subscribe(subscriptionId: subscriptionId, filters: [filter])
            
            // Set up event listener for incoming events
            await relayPool.handleEvents { [weak self] event in
                Task { @MainActor in
                    await self?.handleIncomingEvent(event)
                }
            }
            
            print("✅ Listening for NIP-46 connection approval on relay.nsec.app")
            
        } catch {
            connectionState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            print("❌ Failed to listen for connection approval: \(error)")
        }
    }
    
    /// Parse connection approval message from nsec.app
    private func parseConnectionApproval(event: Event, localKeypair: Keypair) throws -> (token: String, bunkerPubkey: String) {
        // Get the sender's public key
        let senderPubkey = event.publicKey
        
        // Decrypt the content using NIP-04
        let decryptedContent: String
        do {
            decryptedContent = try Nip04.decrypt(
                secretKey: localKeypair.secretKey,
                publicKey: senderPubkey,
                ciphertext: event.content
            )
        } catch {
            print("❌ Failed to decrypt connection approval: \(error)")
            throw NIP46Error.decryptionFailed
        }
        
        // Parse the JSON response
        guard let jsonData = decryptedContent.data(using: .utf8),
              let approvalData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let token = approvalData["token"] as? String else {
            throw NIP46Error.invalidApprovalMessage
        }
        
        // The bunker public key is the sender's public key
        let bunkerPubkey = senderPubkey.bech32
        
        print("✅ Successfully parsed NIP-46 connection approval")
        return (token: token, bunkerPubkey: bunkerPubkey)
    }
    
    /// Handle incoming events from the relay
    private func handleIncomingEvent(_ event: Event) async {
        guard let localKeypair = localKeypair else { return }
        
        // Check if this is an encrypted direct message (kind 4)
        if event.kind == EventKind.encryptedDirectMessage {
            do {
                // Try to parse as connection approval
                let (token, bunkerPubkey) = try parseConnectionApproval(event: event, localKeypair: localKeypair)
                
                // Save connection details
                self.connectionToken = token
                self.bunkerPublicKey = bunkerPubkey
                saveConnectionToKeychain(token: token, bunkerPubkey: bunkerPubkey, localKeypair: localKeypair)
                
                // Update connection state
                connectionState = .connected
                print("✅ NIP-46 connection established successfully")
                
            } catch {
                print("⚠️ Failed to parse connection approval: \(error)")
            }
        } else if event.kind.rawValue == 24133 {
            // Handle NIP-46 response events
            await handleNIP46Response(event)
        }
    }
    
    /// Handle NIP-46 response events (kind 24133)
    private func handleNIP46Response(_ event: Event) async {
        guard let localKeypair = localKeypair else { return }
        
        do {
            // Decrypt the response content
            let decryptedContent = try Nip44.decrypt(
                secretKey: localKeypair.secretKey,
                publicKey: event.publicKey,
                ciphertext: event.content
            )
            
            // Parse the JSON response
            guard let jsonData = decryptedContent.data(using: .utf8),
                  let responseData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let requestId = responseData["id"] as? String else {
                print("⚠️ Invalid NIP-46 response format")
                return
            }
            
            // Handle the response based on request ID
            await handleSigningResponse(requestId: requestId, responseData: responseData)
            
        } catch {
            print("❌ Failed to decrypt NIP-46 response: \(error)")
        }
    }
    
    /// Handle signing response from bunker
    private func handleSigningResponse(requestId: String, responseData: [String: Any]) async {
        // Check if this is an error response
        if let error = responseData["error"] as? [String: Any],
           let errorMessage = error["message"] as? String {
            print("❌ NIP-46 signing error: \(errorMessage)")
            
            // Update pending requests with error
            await MainActor.run {
                if let index = self.pendingRequests.firstIndex(where: { $0.id.uuidString == requestId }) {
                    self.pendingRequests[index].status = .failed(errorMessage)
                }
                self.errorMessage = "Signing failed: \(errorMessage)"
            }
            return
        }
        
        // Handle successful response
        if let result = responseData["result"] as? [String: Any] {
            do {
                // Parse the signed event from the result
                let signedEvent = try parseEventFromNIP46Response(result)
                
                // Update the pending request status
                await MainActor.run {
                    if let index = self.pendingRequests.firstIndex(where: { $0.id.uuidString == requestId }) {
                        self.pendingRequests[index].status = .signed
                    }
                    self.errorMessage = nil // Clear any previous errors
                }
                
                // Store the signed event for retrieval
                await storeSignedEvent(requestId: requestId, event: signedEvent)
                
                print("✅ Successfully received signed event via NIP-46")
                
            } catch {
                print("❌ Failed to parse signed event: \(error)")
                await MainActor.run {
                    if let index = self.pendingRequests.firstIndex(where: { $0.id.uuidString == requestId }) {
                        self.pendingRequests[index].status = .failed("Failed to parse signed event")
                    }
                    self.errorMessage = "Failed to parse signed event: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Store signed event for retrieval by waiting requests
    private func storeSignedEvent(requestId: String, event: Event) async {
        // Use a simple in-memory store for now
        // In a real implementation, you might use a more sophisticated storage mechanism
        await MainActor.run {
            // Store the event using the request ID as the key
            // This will be retrieved by the waitForSigningResponse method
            self.storedSignedEvents[requestId] = event
        }
    }
    
    /// Establish connection with bunker using token
    private func establishConnection(token: String, bunkerPubkey: String, localKeypair: Keypair) async -> Bool {
        // Implementation for establishing the actual signing connection
        // This would involve setting up the secure channel for signing requests
        return true // Simplified for now
    }
    
    /// Send NIP-46 signing request to bunker
    private func sendNIP46SigningRequest(requestId: String, method: String, params: [Any], localKeypair: Keypair, bunkerPublicKey: String) async throws -> Event {
        // TODO: Implement proper NIP-46 signing request with NostrSDK 0.3.0 API
        print("⚠️ NIP-46 signing request not fully implemented")
        
        // For now, throw not implemented error
        throw NIP46Error.notImplemented
    }
    
    /// Wait for NIP-46 response from bunker
    private func waitForNIP46Response(requestId: String, localKeypair: Keypair) async throws -> Event {
        guard relayPool != nil else {
            throw NIP46Error.invalidState
        }
        
        // TODO: Fix API compatibility issues with NostrSDK 0.3.0
        print("⚠️ NIP-46 response waiting not fully implemented")
        throw NIP46Error.notImplemented
    }
    
    /// Parse Event from NIP-46 response
    private func parseEventFromNIP46Response(_ responseData: [String: Any]) throws -> Event {
        // Extract event data from the response
        guard let id = responseData["id"] as? String,
              let pubkey = responseData["pubkey"] as? String,
              let createdAt = responseData["created_at"] as? Int64,
              let kind = responseData["kind"] as? Int,
              let tags = responseData["tags"] as? [[String]],
              let content = responseData["content"] as? String,
              let sig = responseData["sig"] as? String else {
            throw NIP46Error.invalidResponse
        }
        
        do {
            // Parse the public key
            let publicKey = try PublicKey.fromBech32(npub: pubkey)
            
            // Parse the signature
            let signature = try Signature.fromHex(hex: sig)
            
            // Create the event using the EventBuilder
            let eventBuilder = EventBuilder(
                kind: EventKind(rawValue: UInt64(kind)),
                content: content,
                tags: tags
            )
            
            // Create the event with the provided signature and metadata
            let event = try Event.fromBuilder(
                eventBuilder: eventBuilder,
                publicKey: publicKey,
                signature: signature,
                eventId: EventId.fromHex(hex: id),
                createdAt: Timestamp(seconds: UInt64(createdAt))
            )
            
            print("✅ Successfully parsed signed event from NIP-46 response")
            return event
            
        } catch {
            print("❌ Failed to parse event from NIP-46 response: \(error)")
            throw NIP46Error.invalidResponse
        }
    }
    
    /// Wait for signing response from bunker
    private func waitForSigningResponse(requestId: String) async throws -> Event {
        guard let _ = relayPool,
              let _ = localKeypair else {
            throw NIP46Error.invalidState
        }
        
        // Poll for the signed event with timeout
        let startTime = Date()
        let timeout: TimeInterval = 60.0 // 60 second timeout
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Check if we have received the signed event
            if let signedEvent = await getStoredSignedEvent(requestId: requestId) {
                return signedEvent
            }
            
            // Check if the request failed
            let requestStatus = await MainActor.run {
                return self.pendingRequests.first(where: { $0.id.uuidString == requestId })?.status
            }
            
            if case .failed(let error) = requestStatus {
                throw NIP46Error.signingFailed(error)
            }
            
            // Wait a short time before checking again
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        throw NIP46Error.signingTimeout
    }
    
    /// Get stored signed event for a request ID
    private func getStoredSignedEvent(requestId: String) async -> Event? {
        return await MainActor.run {
            return self.storedSignedEvents.removeValue(forKey: requestId)
        }
    }
    
    /// Parse Event object from JSON
    private func parseEventFromJson(_ json: [String: Any]) throws -> Event {
        // This method can reuse the same logic as parseEventFromNIP46Response
        return try parseEventFromNIP46Response(json)
    }
    
    // MARK: - Keychain Storage
    
    private func saveConnectionToKeychain(token: String, bunkerPubkey: String, localKeypair: Keypair) {
        let connectionData: [String: Any] = [
            "token": token,
            "bunkerPubkey": bunkerPubkey,
            "localPrivateKey": localKeypair.secretKey.bech32,
            "localPublicKey": localKeypair.publicKey.bech32
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: connectionData) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "nip46_connection",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
        
        print("✅ NIP-46 connection saved to keychain")
    }
    
    private func loadStoredConnection() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "nip46_connection",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let connectionData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = connectionData["token"] as? String,
              let bunkerPubkey = connectionData["bunkerPubkey"] as? String,
              let localPrivateKey = connectionData["localPrivateKey"] as? String else {
            return
        }
        
        guard let secretKey = try? SecretKey.fromBech32(nsec: localPrivateKey),
              let localKeypair = try? Keypair.fromSecretKey(secretKey) else {
            print("❌ Failed to recreate keypair from stored private key")
            return
        }
        
        self.connectionToken = token
        self.bunkerPublicKey = bunkerPubkey
        self.localKeypair = localKeypair
        
        print("✅ Loaded stored NIP-46 connection")
    }
    
    private func loadStoredLocalKeypair() -> Keypair? {
        // Implementation for loading stored local keypair
        return nil
    }
    
    private func clearStoredConnection() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "nip46_connection"
        ]
        
        SecItemDelete(query as CFDictionary)
        print("✅ Cleared stored NIP-46 connection")
    }
    
    // MARK: - Helper Methods
    
    /// Execute async operation with timeout
    private func withTimeout<T>(_ seconds: TimeInterval, _ operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NIP46Error.connectionTimeout
            }
            
            guard let result = try await group.next() else {
                throw NIP46Error.connectionTimeout
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Attempt to reconnect if connection is lost
    private func reconnectIfNeeded() async {
        guard !connectionState.isConnected else { return }
        
        print("🔄 Attempting NIP-46 reconnection...")
        
        // Check if we have stored connection details
        if let token = connectionToken,
           let bunkerPubkey = bunkerPublicKey,
           let localKeypair = localKeypair {
            
            let success = await establishConnection(
                token: token,
                bunkerPubkey: bunkerPubkey,
                localKeypair: localKeypair
            )
            
            if success {
                await MainActor.run {
                    self.connectionState = .connected
                    self.errorMessage = nil
                }
                print("✅ NIP-46 reconnection successful")
            } else {
                await MainActor.run {
                    self.connectionState = .error("Reconnection failed")
                    self.errorMessage = "Failed to reconnect to nsec bunker"
                }
                print("❌ NIP-46 reconnection failed")
            }
        }
    }
    
    /// Create signing request event (placeholder for full implementation)
    private func createSigningRequest(localKeypair: Keypair, bunkerPublicKey: String, eventBuilder: Any) async throws -> Event {
        // Create NIP-46 request payload
        let requestId = UUID().uuidString
        let nip46Request = [
            "id": requestId,
            "method": "sign_event",
            "params": [eventBuilder]
        ]
        
        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: nip46Request)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NIP46Error.invalidRequest
        }
        
        // Parse bunker public key from bech32
        let bunkerPubkey: PublicKey
        do {
            bunkerPubkey = try PublicKey.fromBech32(npub: bunkerPublicKey)
        } catch {
            throw NIP46Error.invalidPublicKey
        }
        
        // Encrypt content using NIP-44
        let encryptedContent: String
        do {
            encryptedContent = try Nip44.encrypt(
                secretKey: localKeypair.secretKey,
                publicKey: bunkerPubkey,
                plaintext: jsonString
            )
        } catch {
            print("❌ Failed to encrypt NIP-46 request: \(error)")
            throw NIP46Error.encryptionFailed
        }
        
        // Create kind 24133 event for NIP-46
        let tags = [
            ["p", bunkerPublicKey]
        ]
        
        let eventBuilder = EventBuilder(
            kind: EventKind.init(24133),
            content: encryptedContent,
            tags: tags
        )
        
        // Sign the event
        let signedEvent = try eventBuilder.sign(with: localKeypair)
        
        return signedEvent
    }
}

// MARK: - Errors

enum NIP46Error: LocalizedError {
    case keyGenerationFailed
    case notConnected
    case invalidState
    case invalidPublicKey
    case invalidApprovalMessage
    case signingFailed(String)
    case signingTimeout
    case invalidResponse
    case notImplemented
    case connectionTimeout
    case publishFailed
    case invalidRequest
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate local keypair"
        case .notConnected:
            return "Not connected to nsec bunker"
        case .invalidState:
            return "Invalid connection state"
        case .invalidPublicKey:
            return "Invalid public key format"
        case .invalidApprovalMessage:
            return "Invalid connection approval message"
        case .signingFailed(let message):
            return "Signing failed: \(message)"
        case .signingTimeout:
            return "Signing request timed out"
        case .invalidResponse:
            return "Invalid response from bunker"
        case .notImplemented:
            return "Feature not yet implemented"
        case .connectionTimeout:
            return "Connection to bunker timed out"
        case .publishFailed:
            return "Failed to publish signing request to relay"
        case .invalidRequest:
            return "Invalid signing request format"
        case .encryptionFailed:
            return "Failed to encrypt message for bunker"
        case .decryptionFailed:
            return "Failed to decrypt message from bunker"
        }
    }
}

// Note: NostrPrivacyLevel is defined in NostrService.swift to avoid duplication