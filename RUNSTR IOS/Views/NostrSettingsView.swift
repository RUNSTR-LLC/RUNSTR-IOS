import SwiftUI

struct NostrAdvancedSettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingKeyGeneration = false
    @State private var showingMainNpubInput = false
    @State private var showingRelayManagement = false
    @State private var mainNpubInput = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                
                ScrollView {
                    VStack(spacing: 32) {
                        connectionStatusSection
                        
                        keyManagementSection
                        
                        delegationSection
                        
                        relayManagementSection
                        
                        workoutEventsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .background(Color.black)
            .foregroundColor(.white)
        }
        .sheet(isPresented: $showingKeyGeneration) {
            KeyGenerationView()
        }
        .sheet(isPresented: $showingMainNpubInput) {
            MainNpubInputView(npubInput: $mainNpubInput, nostrService: nostrService)
        }
        .sheet(isPresented: $showingRelayManagement) {
            RelayManagementView()
        }
        .task {
            if !nostrService.isConnected {
                await nostrService.connectToRelays()
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button("Close") {
                dismiss()
            }
            .foregroundColor(.white)
            
            Spacer()
            
            Text("Nostr Settings")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            // Invisible button for balance
            Button("") { }
                .foregroundColor(.clear)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .background(Color.black)
    }
    
    private var connectionStatusSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Connection Status")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 12) {
                Circle()
                    .fill(nostrService.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(nostrService.isConnected ? "Connected" : "Disconnected")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("\(nostrService.connectedRelays.count) relays")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button {
                    Task {
                        if nostrService.isConnected {
                            await nostrService.disconnectFromRelays()
                        } else {
                            await nostrService.connectToRelays()
                        }
                    }
                } label: {
                    Text(nostrService.isConnected ? "Disconnect" : "Connect")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var keyManagementSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Key Management")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // RUNSTR Identity
                if let keyPair = nostrService.userKeyPair {
                    NostrKeyCard(
                        title: "RUNSTR Identity",
                        subtitle: "Auto-generated for workout storage",
                        publicKey: keyPair.publicKey,
                        isMain: false
                    )
                } else {
                    Button {
                        showingKeyGeneration = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Generate RUNSTR Keys")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Create new Nostr identity for workouts")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    private var delegationSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Identity Delegation")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                if let mainNpub = nostrService.mainNostrPublicKey {
                    let subtitle = if let nip46Manager = nostrService.nip46ConnectionManager {
                        nip46Manager.isConnected ? "Connected via nsec bunker" : "nsec bunker disconnected"
                    } else if nostrService.isDelegatedSigning {
                        "Linked with delegation"
                    } else {
                        "Linked"
                    }
                    
                    NostrKeyCard(
                        title: "Main Identity",
                        subtitle: subtitle,
                        publicKey: mainNpub,
                        isMain: true
                    )
                    
                    if !nostrService.isDelegatedSigning {
                        Button {
                            // TODO: Setup delegation
                        } label: {
                            Text("Setup Delegation")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                } else {
                    Button {
                        showingMainNpubInput = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Link Main Nostr Identity")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Connect existing npub for identity delegation")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    private var relayManagementSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Relay Management")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(nostrService.connectedRelays, id: \.self) { relay in
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text(relay)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("Connected")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            Button {
                showingRelayManagement = true
            } label: {
                Text("Manage Relays")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
    
    private var workoutEventsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Workout Events")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            if nostrService.recentEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    
                    Text("No workout events published yet")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(nostrService.recentEvents) { event in
                        WorkoutEventRow(event: event)
                    }
                }
            }
        }
    }
}

struct NostrKeyCard: View {
    let title: String
    let subtitle: String
    let publicKey: String
    let isMain: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isMain {
                    Text("MAIN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            HStack {
                Text(publicKey)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = publicKey
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct WorkoutEventRow: View {
    let event: NostrWorkoutEvent
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.workout.activityType.systemImageName)
                .foregroundColor(.white)
                .font(.system(size: 16))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.formattedContent)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(event.createdAt.formatted(.dateTime.month().day().hour().minute()))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("Published")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct KeyGenerationView: View {
    @EnvironmentObject var nostrService: NostrService
    @Environment(\.dismiss) private var dismiss
    @State private var isGenerating = false
    @State private var showingBackup = false
    @State private var generatedKeyPair: NostrKeyPair?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "key.radiowaves.forward.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Generate Nostr Keys")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("This will create a new Nostr identity for your RUNSTR workouts. Keep your keys safe!")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                if let keyPair = generatedKeyPair {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PUBLIC KEY (npub)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(keyPair.publicKey)
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PRIVATE KEY (nsec)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                            
                            Text(keyPair.privateKey)
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.orange)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        Button {
                            nostrService.storeKeyPair(keyPair)
                            dismiss()
                        } label: {
                            Text("Save Keys Securely")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(2)
                        }
                    }
                } else {
                    Button {
                        generateKeys()
                    } label: {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isGenerating ? "Generating..." : "Generate Keys")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(2)
                    }
                    .disabled(isGenerating)
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
    
    private func generateKeys() {
        isGenerating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            generatedKeyPair = nostrService.generateRunstrKeys()
            isGenerating = false
        }
    }
}

struct MainNpubInputView: View {
    @Binding var npubInput: String
    @ObservedObject var nostrService: NostrService
    @Environment(\.dismiss) private var dismiss
    @State private var isLinking = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Link Main Identity")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Connect your existing Nostr account to enable identity delegation for RUNSTR workouts")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("MAIN NOSTR PUBLIC KEY")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    TextField("npub1...", text: $npubInput)
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
                
                Button {
                    Task {
                        await linkIdentity()
                    }
                } label: {
                    HStack {
                        if isLinking {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isLinking ? "Linking..." : "Link Identity")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .cornerRadius(2)
                }
                .disabled(npubInput.isEmpty || !npubInput.hasPrefix("npub1") || isLinking)
                .opacity(npubInput.isEmpty || !npubInput.hasPrefix("npub1") || isLinking ? 0.5 : 1.0)
                
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
    
    private func linkIdentity() async {
        isLinking = true
        
        let success = await nostrService.linkMainNostrIdentity(npubInput)
        
        isLinking = false
        
        if success {
            dismiss()
        }
    }
}

struct RelayManagementView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Relay Management")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Coming soon...")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.top, 40)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    NostrAdvancedSettingsView()
        .environmentObject(AuthenticationService())
        .environmentObject(NostrService())
}