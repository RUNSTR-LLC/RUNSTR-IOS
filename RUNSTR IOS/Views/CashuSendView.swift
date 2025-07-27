import SwiftUI

struct CashuSendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cashuService: CashuService
    
    @State private var amount: String = ""
    @State private var isCreatingToken = false
    @State private var createdToken: String = ""
    @State private var showingTokenSheet = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                
                amountInputSection
                
                if !createdToken.isEmpty {
                    tokenDisplaySection
                } else {
                    createTokenButton
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Color.black)
            .foregroundColor(.white)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingTokenSheet) {
            TokenShareView(token: createdToken)
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.white)
            
            Spacer()
            
            Text("Send Cashu Tokens")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Color.clear
                .frame(width: 60)
        }
        .padding(.top, 20)
    }
    
    private var amountInputSection: some View {
        VStack(spacing: 16) {
            Text("Amount to Send")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                TextField("0", text: $amount)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                
                Text("sats")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            
            Text("Available: \(cashuService.balance) sats")
                .font(.caption)
                .foregroundColor(.gray)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
    }
    
    private var createTokenButton: some View {
        Button {
            createToken()
        } label: {
            HStack {
                if isCreatingToken {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                
                Text(isCreatingToken ? "Creating Token..." : "Create Token")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isValidAmount ? Color.orange : Color.gray)
            )
        }
        .disabled(!isValidAmount || isCreatingToken)
    }
    
    private var tokenDisplaySection: some View {
        VStack(spacing: 16) {
            Text("Token Created!")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("Share this token:")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(createdToken)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .onTapGesture {
                        UIPasteboard.general.string = createdToken
                    }
                
                Text("Tap to copy")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Button {
                showingTokenSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Token")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
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
    
    private var isValidAmount: Bool {
        guard let amountInt = Int(amount), amountInt > 0 else { return false }
        return amountInt <= cashuService.balance
    }
    
    private func createToken() {
        guard let amountInt = Int(amount), amountInt > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        guard amountInt <= cashuService.balance else {
            errorMessage = "Insufficient balance"
            return
        }
        
        isCreatingToken = true
        errorMessage = ""
        
        Task {
            do {
                let token = try await cashuService.sendTokens(amount: amountInt)
                await MainActor.run {
                    createdToken = token
                    isCreatingToken = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create token: \(error.localizedDescription)"
                    isCreatingToken = false
                }
            }
        }
    }
}

struct TokenShareView: View {
    let token: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Share Cashu Token")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(token)
                    .font(.system(size: 14, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                Button("Copy to Clipboard") {
                    UIPasteboard.general.string = token
                    dismiss()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange)
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}