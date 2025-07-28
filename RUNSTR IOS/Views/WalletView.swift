import SwiftUI

struct WalletView: View {
    @EnvironmentObject var cashuService: CashuService
    @State private var showingSendView = false
    @State private var showingReceiveView = false
    @State private var showingFundingOptions = false
    @State private var showingCashuSend = false
    @State private var showingCashuReceive = false
    
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
        .sheet(isPresented: $showingCashuSend) {
            CashuSendView()
        }
        .sheet(isPresented: $showingCashuReceive) {
            CashuReceiveView()
        }
        .sheet(isPresented: $showingFundingOptions) {
            Text("Funding options coming soon")
                .padding()
        }
    }
    
    private var headerSection: some View {
        HStack {
            Text("Wallet")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .background(Color.black)
    }
    
    private var balanceSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Cashu Balance")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    Text(self.formatSats(cashuService.balance))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Text("≈ $\(String(format: "%.2f", self.convertToFiat(sats: cashuService.balance)))")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            
            if let errorMessage = cashuService.errorMessage {
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
        HStack(spacing: 12) {
            WalletActionButton(
                title: "Send Tokens",
                icon: "arrow.up.circle.fill",
                color: .orange
            ) {
                showingCashuSend = true
            }
            
            WalletActionButton(
                title: "Receive Tokens",
                icon: "arrow.down.circle.fill",
                color: .green
            ) {
                showingCashuReceive = true
            }
            
            WalletActionButton(
                title: "Withdraw",
                icon: "bolt.circle.fill",
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
            
            if cashuService.balance == 0 {
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
                    Text("Transaction history coming soon")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.vertical, 40)
                }
            }
        }
    }
    
    // Helper methods for formatting
    private func formatSats(_ sats: Int) -> String {
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
    
    private func convertToFiat(sats: Int) -> Double {
        // Mock conversion rate: 1 BTC = $40,000, so 1 sat = $0.0004
        return Double(sats) * 0.0004
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
    let transaction: CashuTransaction
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: transaction.type == .reward ? "plus.circle.fill" : "minus.circle.fill")
                .foregroundColor(transaction.type == .reward ? .green : .red)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.displaySource)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(DateFormatter.localizedString(from: transaction.timestamp, dateStyle: .short, timeStyle: .short))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.displayAmount)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(transaction.amount >= 0 ? .green : .red)
                
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
