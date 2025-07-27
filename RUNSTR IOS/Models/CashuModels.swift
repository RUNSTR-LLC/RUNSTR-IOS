import Foundation

// MARK: - Cashu Protocol Data Models

/// Mint information from NUT-06
struct CashuMintInfo: Codable {
    let name: String?
    let pubkey: String?
    let version: String?
    let description: String?
    let contact: [CashuContact]?
    let nuts: [String: CashuNutInfo]?
}

/// Contact information for mint
struct CashuContact: Codable {
    let method: String // "email", "twitter", "nostr"
    let info: String
}

/// NUT specification information
struct CashuNutInfo: Codable {
    let supported: Bool
    let methods: [CashuPaymentMethod]?
}

/// Payment method configuration
struct CashuPaymentMethod: Codable {
    let method: String // "bolt11"
    let unit: String // "sat"
    let min_amount: Int?
    let max_amount: Int?
}

/// Keyset for cryptographic operations
struct CashuKeyset: Codable {
    let id: String
    let unit: String
    let keys: [String: String] // amount -> public key
}

/// Token structure for sending/receiving
struct CashuToken: Codable, Identifiable {
    let id = UUID()
    let secret: String
    let amount: Int
    let C: String // Commitment/signature
    
    enum CodingKeys: String, CodingKey {
        case secret, amount, C
    }
}

/// Blinded message for mint operations
struct CashuBlindedMessage: Codable {
    let amount: Int
    let id: String
    let B_: String // Blinded point
}

/// Blinded signature from mint
struct CashuBlindedSignature: Codable {
    let amount: Int
    let id: String
    let C_: String // Blinded signature
}

/// Mint quote request
struct CashuMintQuoteRequest: Codable {
    let unit: String
    let amount: Int
}

/// Mint quote response
struct CashuMintQuote: Codable {
    let id: String
    let amount: Int
    let unit: String
    let payment_request: String? // Lightning invoice
    let state: String?
    let expiry: Int?
}

/// Mint request with blinded messages
struct CashuMintRequest: Codable {
    let quote: String
    let outputs: [CashuBlindedMessage]
}

/// Mint response with blinded signatures
struct CashuMintResponse: Codable {
    let signatures: [CashuBlindedSignature]
}

/// Melt quote for Lightning withdrawal
struct CashuMeltQuote: Codable {
    let id: String
    let amount: Int
    let fee: Int
    let unit: String?
    let payment_request: String?
    let state: String?
}

/// Operation tracking for pending transactions
struct CashuOperation: Identifiable {
    let id: String
    let type: CashuOperationType
    let amount: Int
    var status: CashuOperationStatus
    let timestamp: Date = Date()
}

enum CashuOperationType {
    case mint
    case melt
    case send
    case receive
}

enum CashuOperationStatus {
    case pending
    case completed
    case failed
}

/// Error types for Cashu operations
enum CashuError: Error, LocalizedError {
    case invalidURL
    case httpError(code: Int)
    case invalidTokenFormat
    case insufficientBalance
    case missingMintKey
    case keychainError
    case cryptographicError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid mint URL"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .invalidTokenFormat:
            return "Invalid token format"
        case .insufficientBalance:
            return "Insufficient balance"
        case .missingMintKey:
            return "Missing mint public key"
        case .keychainError:
            return "Keychain storage error"
        case .cryptographicError:
            return "Cryptographic operation failed"
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - Enhanced CashuWallet Integration

extension CashuWallet {
    /// Send tokens using CashuService
    mutating func sendTokens(amount: Int, cashuService: CashuService) async throws -> String {
        guard balance >= amount else {
            throw CashuError.insufficientBalance
        }
        
        let encodedToken = try await cashuService.sendTokens(amount: amount)
        
        // Record transaction
        let transaction = CashuTransaction(
            amount: -amount,
            type: .withdrawal,
            source: .withdrawal,
            destination: "Cashu Token"
        )
        
        transactions.append(transaction)
        balance -= amount
        
        return encodedToken
    }
    
    /// Receive tokens using CashuService
    mutating func receiveTokens(_ encodedToken: String, cashuService: CashuService) async throws {
        try await cashuService.receiveTokens(encodedToken)
        
        // Extract amount from token (simplified for now)
        let amount = try extractAmountFromToken(encodedToken)
        
        // Record transaction
        let transaction = CashuTransaction(
            amount: amount,
            type: .reward,
            source: .teamBonus // or appropriate source
        )
        
        transactions.append(transaction)
        balance += amount
    }
    
    /// Withdraw to Lightning Network
    mutating func withdrawToLightning(
        amount: Int,
        invoice: String,
        cashuService: CashuService
    ) async throws {
        guard balance >= amount else {
            throw CashuError.insufficientBalance
        }
        
        try await cashuService.meltTokens(amount: amount, lightningInvoice: invoice)
        
        // Record transaction
        let transaction = CashuTransaction(
            amount: -amount,
            type: .withdrawal,
            source: .withdrawal,
            destination: invoice
        )
        
        transactions.append(transaction)
        balance -= amount
    }
    
    /// Request tokens from mint (fund wallet)
    mutating func requestTokens(
        amount: Int,
        cashuService: CashuService
    ) async throws -> String {
        let encodedToken = try await cashuService.requestTokens(amount: amount)
        
        // Record pending transaction
        let transaction = CashuTransaction(
            amount: amount,
            type: .reward,
            source: .teamBonus // Temporary - will be updated based on funding source
        )
        
        transactions.append(transaction)
        balance += amount
        
        return encodedToken
    }
    
    // MARK: - Helper Methods
    
    private func extractAmountFromToken(_ encodedToken: String) throws -> Int {
        // TODO: Implement proper token parsing
        // For now, return a placeholder
        return 100
    }
}

// MARK: - Display Formatting

extension CashuToken {
    var displayAmount: String {
        return "\(amount) sats"
    }
    
    var shortSecret: String {
        return String(secret.prefix(8)) + "..."
    }
}

extension CashuMintInfo {
    var displayName: String {
        return name ?? "Unknown Mint"
    }
    
    var supportedUnits: [String] {
        return nuts?.compactMap { (key, value) in
            value.supported ? key : nil
        } ?? []
    }
}