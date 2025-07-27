import SwiftUI

struct CashuReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cashuService: CashuService
    
    @State private var tokenInput: String = ""
    @State private var isReceivingToken = false
    @State private var receivedAmount: Int = 0
    @State private var showingSuccess = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                
                if showingSuccess {
                    successSection
                } else {
                    inputSection
                    receiveButton
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
            
            Text("Receive Cashu Tokens")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Color.clear
                .frame(width: 60)
        }
        .padding(.top, 20)
    }
    
    private var inputSection: some View {
        VStack(spacing: 16) {
            Text("Paste Cashu Token")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                TextEditor(text: $tokenInput)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .background(Color.clear)
                    .frame(height: 100)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                
                Text("Paste a Cashu token starting with 'cashuA'")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Button {
                if let clipboardString = UIPasteboard.general.string {
                    tokenInput = clipboardString
                }
            } label: {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste from Clipboard")
                }
                .foregroundColor(.orange)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
    }
    
    private var receiveButton: some View {
        Button {
            receiveToken()
        } label: {
            HStack {
                if isReceivingToken {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                }
                
                Text(isReceivingToken ? "Receiving..." : "Receive Token")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isValidToken ? Color.green : Color.gray)
            )
        }
        .disabled(!isValidToken || isReceivingToken)
    }
    
    private var successSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Token Received!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                Text("Added to your wallet:")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .foregroundColor(.orange)
                    Text("\(receivedAmount) sats")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
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
                            .fill(Color.orange)
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var isValidToken: Bool {
        return tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("cashuA")
    }
    
    private func receiveToken() {
        let token = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidToken else {
            errorMessage = "Invalid token format"
            return
        }
        
        isReceivingToken = true
        errorMessage = ""
        
        Task {
            do {
                let balanceBefore = cashuService.balance
                try await cashuService.receiveTokens(token)
                let balanceAfter = cashuService.balance
                
                await MainActor.run {
                    receivedAmount = balanceAfter - balanceBefore
                    showingSuccess = true
                    isReceivingToken = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to receive token: \(error.localizedDescription)"
                    isReceivingToken = false
                }
            }
        }
    }
}