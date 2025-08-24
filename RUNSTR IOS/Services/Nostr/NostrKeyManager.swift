import Foundation
import NostrSDK
import Security

/// Manages Nostr cryptographic keys with secure storage
@MainActor
class NostrKeyManager: ObservableObject, NostrKeyManagerProtocol {
    
    // MARK: - Published Properties
    @Published private(set) var currentKeyPair: NostrKeyPair?
    
    // MARK: - Private Properties
    private var internalKeypair: Keypair?
    private let keychainService = "app.runstr.keychain"
    private let keychainAccount = "nostrPrivateKey"
    
    // MARK: - Protocol Properties
    var nostrSDKKeypair: Keypair? {
        return internalKeypair
    }
    
    // MARK: - Initialization
    init() {
        print("🔐 NostrKeyManager initialized")
        loadKeysOnInitialization()
    }
    
    // MARK: - Public Methods
    
    /// Generate new Nostr key pair using NostrSDK
    func generateKeyPair() -> NostrKeyPair? {
        guard let keypair = Keypair() else {
            print("❌ Failed to generate Nostr keypair")
            return nil
        }
        
        let nostrKeyPair = NostrKeyPair(
            privateKey: keypair.privateKey.nsec,
            publicKey: keypair.publicKey.npub
        )
        
        // Store internally for signing
        internalKeypair = keypair
        currentKeyPair = nostrKeyPair
        
        print("✅ Generated new Nostr keypair")
        print("   🔑 npub: \(nostrKeyPair.publicKey.prefix(20))...")
        
        return nostrKeyPair
    }
    
    /// Store key pair securely in iOS Keychain
    func storeKeyPair(_ keyPair: NostrKeyPair) throws {
        guard let keyData = try? JSONEncoder().encode(keyPair) else {
            print("❌ Failed to encode keypair for storage")
            throw NostrServiceError.keyStorageFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            print("❌ Failed to store Nostr keys in keychain: \(status)")
            throw NostrServiceError.keyStorageFailed
        }
        
        // Update current state
        currentKeyPair = keyPair
        
        // Create NostrSDK keypair for internal use
        internalKeypair = Keypair(nsec: keyPair.privateKey)
        
        print("✅ Nostr keys stored securely in keychain")
        print("   🔑 npub: \(keyPair.publicKey.prefix(20))...")
    }
    
    /// Load stored key pair from Keychain
    func loadStoredKeyPair() -> NostrKeyPair? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data,
              let keyPair = try? JSONDecoder().decode(NostrKeyPair.self, from: keyData) else {
            print("⚠️ No stored Nostr keys found in keychain")
            return nil
        }
        
        // Update current state
        currentKeyPair = keyPair
        
        // Create NostrSDK keypair for internal use
        internalKeypair = Keypair(nsec: keyPair.privateKey)
        
        print("✅ Loaded stored Nostr keys from keychain")
        print("   🔑 npub: \(keyPair.publicKey.prefix(20))...")
        
        return keyPair
    }
    
    /// Generate and store new keys if none exist
    func ensureKeysAvailable() throws -> NostrKeyPair {
        if let existingKeyPair = currentKeyPair {
            return existingKeyPair
        }
        
        // Try loading from keychain first
        if let loadedKeyPair = loadStoredKeyPair() {
            return loadedKeyPair
        }
        
        // Generate new keys if none exist
        guard let newKeyPair = generateKeyPair() else {
            throw NostrServiceError.keyGenerationFailed
        }
        
        // Store the new keys
        try storeKeyPair(newKeyPair)
        
        return newKeyPair
    }
    
    /// Delete stored keys from keychain
    func deleteStoredKeys() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            print("❌ Failed to delete keys from keychain: \(status)")
            throw NostrServiceError.keyStorageFailed
        }
        
        // Clear current state
        currentKeyPair = nil
        internalKeypair = nil
        
        print("✅ Deleted stored Nostr keys from keychain")
    }
    
    /// Check if keys are currently available
    var hasKeys: Bool {
        return currentKeyPair != nil && internalKeypair != nil
    }
    
    /// Get public key in hex format
    var publicKeyHex: String? {
        guard let keyPair = currentKeyPair,
              let publicKey = PublicKey(npub: keyPair.publicKey) else {
            return nil
        }
        return publicKey.hex
    }
    
    // MARK: - Private Methods
    
    /// Load keys during initialization
    private func loadKeysOnInitialization() {
        _ = loadStoredKeyPair()
    }
    
    /// Validate key format
    private func validateKeyPair(_ keyPair: NostrKeyPair) -> Bool {
        // Basic validation - check if keys start with expected prefixes
        guard keyPair.privateKey.hasPrefix("nsec"),
              keyPair.publicKey.hasPrefix("npub") else {
            print("❌ Invalid key format - keys must be in bech32 format")
            return false
        }
        
        // Try creating NostrSDK keypair to validate
        guard Keypair(nsec: keyPair.privateKey) != nil else {
            print("❌ Invalid private key - failed to create Keypair")
            return false
        }
        
        return true
    }
}