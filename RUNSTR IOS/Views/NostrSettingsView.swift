import SwiftUI

struct NostrSettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header
                    headerSection
                    
                    // Connection Status
                    connectionStatusSection
                    
                    // Basic Settings
                    basicSettingsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
            }
            
            Spacer()
            
            Text("Nostr Settings")
                .font(.runstrTitle)
                .foregroundColor(.runstrWhite)
            
            Spacer()
            
            // Invisible spacer for centering
            Image(systemName: "xmark")
                .font(.title2)
                .foregroundColor(.clear)
        }
    }
    
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.runstrWhite)
                Text("Connection Status")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            HStack(spacing: RunstrSpacing.sm) {
                Circle()
                    .fill(nostrService.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(nostrService.isConnected ? "Connected to Nostr relays" : "Disconnected")
                    .font(.runstrBody)
                    .foregroundColor(.runstrWhite)
                
                Spacer()
                
                Button {
                    Task {
                        if nostrService.isConnected {
                            await nostrService.disconnect()
                        } else {
                            await nostrService.connect()
                        }
                    }
                } label: {
                    Text(nostrService.isConnected ? "Disconnect" : "Connect")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrWhite)
                        .padding(.horizontal, RunstrSpacing.sm)
                        .padding(.vertical, RunstrSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.runstrWhite.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var basicSettingsSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "key")
                    .foregroundColor(.runstrWhite)
                Text("Identity")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            if let user = authService.currentUser {
                VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                    Text("Public Key")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    
                    Text(user.nostrPublicKey)
                        .font(.runstrSmall)
                        .foregroundColor(.runstrWhite)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                Text("No user authenticated")
                    .font(.runstrBody)
                    .foregroundColor(.runstrGray)
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
}

#Preview {
    NostrSettingsView()
        .environmentObject(AuthenticationService())
        .environmentObject(NostrService())
}