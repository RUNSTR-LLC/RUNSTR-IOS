import Foundation
import AuthenticationServices
import Security

class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var nip46ConnectionManager: NIP46ConnectionManager?
    
    private let keychainService = "app.runstr.keychain"
    
    // Reference to NostrService for connection setup
    weak var nostrService: NostrService?
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    /// Configure NostrService reference for NIP-46 integration
    func configureNostrService(_ service: NostrService) {
        nostrService = service
    }
    
    func signInWithApple() {
        print("🚀 Starting production Apple Sign-In")
        isLoading = true
        
        // Use real Apple Sign-In flow
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func signInWithNsecBunker() async {
        print("🚀 Starting nsec bunker sign-in")
        isLoading = true
        
        do {
            // Initialize NIP-46 connection manager on MainActor
            let connectionManager = await NIP46ConnectionManager()
            await MainActor.run {
                nip46ConnectionManager = connectionManager
            }
            
            // Attempt connection to nsec bunker
            await connectionManager.connect()
            
            // Check if connection was successful
            if await connectionManager.isConnected {
                await createNsecBunkerUser(connectionManager: connectionManager)
            } else {
                throw AuthenticationError.nsecBunkerConnectionFailed
            }
            
        } catch {
            print("❌ nsec bunker sign-in failed: \(error)")
            await MainActor.run {
                self.isLoading = false
                // Handle error appropriately in UI
            }
        }
    }
    
    func signInWithNostr(npub: String) {
        print("🚀 Starting legacy Nostr Sign-In with npub: \(npub)")
        isLoading = true
        
        // Legacy implementation for manual npub input
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.createNostrUser(mainNpub: npub)
        }
    }
    
    
    private func createNsecBunkerUser(connectionManager: NIP46ConnectionManager) async {
        print("✅ Creating nsec bunker user")
        
        let connectionInfo = await connectionManager.getConnectionInfo()
        
        guard let bunkerPublicKey = connectionInfo.publicKey else {
            print("❌ No bunker public key available")
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        // Create user with nsec bunker connection
        let user = User(
            bunkerPublicKey: bunkerPublicKey,
            authenticationMethod: .nsecBunker,
            connectionManager: connectionManager
        )
        
        print("✅ nsec bunker user object created")
        
        saveUserToKeychain(user)
        print("✅ nsec bunker user saved to keychain")
        
        // Configure NostrService with NIP-46 connection manager
        if let nostrService = nostrService {
            await nostrService.setNIP46ConnectionManager(connectionManager)
        }
        
        await MainActor.run {
            print("✅ Setting nsec bunker authentication state")
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            print("✅ nsec bunker authentication complete - isAuthenticated: \(self.isAuthenticated)")
        }
    }
    
    private func createNostrUser(mainNpub: String) {
        print("✅ Creating Nostr user for npub: \(mainNpub)")
        
        // Generate RUNSTR-specific keys for workout storage
        let runstrNostrKeys = NostrKeyPair.generate()
        print("✅ RUNSTR Nostr keys generated")
        
        saveNostrKeysToKeychain(runstrNostrKeys)
        print("✅ RUNSTR keys saved to keychain")
        
        // Mock Nostr profile data - in production, fetch from relays
        let mockProfile = NostrProfile(
            displayName: "Nostr Runner",
            about: "Bitcoin fitness enthusiast",
            picture: nil,
            banner: nil,
            nip05: nil
        )
        
        let user = User(
            mainNostrPublicKey: mainNpub,
            runstrNostrKeys: runstrNostrKeys,
            profile: mockProfile
        )
        print("✅ Nostr user object created")
        
        saveUserToKeychain(user)
        print("✅ Nostr user saved to keychain")
        
        DispatchQueue.main.async {
            print("✅ Setting Nostr authentication state")
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            print("✅ Nostr authentication complete - isAuthenticated: \(self.isAuthenticated)")
        }
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        clearUserDataFromKeychain()
    }
    
    private func checkAuthenticationStatus() {
        if let userData = getUserDataFromKeychain() {
            currentUser = userData
            isAuthenticated = true
        }
    }
    
    private func saveUserToKeychain(_ user: User) {
        guard let userData = try? JSONEncoder().encode(user) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "currentUser",
            kSecValueData as String: userData
        ]
        
        SecItemDelete(query as CFDictionary) // Remove existing
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getUserDataFromKeychain() -> User? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "currentUser",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        
        return user
    }
    
    private func clearUserDataFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "currentUser"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    private func saveNostrKeysToKeychain(_ keyPair: NostrKeyPair) {
        let privateKeyData = keyPair.privateKey.data(using: .utf8)!
        let publicKeyData = keyPair.publicKey.data(using: .utf8)!
        
        let privateKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "nostrPrivateKey",
            kSecValueData as String: privateKeyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let publicKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "nostrPublicKey",
            kSecValueData as String: publicKeyData
        ]
        
        SecItemDelete(privateKeyQuery as CFDictionary)
        SecItemDelete(publicKeyQuery as CFDictionary)
        
        SecItemAdd(privateKeyQuery as CFDictionary, nil)
        SecItemAdd(publicKeyQuery as CFDictionary, nil)
    }
}

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign In")
        }
        return window
    }
}

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("✅ Apple Sign-In authorization received")
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ Failed to get Apple ID credential")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        print("✅ Apple ID credential obtained for user: \(appleIDCredential.user)")
        
        let nostrKeys = NostrKeyPair.generate()
        print("✅ Nostr keys generated")
        
        saveNostrKeysToKeychain(nostrKeys)
        print("✅ Nostr keys saved to keychain")
        
        let user = User(
            appleUserID: appleIDCredential.user,
            email: appleIDCredential.email,
            nostrKeys: nostrKeys
        )
        print("✅ User object created")
        
        saveUserToKeychain(user)
        print("✅ User saved to keychain")
        
        DispatchQueue.main.async {
            print("✅ Setting authentication state")
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            print("✅ Authentication complete - isAuthenticated: \(self.isAuthenticated)")
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
}

// MARK: - Authentication Errors

enum AuthenticationError: LocalizedError {
    case nsecBunkerConnectionFailed
    case invalidBunkerResponse
    case userCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .nsecBunkerConnectionFailed:
            return "Failed to connect to nsec bunker"
        case .invalidBunkerResponse:
            return "Invalid response from nsec bunker"
        case .userCreationFailed:
            return "Failed to create user account"
        }
    }
}