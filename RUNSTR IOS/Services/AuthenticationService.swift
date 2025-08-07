import Foundation
import AuthenticationServices
import Security
import NostrSDK

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
    
    func signInWithRunstr() {
        print("🚀 Starting RUNSTR Sign-In with local key storage")
        isLoading = true
        
        // Generate new Nostr keys for RUNSTR login
        let runstrKeys = NostrKeyPair.generate()
        print("✅ RUNSTR Nostr keys generated")
        
        // Save keys locally (not in Keychain)
        saveRunstrKeysLocally(runstrKeys)
        print("✅ RUNSTR keys saved locally")
        
        // Create user with RUNSTR login method
        let user = User(runstrNostrKeys: runstrKeys)
        print("✅ RUNSTR user object created")
        
        saveUserToKeychain(user)
        print("✅ RUNSTR user saved to keychain")
        
        DispatchQueue.main.async {
            print("✅ Setting RUNSTR authentication state")
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            print("✅ RUNSTR authentication complete - isAuthenticated: \(self.isAuthenticated)")
        }
    }
    
    func signInWithNsec(_ nsec: String) -> Bool {
        print("🚀 Starting RUNSTR Sign-In with existing nsec")
        isLoading = true
        
        // Validate nsec format
        guard nsec.hasPrefix("nsec1") && nsec.count > 10 else {
            print("❌ Invalid nsec format")
            isLoading = false
            return false
        }
        
        // Convert nsec to keypair using NostrSDK
        guard let keypair = Keypair(nsec: nsec) else {
            print("❌ Failed to create Keypair from nsec")
            isLoading = false
            return false
        }
        
        let runstrKeys = NostrKeyPair(
            privateKey: nsec,
            publicKey: keypair.publicKey.npub
        )
        
        print("✅ RUNSTR keys restored from nsec")
        
        // Save keys locally (not in Keychain)
        saveRunstrKeysLocally(runstrKeys)
        print("✅ Restored keys saved locally")
        
        // Create user with RUNSTR login method
        let user = User(runstrNostrKeys: runstrKeys)
        print("✅ RUNSTR user object created from restored keys")
        
        saveUserToKeychain(user)
        print("✅ RUNSTR user saved to keychain")
        
        DispatchQueue.main.async {
            print("✅ Setting RUNSTR authentication state with restored account")
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            print("✅ RUNSTR account restoration complete - isAuthenticated: \(self.isAuthenticated)")
        }
        
        return true
    }
    
    
    
    
    
    
    func signOut() {
        // Clear local storage for RUNSTR users
        if let user = currentUser, user.loginMethod == .runstr {
            clearRunstrKeysFromLocal()
        }
        
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
    
    // MARK: - Local Storage Methods (for RUNSTR login)
    
    private func saveRunstrKeysLocally(_ keyPair: NostrKeyPair) {
        let keyData: [String: String] = [
            "privateKey": keyPair.privateKey,
            "publicKey": keyPair.publicKey
        ]
        
        do {
            let data = try JSONEncoder().encode(keyData)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let keysURL = documentsPath.appendingPathComponent("runstr_keys.json")
            
            try data.write(to: keysURL)
            print("✅ RUNSTR keys saved to local storage: \(keysURL.path)")
        } catch {
            print("❌ Failed to save RUNSTR keys locally: \(error)")
        }
    }
    
    private func loadRunstrKeysFromLocal() -> NostrKeyPair? {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let keysURL = documentsPath.appendingPathComponent("runstr_keys.json")
            
            let data = try Data(contentsOf: keysURL)
            let keyData = try JSONDecoder().decode([String: String].self, from: data)
            
            guard let privateKey = keyData["privateKey"],
                  let publicKey = keyData["publicKey"] else {
                return nil
            }
            
            return NostrKeyPair(privateKey: privateKey, publicKey: publicKey)
        } catch {
            print("❌ Failed to load RUNSTR keys from local storage: \(error)")
            return nil
        }
    }
    
    func exportRunstrPrivateKey() -> String? {
        guard let user = currentUser, user.loginMethod == .runstr else {
            return nil
        }
        
        if let localKeys = loadRunstrKeysFromLocal() {
            return localKeys.privateKey
        } else {
            // Fallback to user's stored private key
            return user.runstrNostrPrivateKey
        }
    }
    
    private func clearRunstrKeysFromLocal() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let keysURL = documentsPath.appendingPathComponent("runstr_keys.json")
            
            if FileManager.default.fileExists(atPath: keysURL.path) {
                try FileManager.default.removeItem(at: keysURL)
                print("✅ RUNSTR keys cleared from local storage")
            }
        } catch {
            print("❌ Failed to clear RUNSTR keys from local storage: \(error)")
        }
    }
    
    // MARK: - Keychain Methods (for Apple login)
    
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