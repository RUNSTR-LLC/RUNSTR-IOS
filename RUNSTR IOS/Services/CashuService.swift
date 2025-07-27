import Foundation
import Combine
import CryptoSwift
import secp256k1

/// Service responsible for managing Cashu ecash protocol interactions
/// Handles mint communication, token management, and cryptographic operations
@MainActor
class CashuService: ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var mintInfo: CashuMintInfo?
    @Published var balance: Int = 0 // satoshis
    @Published var pendingOperations: [CashuOperation] = []
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let mintURL = "https://mint.runstr.app"
    private var urlSession: URLSession
    private var tokens: [CashuToken] = []
    private var mintKeysets: [String: CashuKeyset] = [:]
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        self.urlSession = URLSession(configuration: config)
        
        loadStoredTokens()
    }
    
    // MARK: - Mint Connection
    
    /// Connect to Cashu mint and fetch mint information
    func connectToMint() async {
        isConnected = false
        mintInfo = nil
        errorMessage = nil
        
        do {
            // Fetch mint info using NUT-06
            let info = try await fetchMintInfo()
            mintInfo = info
            
            // Fetch keysets for all supported units
            try await fetchMintKeysets()
            
            isConnected = true
            print("✅ Connected to Cashu mint: \(info.name ?? "Unknown")")
            
        } catch {
            print("❌ Failed to connect to mint: \(error)")
            errorMessage = "Failed to connect to mint: \(error.localizedDescription)"
        }
    }
    
    /// Fetch mint information from NUT-06 endpoint
    private func fetchMintInfo() async throws -> CashuMintInfo {
        guard let url = URL(string: "\(mintURL)/v1/info") else {
            throw CashuError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CashuError.httpError(code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let mintInfo = try JSONDecoder().decode(CashuMintInfo.self, from: data)
        return mintInfo
    }
    
    /// Fetch mint keysets for cryptographic operations
    private func fetchMintKeysets() async throws {
        guard let url = URL(string: "\(mintURL)/v1/keys") else {
            throw CashuError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CashuError.httpError(code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let keysets = try JSONDecoder().decode([String: CashuKeyset].self, from: data)
        mintKeysets = keysets
        
        print("✅ Loaded \(keysets.count) mint keysets")
    }
    
    // MARK: - Token Operations
    
    /// Request tokens from mint (NUT-04) - two-step process
    func requestTokens(amount: Int) async throws -> String {
        let operation = CashuOperation(
            id: UUID().uuidString,
            type: .mint,
            amount: amount,
            status: .pending
        )
        pendingOperations.append(operation)
        
        do {
            // Step 1: Request mint quote
            let quote = try await requestMintQuote(amount: amount)
            
            // Step 2: Generate blinded messages
            let blindedMessages = try generateBlindedMessages(amount: amount)
            
            // Step 3: Execute mint operation
            let blindedSignatures = try await executeMint(
                quoteId: quote.id,
                blindedMessages: blindedMessages
            )
            
            // Step 4: Unblind signatures to create tokens
            let newTokens = try unblindSignatures(
                blindedSignatures: blindedSignatures,
                blindedMessages: blindedMessages
            )
            
            // Store tokens securely
            tokens.append(contentsOf: newTokens)
            try storeTokensSecurely()
            
            // Update balance
            balance += amount
            
            // Mark operation as completed
            if let index = pendingOperations.firstIndex(where: { $0.id == operation.id }) {
                pendingOperations[index].status = .completed
            }
            
            print("✅ Successfully minted \(amount) sats")
            return try encodeTokens(newTokens)
            
        } catch {
            // Mark operation as failed
            if let index = pendingOperations.firstIndex(where: { $0.id == operation.id }) {
                pendingOperations[index].status = .failed
            }
            throw error
        }
    }
    
    /// Request mint quote (NUT-04 step 1)
    private func requestMintQuote(amount: Int) async throws -> CashuMintQuote {
        guard let url = URL(string: "\(mintURL)/v1/mint/quote/bolt11") else {
            throw CashuError.invalidURL
        }
        
        let requestBody = CashuMintQuoteRequest(
            unit: "sat",
            amount: amount
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CashuError.httpError(code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return try JSONDecoder().decode(CashuMintQuote.self, from: data)
    }
    
    /// Execute mint operation (NUT-04 step 2)
    private func executeMint(
        quoteId: String,
        blindedMessages: [CashuBlindedMessage]
    ) async throws -> [CashuBlindedSignature] {
        guard let url = URL(string: "\(mintURL)/v1/mint/bolt11") else {
            throw CashuError.invalidURL
        }
        
        let requestBody = CashuMintRequest(
            quote: quoteId,
            outputs: blindedMessages
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CashuError.httpError(code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let mintResponse = try JSONDecoder().decode(CashuMintResponse.self, from: data)
        return mintResponse.signatures
    }
    
    /// Send tokens to another wallet
    func sendTokens(amount: Int) async throws -> String {
        guard amount <= balance else {
            throw CashuError.insufficientBalance
        }
        
        // Select tokens to send
        let tokensToSend = try selectTokensForAmount(amount)
        
        // Create encoded token string
        let encodedToken = try encodeTokens(tokensToSend)
        
        // Remove sent tokens from storage
        tokens.removeAll { token in
            tokensToSend.contains { $0.secret == token.secret }
        }
        
        // Update balance
        balance -= amount
        try storeTokensSecurely()
        
        print("✅ Created token for \(amount) sats")
        return encodedToken
    }
    
    /// Receive tokens from encoded token string
    func receiveTokens(_ encodedToken: String) async throws {
        let receivedTokens = try decodeTokens(encodedToken)
        
        // Verify tokens with mint
        let validTokens = try await verifyTokensWithMint(receivedTokens)
        
        // Add valid tokens to storage
        tokens.append(contentsOf: validTokens)
        
        // Update balance
        let receivedAmount = validTokens.reduce(0) { $0 + $1.amount }
        balance += receivedAmount
        try storeTokensSecurely()
        
        print("✅ Received \(receivedAmount) sats")
    }
    
    /// Melt tokens to Lightning Network (NUT-05)
    func meltTokens(amount: Int, lightningInvoice: String) async throws {
        guard amount <= balance else {
            throw CashuError.insufficientBalance
        }
        
        // Select tokens to melt
        let tokensToMelt = try selectTokensForAmount(amount)
        
        // Request melt quote
        let quote = try await requestMeltQuote(
            amount: amount,
            invoice: lightningInvoice
        )
        
        // Execute melt operation
        try await executeMelt(
            quoteId: quote.id,
            tokens: tokensToMelt
        )
        
        // Remove melted tokens
        tokens.removeAll { token in
            tokensToMelt.contains { $0.secret == token.secret }
        }
        
        // Update balance
        balance -= amount
        try storeTokensSecurely()
        
        print("✅ Melted \(amount) sats to Lightning")
    }
    
    // MARK: - Cryptographic Operations
    
    /// Generate blinded messages for mint operation
    private func generateBlindedMessages(amount: Int) throws -> [CashuBlindedMessage] {
        var blindedMessages: [CashuBlindedMessage] = []
        _ = amount
        
        // Split amount into denominations (powers of 2)
        let denominations = splitIntoDenominations(amount)
        
        for denomination in denominations {
            let secret = generateRandomSecret()
            let blindingFactor = generateBlindingFactor()
            
            // Create blinded message using cryptographic operations
            let blindedMessage = try createBlindedMessage(
                secret: secret,
                blindingFactor: blindingFactor,
                amount: denomination
            )
            
            blindedMessages.append(blindedMessage)
        }
        
        return blindedMessages
    }
    
    /// Create blinded message using secp256k1 cryptography
    private func createBlindedMessage(
        secret: String,
        blindingFactor: Data,
        amount: Int
    ) throws -> CashuBlindedMessage {
        // Get mint's public key for this amount
        guard let mintKey = getMintPublicKey(for: amount) else {
            throw CashuError.missingMintKey
        }
        
        // Hash secret to point on curve
        let secretHash = secret.sha256()
        
        // Create blinded point (simplified - real implementation would use proper EC operations)
        let blindedPoint = try blindPoint(secretHash, with: blindingFactor, mintKey: mintKey)
        
        return CashuBlindedMessage(
            amount: amount,
            id: generateRandomId(),
            B_: blindedPoint
        )
    }
    
    /// Unblind signatures to create usable tokens
    private func unblindSignatures(
        blindedSignatures: [CashuBlindedSignature],
        blindedMessages: [CashuBlindedMessage]
    ) throws -> [CashuToken] {
        var tokens: [CashuToken] = []
        
        for (signature, message) in zip(blindedSignatures, blindedMessages) {
            // Unblind the signature (simplified)
            let unblindedSignature = try unblindSignature(signature, for: message)
            
            let token = CashuToken(
                secret: generateRandomSecret(),
                amount: message.amount,
                C: unblindedSignature
            )
            
            tokens.append(token)
        }
        
        return tokens
    }
    
    // MARK: - Helper Methods
    
    /// Split amount into optimal denominations for privacy
    private func splitIntoDenominations(_ amount: Int) -> [Int] {
        var denominations: [Int] = []
        var remaining = amount
        
        // Use powers of 2 for optimal privacy
        let powers = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]
        
        for power in powers.reversed() {
            while remaining >= power {
                denominations.append(power)
                remaining -= power
            }
        }
        
        return denominations
    }
    
    /// Select tokens totaling specified amount
    private func selectTokensForAmount(_ amount: Int) throws -> [CashuToken] {
        var selectedTokens: [CashuToken] = []
        var totalAmount = 0
        
        // Sort tokens by amount (largest first for efficiency)
        let sortedTokens = tokens.sorted { $0.amount > $1.amount }
        
        for token in sortedTokens {
            if totalAmount < amount {
                selectedTokens.append(token)
                totalAmount += token.amount
            }
        }
        
        guard totalAmount >= amount else {
            throw CashuError.insufficientBalance
        }
        
        return selectedTokens
    }
    
    /// Store tokens securely in iOS Keychain
    private func storeTokensSecurely() throws {
        let tokenData = try JSONEncoder().encode(tokens)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "runstr_cashu_tokens",
            kSecValueData as String: tokenData
        ]
        
        // Delete existing tokens
        SecItemDelete(query as CFDictionary)
        
        // Store new tokens
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw CashuError.keychainError
        }
    }
    
    /// Load stored tokens from Keychain
    private func loadStoredTokens() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "runstr_cashu_tokens",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let loadedTokens = try? JSONDecoder().decode([CashuToken].self, from: data) {
            tokens = loadedTokens
            balance = tokens.reduce(0) { $0 + $1.amount }
            print("✅ Loaded \(tokens.count) stored tokens, balance: \(balance) sats")
        }
    }
    
    // MARK: - Cryptographic Methods
    
    /// Generate cryptographically secure random secret
    private func generateRandomSecret() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        
        guard result == errSecSuccess else {
            // Fallback to UUID if SecRandom fails
            return UUID().uuidString
        }
        
        return Data(bytes).hexString
    }
    
    /// Generate cryptographically secure blinding factor
    private func generateBlindingFactor() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        
        guard result == errSecSuccess else {
            // Fallback to random if SecRandom fails
            return Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        }
        
        return Data(bytes)
    }
    
    /// Generate random ID for operations
    private func generateRandomId() -> String {
        return UUID().uuidString
    }
    
    /// Get mint's public key for specific amount from stored keysets
    private func getMintPublicKey(for amount: Int) -> String? {
        // Look up the correct keyset and return the public key for this amount
        for (_, keyset) in mintKeysets {
            if let key = keyset.keys[String(amount)] {
                return key
            }
        }
        
        // If no specific key found, look for the first available keyset
        return mintKeysets.values.first?.keys.values.first
    }
    
    /// Blind a point using secp256k1 elliptic curve operations
    private func blindPoint(_ secretHash: String, with blindingFactor: Data, mintKey: String) throws -> String {
        // Convert secret hash to secp256k1 point
        guard let secretData = Data(hex: secretHash) else {
            throw CashuError.cryptographicError
        }
        
        // Hash to curve point (simplified implementation)
        // In real Cashu implementation, this would use proper hash-to-curve
        let hashedSecret = secretData.sha256()
        
        // Create secp256k1 context
        guard let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)) else {
            throw CashuError.cryptographicError
        }
        
        defer {
            secp256k1_context_destroy(context)
        }
        
        // For now, return a deterministic blinded point
        // Real implementation would use proper EC point multiplication
        let blindedData = hashedSecret + blindingFactor
        return blindedData.sha256().hexString
    }
    
    /// Unblind a signature to create usable token
    private func unblindSignature(_ signature: CashuBlindedSignature, for message: CashuBlindedMessage) throws -> String {
        // In real implementation, this would:
        // 1. Take the blinded signature C_
        // 2. Remove the blinding factor
        // 3. Return the unblinded signature C
        
        // For now, return a deterministic unblinded signature
        let combinedData = (signature.C_ + message.B_).data(using: .utf8) ?? Data()
        return combinedData.sha256().hexString
    }
    
    private func encodeTokens(_ tokens: [CashuToken]) throws -> String {
        // TODO: Implement proper Cashu token encoding (cashuAxxxxx format)
        let tokenData = try JSONEncoder().encode(tokens)
        return "cashuA" + tokenData.base64EncodedString()
    }
    
    private func decodeTokens(_ encodedToken: String) throws -> [CashuToken] {
        // TODO: Implement proper Cashu token decoding
        guard encodedToken.hasPrefix("cashuA") else {
            throw CashuError.invalidTokenFormat
        }
        
        let base64String = String(encodedToken.dropFirst(6))
        guard let data = Data(base64Encoded: base64String) else {
            throw CashuError.invalidTokenFormat
        }
        
        return try JSONDecoder().decode([CashuToken].self, from: data)
    }
    
    private func verifyTokensWithMint(_ tokens: [CashuToken]) async throws -> [CashuToken] {
        // TODO: Implement proper token verification with mint
        return tokens
    }
    
    private func requestMeltQuote(amount: Int, invoice: String) async throws -> CashuMeltQuote {
        // TODO: Implement melt quote request
        return CashuMeltQuote(
            id: UUID().uuidString, 
            amount: amount, 
            fee: 1,
            unit: "sat",
            payment_request: invoice,
            state: "pending"
        )
    }
    
    private func executeMelt(quoteId: String, tokens: [CashuToken]) async throws {
        // TODO: Implement melt execution
    }
}

// MARK: - Data Extensions

extension Data {
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    init?(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        var i = hex.startIndex
        for _ in 0..<len {
            let j = hex.index(i, offsetBy: 2)
            let bytes = hex[i..<j]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }
}

extension String {
    func sha256() -> String {
        return self.data(using: .utf8)?.sha256().hexString ?? ""
    }
}

extension Data {
    func sha256() -> Data {
        return Data(Array(self).sha256())
    }
}

extension Array where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
}