import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionService = SubscriptionService()
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTier: SubscriptionTier = .member
    @State private var selectedPaymentMethod: PaymentMethod = .applePay
    @State private var selectedTeam: TeamSelection?
    @State private var showingTeamSelector = false
    @State private var showingBitcoinPayment = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    
                    tierSelectionSection
                    
                    if selectedTier == .member {
                        teamSelectionSection
                    }
                    
                    paymentMethodSection
                    
                    subscribeButtonSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color.black)
            .foregroundColor(.white)
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
        .sheet(isPresented: $showingTeamSelector) {
            TeamSelectorView(selectedTeam: $selectedTeam)
        }
        .sheet(isPresented: $showingBitcoinPayment) {
            BitcoinPaymentView(tier: selectedTier) { success in
                if success {
                    dismiss()
                }
                showingBitcoinPayment = false
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Unlock rewards, join teams, and compete in events")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    private var tierSelectionSection: some View {
        VStack(spacing: 16) {
            ForEach(SubscriptionTier.allCases.filter { $0 != .none }, id: \.self) { tier in
                SubscriptionTierCard(
                    tier: tier,
                    isSelected: selectedTier == tier,
                    onSelect: { selectedTier = tier }
                )
            }
        }
    }
    
    private var teamSelectionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Choose Your Team")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            Button {
                showingTeamSelector = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedTeam?.teamName ?? "Select a team")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        if let team = selectedTeam {
                            Text("\(team.memberCount) members • \(team.activityLevel.displayName)")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    private var paymentMethodSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Payment Method")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 8) {
                PaymentMethodCard(
                    method: .applePay,
                    price: selectedTier.monthlyPrice,
                    isSelected: selectedPaymentMethod == .applePay,
                    onSelect: { selectedPaymentMethod = .applePay }
                )
                
                PaymentMethodCard(
                    method: .bitcoin,
                    price: selectedTier.bitcoinDiscountPrice,
                    isSelected: selectedPaymentMethod == .bitcoin,
                    onSelect: { selectedPaymentMethod = .bitcoin },
                    showDiscount: true
                )
            }
        }
    }
    
    private var subscribeButtonSection: some View {
        VStack(spacing: 16) {
            Button {
                handleSubscribe()
            } label: {
                HStack {
                    if subscriptionService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.8)
                    }
                    
                    Text(subscriptionService.isLoading ? "Processing..." : "Subscribe")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(2)
            }
            .disabled(subscriptionService.isLoading || (selectedTier == .member && selectedTeam == nil))
            .opacity((subscriptionService.isLoading || (selectedTier == .member && selectedTeam == nil)) ? 0.5 : 1.0)
            
            if let errorMessage = subscriptionService.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Text("Cancel anytime. No hidden fees.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray)
        }
    }
    
    private func handleSubscribe() {
        Task {
            if selectedPaymentMethod == .bitcoin {
                showingBitcoinPayment = true
            } else {
                // Find the product for the selected tier
                if let product = subscriptionService.availableProducts.first(where: { $0.id == selectedTier.productID }) {
                    let success = await subscriptionService.purchase(product, paymentMethod: selectedPaymentMethod)
                    if success {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SubscriptionTierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: tier.systemImageName)
                                .foregroundColor(.white)
                            
                            Text(tier.displayName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Text("$\(String(format: "%.2f", tier.monthlyPrice))")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("/month")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tier.features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: 12, weight: .medium))
                            
                            Text(feature)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

struct PaymentMethodCard: View {
    let method: PaymentMethod
    let price: Double
    let isSelected: Bool
    let onSelect: () -> Void
    let showDiscount: Bool
    
    init(method: PaymentMethod, price: Double, isSelected: Bool, onSelect: @escaping () -> Void, showDiscount: Bool = false) {
        self.method = method
        self.price = price
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.showDiscount = showDiscount
    }
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: method.systemImageName)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(method.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        if showDiscount {
                            Text("10% OFF")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("$\(String(format: "%.2f", price))/month")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(AuthenticationService())
}