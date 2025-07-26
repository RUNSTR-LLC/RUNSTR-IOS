import Foundation
import Combine

// MARK: - Bitcoin Wallet Service
@MainActor
class BitcoinWalletService: ObservableObject {
    @Published var balance: Int = 0 // Balance in satoshis
    @Published var transactions: [BitcoinTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lightningInvoice: String?
    @Published var paymentStatus: PaymentStatus = .idle
    
    // Mock Zebedee credentials (replace in production)
    private let apiKey = "mock_zebedee_api_key"
    private let baseURL = "https://api.zebedee.io/v0"
    
    init() {
        loadMockData()
    }
    
    // MARK: - Public Methods
    
    func refreshBalance() async {
        isLoading = true
        errorMessage = nil
        
        // Mock API call delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock balance update (in production, call Zebedee API)
        let mockBalance = Int.random(in: 5000...50000)
        balance = mockBalance
        
        isLoading = false
    }
    
    func generateLightningInvoice(amount: Int, description: String) async -> String? {
        isLoading = true
        errorMessage = nil
        
        // Mock invoice generation
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        let mockInvoice = "lnbc\(amount)0n1p\(generateRandomString(50))payreq"
        lightningInvoice = mockInvoice
        
        isLoading = false
        return mockInvoice
    }
    
    func sendLightningPayment(invoice: String) async -> Bool {
        isLoading = true
        paymentStatus = .pending
        errorMessage = nil
        
        // Mock payment processing
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        let success = Bool.random() // 50% success rate for demo
        
        if success {
            paymentStatus = .completed
            // Deduct from balance
            let amount = extractAmountFromInvoice(invoice)
            balance = max(0, balance - amount)
            
            // Add transaction
            let transaction = BitcoinTransaction(
                id: UUID().uuidString,
                type: BitcoinTransactionType.sent,
                amount: amount,
                description: "Lightning payment",
                timestamp: Date(),
                status: BitcoinTransactionStatus.confirmed,
                txHash: generateRandomString(64)
            )
            transactions.insert(transaction, at: 0)
            
        } else {
            paymentStatus = .failed
            errorMessage = "Payment failed. Please try again."
        }
        
        isLoading = false
        return success
    }
    
    func sendToAddress(address: String, amount: Int) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        // Mock on-chain payment
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        
        let success = Bool.random()
        
        if success {
            // Deduct from balance (include mock fee)
            let totalAmount = amount + 1000 // 1000 sats fee
            balance = max(0, balance - totalAmount)
            
            // Add transaction
            let transaction = BitcoinTransaction(
                id: UUID().uuidString,
                type: BitcoinTransactionType.sent,
                amount: amount,
                description: "Bitcoin transfer",
                timestamp: Date(),
                status: BitcoinTransactionStatus.confirmed,
                txHash: generateRandomString(64)
            )
            transactions.insert(transaction, at: 0)
            
        } else {
            errorMessage = "On-chain payment failed. Please check the address and try again."
        }
        
        isLoading = false
        return success
    }
    
    func addFunds(amount: Int, method: FundingMethod) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        // Mock funding delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        let success = true // Always succeed in mock
        
        if success {
            balance += amount
            
            let transaction = BitcoinTransaction(
                id: UUID().uuidString,
                type: BitcoinTransactionType.received,
                amount: amount,
                description: "Wallet funding via \(method.displayName)",
                timestamp: Date(),
                status: BitcoinTransactionStatus.confirmed,
                txHash: generateRandomString(64)
            )
            transactions.insert(transaction, at: 0)
        }
        
        isLoading = false
        return success
    }
    
    func convertToFiat(sats: Int) -> Double {
        // Mock conversion rate: 1 BTC = $40,000, so 1 sat = $0.0004
        return Double(sats) * 0.0004
    }
    
    func formatSats(_ sats: Int) -> String {
        if sats >= 100_000_000 {
            let btc = Double(sats) / 100_000_000
            return String(format: "₿%.8f", btc)
        } else if sats >= 1000 {
            let k = Double(sats) / 1000
            return String(format: "%.1fk sats", k)
        } else {
            return "\(sats) sats"
        }
    }
    
    // MARK: - Private Methods
    
    private func loadMockData() {
        // Initialize with mock balance and transactions
        balance = 15420 // 15,420 sats
        
        transactions = [
            BitcoinTransaction(
                id: "1",
                type: BitcoinTransactionType.received,
                amount: 500,
                description: "Workout reward",
                timestamp: Date().addingTimeInterval(-3600),
                status: BitcoinTransactionStatus.confirmed,
                txHash: generateRandomString(64)
            ),
            BitcoinTransaction(
                id: "2",
                type: BitcoinTransactionType.sent,
                amount: 2000,
                description: "Coffee purchase",
                timestamp: Date().addingTimeInterval(-7200),
                status: BitcoinTransactionStatus.confirmed,
                txHash: generateRandomString(64)
            ),
            BitcoinTransaction(
                id: "3",
                type: BitcoinTransactionType.received,
                amount: 1000,
                description: "Team challenge reward",
                timestamp: Date().addingTimeInterval(-86400),
                status: BitcoinTransactionStatus.confirmed,
                txHash: generateRandomString(64)
            )
        ]
    }
    
    private func generateRandomString(_ length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    private func extractAmountFromInvoice(_ invoice: String) -> Int {
        // Mock amount extraction - in production, decode the actual invoice
        return Int.random(in: 100...5000)
    }
}

// MARK: - Models

struct BitcoinTransaction: Identifiable, Codable {
    let id: String
    let type: BitcoinTransactionType
    let amount: Int // in satoshis
    let description: String
    let timestamp: Date
    let status: BitcoinTransactionStatus
    let txHash: String
    
    var formattedAmount: String {
        let prefix = type == BitcoinTransactionType.received ? "+" : "-"
        return "\(prefix)\(amount) sats"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

enum BitcoinTransactionType: String, Codable {
    case sent = "sent"
    case received = "received"
    
    var systemImageName: String {
        switch self {
        case .sent: return "arrow.up.circle.fill"
        case .received: return "arrow.down.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .sent: return "red"
        case .received: return "green"
        }
    }
}

enum BitcoinTransactionStatus: String, Codable {
    case pending = "pending"
    case confirmed = "confirmed"
    case failed = "failed"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

enum PaymentStatus {
    case idle
    case pending
    case completed
    case failed
}

enum FundingMethod: String, CaseIterable {
    case lightning = "lightning"
    case onchain = "onchain"
    case creditCard = "credit_card"
    case bankTransfer = "bank_transfer"
    
    var displayName: String {
        switch self {
        case .lightning: return "Lightning Network"
        case .onchain: return "On-Chain Bitcoin"
        case .creditCard: return "Credit Card"
        case .bankTransfer: return "Bank Transfer"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .lightning: return "bolt.circle.fill"
        case .onchain: return "link.circle.fill"
        case .creditCard: return "creditcard.fill"
        case .bankTransfer: return "building.columns.fill"
        }
    }
}