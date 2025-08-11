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