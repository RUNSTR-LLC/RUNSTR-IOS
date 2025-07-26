import Foundation
import AuthenticationServices
import Security

class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    
    private let keychainService = "app.runstr.keychain"
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    func signInWithApple() {
        print("🚀 Using mock Apple Sign-In for development")
        isLoading = true
        
        // Mock authentication for development (remove when you have paid Apple Developer account)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.createMockUser()
        }
    }
    
    func signInWithNostr(npub: String) {
        print("🚀 Starting Nostr Sign-In with npub: \(npub)")
        isLoading = true
        
        // Mock implementation - in production, fetch user profile from Nostr relays
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.createNostrUser(mainNpub: npub)
        }
    }
    
    private func createMockUser() {
        print("✅ Creating mock user for development")
        
        let nostrKeys = NostrKeyPair.generate()
        print("✅ Nostr keys generated")
        
        saveNostrKeysToKeychain(nostrKeys)
        print("✅ Nostr keys saved to keychain")
        
        let user = User(
            appleUserID: "mock_user_\(UUID().uuidString.prefix(8))",
            email: "test@runstr.app",
            nostrKeys: nostrKeys
        )
        print("✅ Mock user object created")
        
        saveUserToKeychain(user)
        print("✅ Mock user saved to keychain")
        
        DispatchQueue.main.async {
            print("✅ Setting authentication state")
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            print("✅ Mock authentication complete - isAuthenticated: \(self.isAuthenticated)")
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