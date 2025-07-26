import SwiftUI

struct BitcoinPaymentView: View {
    let tier: SubscriptionTier
    let onComplete: (Bool) -> Void
    
    @State private var isProcessing = false
    @State private var paymentStep: PaymentStep = .invoice
    @State private var invoiceString = ""
    @State private var showingInvoiceQR = false
    
    enum PaymentStep {
        case invoice
        case waiting
        case success
        case failed
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                headerSection
                
                switch paymentStep {
                case .invoice:
                    invoiceSection
                case .waiting:
                    waitingSection
                case .success:
                    successSection
                case .failed:
                    failedSection
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
                        onComplete(false)
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            generateMockInvoice()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
            
            Text("Pay with Bitcoin")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 4) {
                Text("\(tier.displayName) Subscription")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text("$\(String(format: "%.2f", tier.bitcoinDiscountPrice))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("$\(String(format: "%.2f", tier.monthlyPrice))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                        .strikethrough()
                    
                    Text("10% OFF")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white)
                        .cornerRadius(4)
                }
            }
        }
    }
    
    private var invoiceSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Lightning Invoice")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Button {
                    showingInvoiceQR = true
                } label: {
                    VStack(spacing: 12) {
                        // Mock QR Code placeholder
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: 200, height: 200)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 40))
                                        .foregroundColor(.black)
                                    
                                    Text("Tap to View QR")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.black)
                                }
                            )
                        
                        Text("Tap QR code to copy or share")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LIGHTNING INVOICE")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        Text(invoiceString)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .truncationMode(.middle)
                        
                        Button {
                            copyToClipboard(invoiceString)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                
                Button {
                    startPaymentProcess()
                } label: {
                    Text("I've Paid")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(2)
                }
            }
        }
    }
    
    private var waitingSection: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            VStack(spacing: 8) {
                Text("Confirming Payment")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Please wait while we confirm your Bitcoin payment")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var successSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("Payment Successful!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your \(tier.displayName) subscription is now active")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                onComplete(true)
            } label: {
                Text("Continue")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .cornerRadius(2)
            }
        }
    }
    
    private var failedSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Payment Failed")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("We couldn't confirm your Bitcoin payment. Please try again.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button {
                    paymentStep = .invoice
                    generateMockInvoice()
                } label: {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(2)
                }
                
                Button {
                    onComplete(false)
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func generateMockInvoice() {
        // Mock Lightning invoice generation
        invoiceString = "lnbc\(Int(tier.bitcoinDiscountPrice * 100))u1pw8x2k3pp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygs9qy9qsqsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygs9qy9qsqsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygs9qy9qsq"
    }
    
    private func startPaymentProcess() {
        paymentStep = .waiting
        isProcessing = true
        
        // Mock payment confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Simulate 90% success rate
            let success = Int.random(in: 1...10) <= 9
            paymentStep = success ? .success : .failed
            isProcessing = false
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        // Could add haptic feedback here
    }
}

#Preview {
    BitcoinPaymentView(tier: .member) { _ in }
}