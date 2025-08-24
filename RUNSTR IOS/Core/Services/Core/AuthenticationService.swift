import Foundation
import AuthenticationServices
import Security
import NostrSDK

class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var isLoadingProfile = false
    
    private let keychainService = "app.runstr.keychain"
    
    override init() {
        super.init()
        // Don't check authentication status during init to avoid blocking app startup
        // It will be checked when the ContentView appears
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
    
    func signInWithNostrKey(_ nsec: String) async -> Bool {
        print("🚀 Starting Nostr Sign-In with key")
        
        do {
            // Create key pair from nsec using NostrSDK
            guard let nostrSDKKeypair = Keypair(nsec: nsec) else {
                throw NSError(domain: "NostrKeyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid nsec format"])
            }
            
            let keyPair = NostrKeyPair(
                privateKey: nostrSDKKeypair.privateKey.nsec,
                publicKey: nostrSDKKeypair.publicKey.npub
            )
            
            // Create user with Nostr authentication
            let user = User(
                appleUserID: nil,
                email: nil,
                nostrPublicKey: keyPair.publicKey,
                nostrPrivateKey: keyPair.privateKey
            )
            
            // Update user login method to Nostr
            var modifiedUser = user
            modifiedUser.loginMethod = .nostr
            
            // Save user to keychain
            saveUserToKeychain(modifiedUser)
            
            // Update published properties on main thread
            await MainActor.run { [modifiedUser] in
                currentUser = modifiedUser
                isAuthenticated = true
                isLoading = false
            }
            
            print("✅ Successfully signed in with Nostr")
            print("   📁 Public key: \(keyPair.publicKey)")
            print("   🔐 Private key: [REDACTED]")
            
            // Fetch profile data from Nostr relays in background
            Task {
                await fetchAndUpdateUserProfile()
            }
            
            return true
            
        } catch {
            print("❌ Failed to sign in with Nostr: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
            return false
        }
    }
    
    
    
    
    
    
    
    
    
    func importNostrKey(_ nsec: String) async -> Bool {
        do {
            // Create key pair from nsec using NostrSDK
            guard let nostrSDKKeypair = Keypair(nsec: nsec) else {
                throw NSError(domain: "NostrKeyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid nsec format"])
            }
            
            let keyPair = NostrKeyPair(
                privateKey: nostrSDKKeypair.privateKey.nsec,
                publicKey: nostrSDKKeypair.publicKey.npub
            )
            
            // Update current user with new keys
            guard var user = currentUser else { return false }
            user = User(
                appleUserID: user.appleUserID,
                email: user.email,
                nostrPublicKey: keyPair.publicKey,
                nostrPrivateKey: keyPair.privateKey
            )
            
            // Save updated user
            saveUserToKeychain(user)
            
            // Update published properties on main thread
            await MainActor.run { [user] in
                currentUser = user
            }
            
            print("✅ Successfully imported Nostr keys")
            print("   📁 Public key: \(keyPair.publicKey)")
            print("   🔐 Private key: [REDACTED]")
            
            // Fetch profile data from Nostr relays in background
            Task {
                await fetchAndUpdateUserProfile()
            }
            
            return true
            
        } catch {
            print("❌ Failed to import Nostr keys: \(error.localizedDescription)")
            return false
        }
    }
    
    func updateUserProfile(displayName: String, about: String, profilePicture: String?) async -> Bool {
        guard var user = currentUser else { return false }
        
        // Update user profile
        user.profile.updateProfile(
            displayName: displayName,
            about: about,
            profilePicture: profilePicture
        )
        
        // Save updated user to keychain
        saveUserToKeychain(user)
        
        // Update published properties on main thread
        let userToSet = user
        await MainActor.run {
            currentUser = userToSet
        }
        
        print("✅ User profile updated successfully")
        print("   📝 Display name: \(displayName)")
        print("   📋 About: \(about)")
        print("   🖼️ Profile picture: \(profilePicture ?? "none")")
        
        return true
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        clearUserDataFromKeychain()
    }
    
    func checkAuthenticationStatus() {
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
    
    // MARK: - Profile Fetching
    
    /// Fetch user profile from Nostr relays and update local profile
    private func fetchAndUpdateUserProfile() async {
        guard let user = currentUser, !user.nostrPublicKey.isEmpty else {
            print("⚠️ No user or public key available for profile fetch")
            return
        }
        
        await MainActor.run {
            isLoadingProfile = true
        }
        
        print("🔍 Fetching profile data from Nostr relays...")
        
        // Create a temporary NostrService instance for profile fetching
        let nostrService = await NostrService()
        await nostrService.connect()
        
        // Convert npub to hex format for API call
        let pubkeyForAPI = extractPubkeyHex(from: user.nostrPublicKey)
        
        // Clear any cached profile data to force fresh fetch
        await nostrService.clearProfileCache(for: pubkeyForAPI)
        
        if let nostrProfile = await nostrService.fetchProfile(pubkey: pubkeyForAPI) {
            print("✅ Profile data fetched successfully")
            
            // Update user profile with fetched data
            var updatedUser = user
            updatedUser.profile.updateFromNostrProfile(nostrProfile)
            
            // Save updated user
            saveUserToKeychain(updatedUser)
            
            // Update published properties on main thread  
            let finalUser = updatedUser
            await MainActor.run {
                currentUser = finalUser
                isLoadingProfile = false
                print("✅ User profile updated with Nostr data")
                print("   📝 Display name: \(nostrProfile.displayName ?? "none")")
                print("   🖼️ Picture: \(nostrProfile.picture ?? "none")")
            }
            
            // Start background updates
            await nostrService.startBackgroundProfileUpdates()
        } else {
            print("⚠️ Could not fetch profile data from Nostr relays")
            await MainActor.run {
                isLoadingProfile = false
            }
        }
        
        await nostrService.disconnect()
    }
    
    /// Extract hex pubkey from npub format
    private func extractPubkeyHex(from npub: String) -> String {
        // Try to convert npub to hex using NostrSDK
        if let publicKey = PublicKey(npub: npub) {
            return publicKey.hex
        }
        
        // If that fails, check if it's already in hex format
        if npub.count == 64 && npub.allSatisfy({ $0.isHexDigit }) {
            return npub
        }
        
        // Fallback: return the original (NostrSDK should handle various formats)
        print("⚠️ Could not convert pubkey format, using as-is: \(npub.prefix(20))...")
        return npub
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
        
        // Create user without Nostr keys to prevent startup delay
        // Nostr keys will be generated later when needed
        let user = User(
            appleUserID: appleIDCredential.user,
            email: appleIDCredential.email
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
    case userCreationFailed
    case localStorageError
    
    var errorDescription: String? {
        switch self {
        case .userCreationFailed:
            return "Failed to create user account"
        case .localStorageError:
            return "Failed to save user data locally"
        }
    }
}

// MARK: - Helper Extensions

extension Character {
    var isHexDigit: Bool {
        return self.isNumber || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}