import SwiftUI

struct WalletView: View {
    @StateObject private var walletService = BitcoinWalletService()
    @State private var showingSendView = false
    @State private var showingReceiveView = false
    @State private var showingFundingOptions = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            ScrollView {
                VStack(spacing: 32) {
                    balanceSection
                    
                    actionButtonsSection
                    
                    transactionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .background(Color.black)
        .foregroundColor(.white)
        .sheet(isPresented: $showingSendView) {
            SendBitcoinView(walletService: walletService)
        }
        .sheet(isPresented: $showingReceiveView) {
            ReceiveBitcoinView(walletService: walletService)
        }
        .sheet(isPresented: $showingFundingOptions) {
            GiftCardStoreView(walletService: walletService)
        }
        .task {
            await walletService.refreshBalance()
        }
    }
    
    private var headerSection: some View {
        HStack {
            Text("Wallet")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(.white)
            
            Spacer()
            
            Button {
                Task {
                    await walletService.refreshBalance()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .medium))
            }
            .disabled(walletService.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .background(Color.black)
    }
    
    private var balanceSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Total Balance")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(walletService.formatSats(walletService.balance))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    if walletService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
                
                Text("≈ $\(String(format: "%.2f", walletService.convertToFiat(sats: walletService.balance)))")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            if let errorMessage = walletService.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            WalletActionButton(
                title: "Send",
                icon: "arrow.up.circle.fill",
                color: .red
            ) {
                showingSendView = true
            }
            
            WalletActionButton(
                title: "Receive",
                icon: "arrow.down.circle.fill",
                color: .green
            ) {
                showingReceiveView = true
            }
            
            WalletActionButton(
                title: "Spend",
                icon: "gift.circle.fill",
                color: .blue
            ) {
                showingFundingOptions = true
            }
        }
    }
    
    private var transactionsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Recent Transactions")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            if walletService.transactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bitcoinsign.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No transactions yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("Start earning Bitcoin by completing workouts!")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(walletService.transactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }
}

struct WalletActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct TransactionRow: View {
    let transaction: BitcoinTransaction
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: transaction.type.systemImageName)
                .foregroundColor(transaction.type == .received ? .green : .red)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(transaction.formattedDate)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.formattedAmount)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(transaction.type == .received ? .green : .red)
                
                Text(transaction.status.displayName)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.white.opacity(0.02))
        )
    }
}

struct SendBitcoinView: View {
    @ObservedObject var walletService: BitcoinWalletService
    @Environment(\.dismiss) private var dismiss
    @State private var recipient = ""
    @State private var amount = ""
    @State private var sendMethod: SendMethod = .lightning
    @State private var isProcessing = false
    
    enum SendMethod: String, CaseIterable {
        case lightning = "Lightning"
        case onchain = "On-Chain"
        
