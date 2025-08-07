import SwiftUI

struct WalletView: View {
    @EnvironmentObject var cashuService: CashuService
    @State private var showingSendView = false
    @State private var showingReceiveView = false
    @State private var showingFundingOptions = false
    @State private var showingCashuSend = false
    @State private var showingCashuReceive = false
    @State private var showingCashuWithdraw = false
    @State private var showingWeeklyRewards = false
    
    // Mock data for weekly rewards
    @State private var mockWeeklyRewards: [DayReward] = [
        DayReward(day: "Mon", activity: "Running", reward: 50, completed: true),
        DayReward(day: "Tue", activity: "Cycling", reward: 50, completed: true),
        DayReward(day: "Wed", activity: nil, reward: 0, completed: false),
        DayReward(day: "Thu", activity: "Walking", reward: 50, completed: true),
        DayReward(day: "Fri", activity: "Running", reward: 50, completed: true),
        DayReward(day: "Sat", activity: nil, reward: 0, completed: false),
        DayReward(day: "Sun", activity: nil, reward: 0, completed: false)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            ScrollView {
                VStack(spacing: 32) {
                    balanceSection
                    
                    actionButtonsSection
                    
                    weeklyRewardsSection
                    
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
        .sheet(isPresented: $showingCashuWithdraw) {
            CashuWithdrawView()
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
                Text("Balance")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("2,500")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            
            if let errorMessage = cashuService.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            WalletActionButton(
                title: "Send",
                icon: "arrow.up.circle.fill",
                color: .white
            ) {
                showingCashuSend = true
            }
            
            WalletActionButton(
                title: "Receive",
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
                showingCashuWithdraw = true
            }
        }
    }
    
    private var weeklyRewardsSection: some View {
        VStack(spacing: 20) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingWeeklyRewards.toggle()
                }
            } label: {
                HStack {
                    Text("Weekly Rewards")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("(\(mockWeeklyRewards.filter { $0.completed }.reduce(0) { $0 + $1.reward }))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Image(systemName: showingWeeklyRewards ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .animation(.easeInOut(duration: 0.3), value: showingWeeklyRewards)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if showingWeeklyRewards {
                VStack(spacing: 1) {
                    // Weekly summary
                    HStack {
                        Text("This Week")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(mockWeeklyRewards.filter { $0.completed }.count) workouts • \(mockWeeklyRewards.filter { $0.completed }.reduce(0) { $0 + $1.reward }) earned")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.02))
                    
                    // Daily breakdown
                    ForEach(mockWeeklyRewards, id: \.day) { dayReward in
                        HStack {
                            Text(dayReward.day)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 40, alignment: .leading)
                            
                            if let activity = dayReward.activity {
                                HStack(spacing: 8) {
                                    Image(systemName: getActivityIcon(for: activity))
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    
                                    Text(activity)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.gray)
                                }
                            } else {
                                Text("No workout")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            if dayReward.completed {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                    
                                    Text("+\(dayReward.reward)")
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(.green)
                                }
                            } else {
                                Text("-")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Rectangle()
                                .fill(dayReward.completed ? Color.green.opacity(0.05) : Color.white.opacity(0.02))
                        )
                    }
                    
                    // Streak bonus info
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        
                        Text("Current Streak: 4 days")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("+20 bonus")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func getActivityIcon(for activity: String) -> String {
        switch activity.lowercased() {
        case "running": return "figure.run"
        case "cycling": return "bicycle"
        case "walking": return "figure.walk"
        case "swimming": return "figure.pool.swim"
        default: return "figure.run"
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
            
            if cashuService.pendingOperations.isEmpty && cashuService.balance == 0 {
                VStack(spacing: 16) {
                    Image(systemName: "creditcard.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No transactions yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("Start earning rewards by completing workouts!")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(cashuService.pendingOperations.reversed()) { operation in
                        CashuOperationRow(operation: operation)
                    }
                    
                    if cashuService.pendingOperations.isEmpty {
                        Text("All caught up!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.vertical, 20)
                    }
                }
            }
        }
    }
    
    // Helper methods for formatting
    private func formatBalance(_ amount: Int) -> String {
        if amount >= 1000 {
            let k = Double(amount) / 1000
            return String(format: "%.1fk", k)
        } else {
            return "\(amount)"
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

struct CashuOperationRow: View {
    let operation: CashuOperation
    
    private var operationIcon: String {
        switch operation.type {
        case .mint: return "plus.circle.fill"
        case .melt: return "bolt.circle.fill"
        case .send: return "arrow.up.circle.fill"
        case .receive: return "arrow.down.circle.fill"
        }
    }
    
    private var operationColor: Color {
        switch operation.type {
        case .mint, .receive: return .green
        case .melt, .send: return operation.status == .failed ? .red : .white
        }
    }
    
    private var operationTitle: String {
        switch operation.type {
        case .mint: return "Mint Tokens"
        case .melt: return "Lightning Withdrawal"
        case .send: return "Send Tokens"
        case .receive: return "Receive Tokens"
        }
    }
    
    private var statusColor: Color {
        switch operation.status {
        case .pending: return .yellow
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: operationIcon)
                .foregroundColor(operationColor)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(operationTitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(DateFormatter.localizedString(from: operation.timestamp, dateStyle: .short, timeStyle: .short))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(operation.type == .send || operation.type == .melt ? "-" : "+")\(operation.amount)")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(operationColor)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(operation.status == .pending ? "Pending" : operation.status == .completed ? "Complete" : "Failed")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
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

struct DayReward {
    let day: String
    let activity: String?
    let reward: Int
    let completed: Bool
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
