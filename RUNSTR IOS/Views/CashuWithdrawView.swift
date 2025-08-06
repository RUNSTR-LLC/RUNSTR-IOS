import SwiftUI

struct CashuWithdrawView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cashuService: CashuService
    
    @State private var invoice: String = ""
    @State private var amount: String = ""
    @State private var isWithdrawing = false
    @State private var showingSuccess = false
    @State private var errorMessage: String = ""
    @State private var preimage: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                
                if showingSuccess {
                    successSection
                } else {
                    inputSection
                    withdrawButton
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Color.black)
            .foregroundColor(.white)
            .navigationBarHidden(true)
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.white)
            
            Spacer()
            
            Text("Lightning Withdrawal")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Color.clear
                .frame(width: 60)
        }
        .padding(.top, 20)
    }
    
    private var inputSection: some View {
        VStack(spacing: 20) {
            // Amount input
            VStack(spacing: 16) {
                Text("Amount to Withdraw")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack {
                    Image(systemName: "bolt.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    TextField("0", text: $amount)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                    
                    Text("sats")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                
                Text("Available: \(cashuService.balance) sats")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Lightning invoice input
            VStack(spacing: 16) {
                Text("Lightning Invoice")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    TextEditor(text: $invoice)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .background(Color.clear)
                        .frame(height: 100)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("Paste a Lightning invoice (lnbc...)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Button {
                    if let clipboardString = UIPasteboard.general.string {
                        invoice = clipboardString
                        // Try to extract amount from invoice
                        extractAmountFromInvoice(clipboardString)
                    }
                } label: {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
    }
    
    private var withdrawButton: some View {
        Button {
            withdrawToLightning()
        } label: {
            HStack {
                if isWithdrawing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title3)
                }
                
                Text(isWithdrawing ? "Withdrawing..." : "Withdraw to Lightning")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isValidWithdrawal ? Color.blue : Color.gray)
            )
        }
        .disabled(!isValidWithdrawal || isWithdrawing)
    }
    
    private var successSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Withdrawal Successful!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                Text("Sent via Lightning:")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "bolt.circle.fill")
                        .foregroundColor(.orange)
                    Text("\(amount) sats")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            
            if !preimage.isEmpty {
                VStack(spacing: 8) {
                    Text("Payment Preimage:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(preimage)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .onTapGesture {
                            UIPasteboard.general.string = preimage
                        }
                }
            }
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var isValidWithdrawal: Bool {
        guard let amountInt = Int(amount), amountInt > 0 else { return false }
        guard amountInt <= cashuService.balance else { return false }
        guard invoice.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("lnbc") else { return false }
        return true
    }
    
    private func extractAmountFromInvoice(_ invoice: String) {
        // Simple amount extraction from Lightning invoice
        // Real implementation would use proper BOLT11 decoding
        let cleanInvoice = invoice.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if cleanInvoice.hasPrefix("lnbc") {
            let withoutPrefix = String(cleanInvoice.dropFirst(4))
            
            // Look for amount in the invoice (simplified extraction)
            let scanner = Scanner(string: withoutPrefix)
            if let extractedAmount = scanner.scanInt() {
                // Convert to sats based on suffix
                if withoutPrefix.contains("m") {
                    amount = String(extractedAmount * 100000) // millibitcoin to sats
                } else if withoutPrefix.contains("u") {
                    amount = String(extractedAmount * 100) // microbitcoin to sats
                } else if withoutPrefix.contains("n") {
                    amount = String(extractedAmount / 10) // nanobitcoin to sats
                } else {
                    amount = String(extractedAmount) // assume sats
                }
            }
        }
    }
    
    private func withdrawToLightning() {
        guard let amountInt = Int(amount), amountInt > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        guard amountInt <= cashuService.balance else {
            errorMessage = "Insufficient balance"
            return
        }
        
        let cleanInvoice = invoice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanInvoice.lowercased().hasPrefix("lnbc") else {
            errorMessage = "Please enter a valid Lightning invoice"
            return
        }
        
        isWithdrawing = true
        errorMessage = ""
        
        Task {
            do {
                try await cashuService.meltTokens(amount: amountInt, lightningInvoice: cleanInvoice)
                
                await MainActor.run {
                    showingSuccess = true
                    isWithdrawing = false
                    // In a real implementation, you'd get the preimage from the response
                    preimage = "Payment successful"
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Withdrawal failed: \(error.localizedDescription)"
                    isWithdrawing = false
                }
            }
        }
    }
}

#Preview {
    CashuWithdrawView()
        .environmentObject(CashuService())
}