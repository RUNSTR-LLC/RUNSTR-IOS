import Foundation
import Combine

/// Manages NIP-46 connection lifecycle and state coordination
/// Acts as a lightweight coordinator between UI and NIP46Client
@MainActor
class NIP46ConnectionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectionStatus: String = "Not connected"
    @Published var userPublicKey: String?
    @Published var isConnecting = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let nip46Client: NIP46Client
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        self.nip46Client = NIP46Client()
        setupBindings()
        
        // Check for existing connection on startup
        Task {
            await checkExistingConnection()
        }
    }
    
    // MARK: - Public Methods
    
    /// Initiate connection to nsec bunker
    func connect() async {
        isConnecting = true
        errorMessage = nil
        
        await nip46Client.connectToBunker()
        
        isConnecting = false
    }
    
    /// Disconnect from nsec bunker
    func disconnect() async {
        await nip46Client.disconnect()
    }
    
    /// Sign a workout event using the connected bunker
    func signWorkoutEvent(workout: Workout, privacyLevel: NostrPrivacyLevel = .public) async throws -> Event {
        guard isConnected else {
            throw NIP46Error.notConnected
        }
        
        return try await nip46Client.signWorkoutEvent(workout: workout, privacyLevel: privacyLevel)
    }
    
    /// Get connection info for display purposes
    func getConnectionInfo() -> (isConnected: Bool, publicKey: String?, status: String) {
        return (
            isConnected: isConnected,
            publicKey: userPublicKey,
            status: connectionStatus
        )
    }
    
    /// Check if we have a valid stored connection
    func checkExistingConnection() async {
        let hasValidConnection = await nip46Client.checkStoredConnection()
        
        if hasValidConnection {
            print("✅ Found valid existing NIP-46 connection")
        } else {
            print("ℹ️ No valid existing NIP-46 connection found")
        }
    }
    
    // MARK: - Private Methods
    
    /// Setup bindings to NIP46Client
    private func setupBindings() {
        // Bind connection state
        nip46Client.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleConnectionStateChange(state)
            }
            .store(in: &cancellables)
        
        // Bind error messages
        nip46Client.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)
        
        // Bind bunker public key
        nip46Client.$bunkerPublicKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pubkey in
                self?.userPublicKey = pubkey
            }
            .store(in: &cancellables)
    }
    
    /// Handle connection state changes
    private func handleConnectionStateChange(_ state: NIP46Client.ConnectionState) {
        switch state {
        case .disconnected:
            isConnected = false
            connectionStatus = "Not connected"
            userPublicKey = nil
            
        case .connecting:
            isConnected = false
            connectionStatus = "Connecting to nsec.app..."
            
        case .waitingForApproval:
            isConnected = false
            connectionStatus = "Waiting for approval in nsec.app"
            
        case .connected:
            isConnected = true
            connectionStatus = "Connected to nsec bunker"
            
        case .error(let message):
            isConnected = false
            connectionStatus = "Connection error"
            errorMessage = message
        }
    }
}

// MARK: - Extensions

extension NIP46ConnectionManager {
    /// Check if the connection manager is ready for signing
    var canSign: Bool {
        return isConnected && userPublicKey != nil
    }
    
    /// Get a user-friendly status message
    var displayStatus: String {
        if isConnecting {
            return "Connecting..."
        } else if isConnected {
            return "Connected via nsec bunker"
        } else if let error = errorMessage {
            return "Error: \(error)"
        } else {
            return "Not connected"
        }
    }
    
    /// Get status color for UI
    var statusColor: String {
        if isConnected {
            return "green"
        } else if isConnecting {
            return "orange"
        } else if errorMessage != nil {
            return "red"
        } else {
            return "gray"
        }
    }
}