        var placeholder: String {
            switch self {
            case .lightning: return "lnbc1..."
            case .onchain: return "bc1q..."
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    Picker("Send Method", selection: $sendMethod) {
                        ForEach(SendMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sendMethod == .lightning ? "LIGHTNING INVOICE" : "BITCOIN ADDRESS")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField(sendMethod.placeholder, text: $recipient)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AMOUNT (SATS)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField("0", text: $amount)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .keyboardType(.numberPad)
                    }
                    
                    Button {
                        Task {
                            await sendPayment()
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isProcessing ? "Sending..." : "Send Payment")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(2)
                    }
                    .disabled(recipient.isEmpty || amount.isEmpty || isProcessing)
                    .opacity(recipient.isEmpty || amount.isEmpty || isProcessing ? 0.5 : 1.0)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Scan") {
                        // QR scanner would go here
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func sendPayment() async {
        guard let amountInt = Int(amount) else { return }
        
        isProcessing = true
        
        let success: Bool
        if sendMethod == .lightning {
            success = await walletService.sendLightningPayment(invoice: recipient)
        } else {
            success = await walletService.sendToAddress(address: recipient, amount: amountInt)
        }
        
        isProcessing = false
        
        if success {
            dismiss()
        }
    }
}

struct ReceiveBitcoinView: View {
    @ObservedObject var walletService: BitcoinWalletService
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var description = ""
    @State private var generatedInvoice = ""
    @State private var isGenerating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AMOUNT (SATS)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField("0", text: $amount)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .keyboardType(.numberPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DESCRIPTION (OPTIONAL)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField("Payment for...", text: $description)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    Button {
                        Task {
                            await generateInvoice()
                        }
                    } label: {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isGenerating ? "Generating..." : "Generate Invoice")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(2)
                    }
                    .disabled(amount.isEmpty || isGenerating)
                    .opacity(amount.isEmpty || isGenerating ? 0.5 : 1.0)
                }
                
                if !generatedInvoice.isEmpty {
                    VStack(spacing: 16) {
                        Text("Lightning Invoice")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(generatedInvoice)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.gray)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .lineLimit(nil)
                        
                        Button {
                            UIPasteboard.general.string = generatedInvoice
                        } label: {
                            Text("Copy Invoice")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func generateInvoice() async {
        guard let amountInt = Int(amount) else { return }
        
        isGenerating = true
        
        if let invoice = await walletService.generateLightningInvoice(
            amount: amountInt,
            description: description.isEmpty ? "Payment request" : description
        ) {
            generatedInvoice = invoice
        }
        
        isGenerating = false
    }
}

struct GiftCardStoreView: View {
    @ObservedObject var walletService: BitcoinWalletService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCard: GiftCard?
    @State private var isProcessing = false
    
    private let giftCards: [GiftCard] = [
        GiftCard(name: "Amazon", brand: "amazon", denominations: [1000, 2500, 5000, 10000], icon: "amazon"),
        GiftCard(name: "Apple", brand: "apple", denominations: [2500, 5000, 10000, 25000], icon: "apple.logo"),
        GiftCard(name: "Starbucks", brand: "starbucks", denominations: [1000, 2500, 5000], icon: "cup.and.saucer.fill"),
        GiftCard(name: "Target", brand: "target", denominations: [2500, 5000, 10000], icon: "target"),
        GiftCard(name: "Walmart", brand: "walmart", denominations: [2500, 5000, 10000, 25000], icon: "cart.fill"),
        GiftCard(name: "Netflix", brand: "netflix", denominations: [2500, 5000], icon: "tv.fill")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Text("Gift Card Store")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Spend your Bitcoin on gift cards")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // Gift Cards Grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                        ForEach(giftCards, id: \.brand) { card in
                            GiftCardCell(card: card) {
                                selectedCard = card
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .sheet(item: $selectedCard) { card in
                GiftCardPurchaseView(card: card, walletService: walletService)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct GiftCard: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
    let denominations: [Int] // in sats
    let icon: String
}

struct GiftCardCell: View {
    let card: GiftCard
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 16) {
                Image(systemName: card.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                
                VStack(spacing: 4) {
                    Text(card.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("From \(card.denominations.min() ?? 0) sats")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct GiftCardPurchaseView: View {
    let card: GiftCard
    @ObservedObject var walletService: BitcoinWalletService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAmount: Int?
    @State private var isProcessing = false
    @State private var purchaseSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    Image(systemName: card.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text(card.name + " Gift Card")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Select amount:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(card.denominations, id: \.self) { amount in
                        Button {
                            selectedAmount = amount
                        } label: {
                            VStack(spacing: 8) {
                                Text("\(amount) sats")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(selectedAmount == amount ? .black : .white)
                                
                                Text("≈ $\(String(format: "%.2f", walletService.convertToFiat(sats: amount)))")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(selectedAmount == amount ? .black : .gray)
                            }
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedAmount == amount ? Color.white : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                
                if let amount = selectedAmount {
                    Button {
                        Task {
                            await purchaseGiftCard(amount: amount)
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isProcessing ? "Processing..." : "Purchase Gift Card")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                    .disabled(isProcessing || walletService.balance < amount)
                    .opacity(isProcessing || walletService.balance < amount ? 0.5 : 1.0)
                    
                    if walletService.balance < amount {
                        Text("Insufficient balance")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Gift Card Purchased!", isPresented: $purchaseSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your \(card.name) gift card has been sent to your email.")
            }
        }
    }
    
    private func purchaseGiftCard(amount: Int) async {
        isProcessing = true
        
        // Mock purchase process
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Deduct from balance
        walletService.balance = max(0, walletService.balance - amount)
        
        // Add transaction
        let transaction = BitcoinTransaction(
            id: UUID().uuidString,
            type: BitcoinTransactionType.sent,
            amount: amount,
            description: "\(card.name) Gift Card",
            timestamp: Date(),
            status: BitcoinTransactionStatus.confirmed,
            txHash: generateRandomString(64)
        )
        walletService.transactions.insert(transaction, at: 0)
        
        isProcessing = false
        purchaseSuccess = true
    }
    
    private func generateRandomString(_ length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
}

// Removed FundingMethodCard - replaced with GiftCard functionality

#Preview {
    WalletView()
}