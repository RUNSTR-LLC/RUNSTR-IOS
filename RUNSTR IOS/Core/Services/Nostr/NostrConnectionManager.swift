import Foundation
import NostrSDK
import Combine

/// Manages connections to Nostr relays
@MainActor
class NostrConnectionManager: ObservableObject, NostrConnectionManagerProtocol {
    
    // MARK: - Published Properties
    @Published private(set) var isConnected = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var internalRelayPool: RelayPool?
    private let defaultRelayUrls = [
        "wss://relay.damus.io",
        "wss://nos.lol", 
        "wss://relay.snort.social",
        "wss://relay.primal.net"
    ]
    
    // MARK: - Protocol Properties
    var relayPool: RelayPool? {
        return internalRelayPool
    }
    
    // MARK: - Initialization
    init(relayUrls: [String]? = nil) {
        let urls = relayUrls ?? defaultRelayUrls
        print("🌐 NostrConnectionManager initialized with \(urls.count) relays")
        setupRelayPool(with: urls)
    }
    
    // MARK: - Public Methods
    
    /// Connect to Nostr relays
    func connect() async {
        await ensureRelayPoolSetup()
        
        guard let relayPool = internalRelayPool else {
            await MainActor.run {
                errorMessage = "RelayPool not initialized"
                print("❌ Cannot connect: RelayPool not initialized")
            }
            return
        }
        
        relayPool.connect()
        
        await MainActor.run {
            isConnected = true
            errorMessage = nil
            print("✅ Connected to Nostr relays")
        }
    }
    
    /// Disconnect from relays
    func disconnect() async {
        internalRelayPool?.disconnect()
        
        await MainActor.run {
            isConnected = false
            print("✅ Disconnected from Nostr relays")
        }
    }
    
    /// Get connection status
    func getConnectionStatus() -> Bool {
        return isConnected
    }
    
    /// Reconnect to relays
    func reconnect() async {
        print("🔄 Reconnecting to Nostr relays...")
        await disconnect()
        
        // Brief delay before reconnecting
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await connect()
    }
    
    /// Update relay configuration
    func updateRelays(_ relayUrls: [String]) async {
        print("🔄 Updating relay configuration with \(relayUrls.count) relays")
        
        // Disconnect from current relays
        await disconnect()
        
        // Setup new relay pool
        setupRelayPool(with: relayUrls)
        
        // Reconnect if we were connected before
        await connect()
    }
    
    /// Get current relay URLs
    func getCurrentRelayUrls() -> [String] {
        guard let relayPool = internalRelayPool else {
            return defaultRelayUrls
        }
        
        // Extract URLs from relay pool
        // Note: NostrSDK 0.3.0 doesn't expose relay URLs directly,
        // so we'll return the configured URLs
        return defaultRelayUrls
    }
    
    /// Check if relay pool is ready for operations
    var isRelayPoolReady: Bool {
        return internalRelayPool != nil
    }
    
    // MARK: - Private Methods
    
    /// Setup relay pool with given URLs
    private func setupRelayPool(with relayUrls: [String]) {
        let validRelays = createRelaysFromUrls(relayUrls)
        
        guard !validRelays.isEmpty else {
            print("❌ No valid relays found, using default configuration")
            let defaultRelays = createRelaysFromUrls(defaultRelayUrls)
            internalRelayPool = RelayPool(relays: Set(defaultRelays))
            return
        }
        
        internalRelayPool = RelayPool(relays: Set(validRelays))
        print("✅ RelayPool configured with \(validRelays.count) relays")
        
        // Log relay URLs for debugging
        for (index, url) in relayUrls.enumerated() {
            print("   📡 Relay \(index + 1): \(url)")
        }
    }
    
    /// Create Relay objects from URL strings
    private func createRelaysFromUrls(_ urls: [String]) -> [Relay] {
        return urls.compactMap { urlString in
            guard let url = URL(string: urlString) else {
                print("⚠️ Invalid relay URL: \(urlString)")
                return nil
            }
            
            do {
                return try Relay(url: url)
            } catch {
                print("⚠️ Failed to create relay for \(urlString): \(error)")
                return nil
            }
        }
    }
    
    /// Ensure relay pool is setup (lazy initialization)
    private func ensureRelayPoolSetup() async {
        if internalRelayPool == nil {
            setupRelayPool(with: defaultRelayUrls)
        }
    }
    
    /// Validate relay URL format
    private func isValidRelayUrl(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        
        // Check if it's a WebSocket URL
        guard url.scheme == "wss" || url.scheme == "ws" else {
            return false
        }
        
        // Check if host exists
        guard url.host != nil else {
            return false
        }
        
        return true
    }
    
    /// Get relay health status (placeholder for future implementation)
    func getRelayHealthStatus() -> [String: Bool] {
        // This would return the health status of each relay
        // For now, return empty dictionary as NostrSDK 0.3.0 doesn't expose this
        return [:]
    }
}