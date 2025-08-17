import SwiftUI
import NostrSDK

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var unitPreferences: UnitPreferencesService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedActivityType: ActivityType = .running
    @State private var skipStartCountdown = false
    @State private var autoPublishRuns = true
    @State private var autoPostRunNotes = true
    @State private var enableHapticFeedback = true
    @State private var showingExportKeyAlert = false
    @State private var exportedKey = ""
    @State private var showingImportKeyModal = false
    @State private var showingImportKeyWarning = false
    @State private var importedNsec = ""
    @State private var importError = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header
                    headerSection
                    
                    // Activity Types
                    activityTypesSection
                    
                    // Run Behavior
                    runBehaviorSection
                    
                    // Units & Feedback
                    unitsAndFeedbackSection
                    
                    
                    // Account & Security
                    accountSecuritySection
                    
                    // Nostr Publishing
                    nostrPublishingSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .alert("Your RUNSTR Private Key", isPresented: $showingExportKeyAlert) {
            Button("Copy to Clipboard") {
                UIPasteboard.general.string = exportedKey
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is your private key (nsec). Keep it safe and never share it with anyone. You can use this key to recover your RUNSTR account.")
        }
        .alert("Security Warning", isPresented: $showingImportKeyWarning) {
            Button("I Understand the Risks") {
                showingImportKeyModal = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Importing a private key (nsec) has security risks. Your key could be exposed if pasted from an insecure source. We recommend using your Apple ID with auto-generated keys instead. Only proceed if you understand these risks.")
        }
        .sheet(isPresented: $showingImportKeyModal) {
            ImportKeyView(
                importedNsec: $importedNsec,
                importError: $importError,
                onImport: importPrivateKey,
                onCancel: {
                    showingImportKeyModal = false
                    importedNsec = ""
                    importError = ""
                }
            )
        }
        .onAppear {
            loadSettings()
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
            
            Text("Settings")
                .font(.runstrTitle)
                .foregroundColor(.runstrWhite)
            
            Spacer()
            
            // Invisible spacer for centering
            Image(systemName: "xmark")
                .font(.title2)
                .foregroundColor(.clear)
        }
    }
    
    private var activityTypesSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(.runstrWhite)
                Text("Default Activity Type")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            Picker("Activity Type", selection: $selectedActivityType) {
                ForEach(ActivityType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .colorScheme(.dark)
            .onChange(of: selectedActivityType) { _, newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: "selectedActivityType")
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var runBehaviorSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.runstrWhite)
                Text("Run Behavior")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            Toggle("Skip Start Countdown", isOn: $skipStartCountdown)
                .font(.runstrBody)
                .foregroundColor(.runstrWhite)
                .toggleStyle(SwitchToggleStyle(tint: .runstrWhite))
                .onChange(of: skipStartCountdown) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "skipStartCountdown")
                }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var unitsAndFeedbackSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "ruler")
                    .foregroundColor(.runstrWhite)
                Text("Units & Feedback")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            Toggle("Use Metric Units (km)", isOn: $unitPreferences.useMetricUnits)
                .font(.runstrBody)
                .foregroundColor(.runstrWhite)
                .toggleStyle(SwitchToggleStyle(tint: .runstrWhite))
            
            Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                .font(.runstrBody)
                .foregroundColor(.runstrWhite)
                .toggleStyle(SwitchToggleStyle(tint: .runstrWhite))
                .onChange(of: enableHapticFeedback) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "enableHapticFeedback")
                }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var accountSecuritySection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.runstrWhite)
                Text("Nostr Identity")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            if let user = authService.currentUser {
                VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                    Text("Your Nostr Public Key")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    
                    Button {
                        UIPasteboard.general.string = user.nostrPublicKey
                    } label: {
                        HStack {
                            Text(user.nostrPublicKey)
                                .font(.runstrSmall)
                                .foregroundColor(.runstrWhite)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Image(systemName: "doc.on.doc")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button {
                    exportPrivateKey()
                } label: {
                    HStack {
                        Image(systemName: "key.horizontal")
                            .foregroundColor(.orange)
                        Text("Export Private Key")
                            .font(.runstrBody)
                            .foregroundColor(.orange)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, RunstrSpacing.sm)
                
                Button {
                    showingImportKeyWarning = true
                } label: {
                    HStack {
                        Image(systemName: "key.horizontal.fill")
                            .foregroundColor(.blue)
                        Text("Import Private Key")
                            .font(.runstrBody)
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, RunstrSpacing.sm)
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var nostrPublishingSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.runstrWhite)
                Text("Nostr Publishing")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            Toggle("Auto-Publish Workouts", isOn: $autoPublishRuns)
                .font(.runstrBody)
                .foregroundColor(.runstrWhite)
                .toggleStyle(SwitchToggleStyle(tint: .runstrWhite))
                .onChange(of: autoPublishRuns) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "autoPublishRuns")
                }
            
            Toggle("Auto-Post Run Notes", isOn: $autoPostRunNotes)
                .font(.runstrBody)
                .foregroundColor(.runstrWhite)
                .toggleStyle(SwitchToggleStyle(tint: .runstrWhite))
                .onChange(of: autoPostRunNotes) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "autoPostRunNotes")
                }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private func loadSettings() {
        // Load user preferences from UserDefaults
        enableHapticFeedback = UserDefaults.standard.object(forKey: "enableHapticFeedback") as? Bool ?? true
        skipStartCountdown = UserDefaults.standard.object(forKey: "skipStartCountdown") as? Bool ?? false
autoPublishRuns = UserDefaults.standard.object(forKey: "autoPublishRuns") as? Bool ?? true
        autoPostRunNotes = UserDefaults.standard.object(forKey: "autoPostRunNotes") as? Bool ?? true
        
        if let activityTypeRaw = UserDefaults.standard.object(forKey: "selectedActivityType") as? String,
           let activityType = ActivityType(rawValue: activityTypeRaw) {
            selectedActivityType = activityType
        }
    }
    
    private func exportPrivateKey() {
        guard let user = authService.currentUser else { return }
        exportedKey = user.nostrPrivateKey
        showingExportKeyAlert = true
    }
    
    private func importPrivateKey() {
        guard !importedNsec.isEmpty else {
            importError = "Please enter a private key"
            return
        }
        
        // Validate nsec format
        guard importedNsec.hasPrefix("nsec1") && importedNsec.count >= 60 else {
            importError = "Invalid nsec format. Must start with 'nsec1' and be at least 60 characters."
            return
        }
        
        Task {
            do {
                let success = await authService.importNostrKey(importedNsec)
                if success {
                    await MainActor.run {
                        showingImportKeyModal = false
                        importedNsec = ""
                        importError = ""
                    }
                } else {
                    await MainActor.run {
                        importError = "Failed to import key. Please check the format and try again."
                    }
                }
            }
        }
    }
}

struct ImportKeyView: View {
    @Binding var importedNsec: String
    @Binding var importError: String
    let onImport: () -> Void
    let onCancel: () -> Void
    
    @State private var derivedNpub = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: RunstrSpacing.lg) {
                // Header
                VStack(spacing: RunstrSpacing.sm) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Import Private Key")
                        .font(.runstrTitle)
                        .foregroundColor(.runstrWhite)
                    
                    Text("Paste your nsec private key below")
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, RunstrSpacing.xl)
                
                // Input section
                VStack(alignment: .leading, spacing: RunstrSpacing.md) {
                    Text("Private Key (nsec)")
                        .font(.runstrSubheadline)
                        .foregroundColor(.runstrWhite)
                    
                    SecureField("nsec1...", text: $importedNsec)
                        .font(.runstrSmall)
                        .foregroundColor(.runstrWhite)
                        .padding(RunstrSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.runstrGray.opacity(0.1))
                                .stroke(Color.runstrGray.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: importedNsec) { _, newValue in
                            updateDerivedNpub(from: newValue)
                            importError = ""
                        }
                    
                    if !derivedNpub.isEmpty {
                        VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                            Text("Derived Public Key")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                            
                            Text(derivedNpub)
                                .font(.runstrSmall)
                                .foregroundColor(.green)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    
                    if !importError.isEmpty {
                        Text(importError)
                            .font(.runstrCaption)
                            .foregroundColor(.red)
                            .padding(.top, RunstrSpacing.xs)
                    }
                }
                .padding(.horizontal, RunstrSpacing.lg)
                
                Spacer()
                
                // Buttons
                VStack(spacing: RunstrSpacing.md) {
                    Button {
                        onImport()
                    } label: {
                        Text("Import Key")
                            .font(.runstrHeadline)
                            .foregroundColor(importedNsec.isEmpty ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(importedNsec.isEmpty ? Color.gray : Color.white)
                            .cornerRadius(25)
                    }
                    .disabled(importedNsec.isEmpty)
                    
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.runstrBody)
                            .foregroundColor(.runstrGray)
                    }
                }
                .padding(.horizontal, RunstrSpacing.lg)
                .padding(.bottom, RunstrSpacing.xl)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
    }
    
    private func updateDerivedNpub(from nsec: String) {
        // Use NostrSDK to derive public key from private key
        guard let nostrSDKKeypair = Keypair(nsec: nsec) else {
            derivedNpub = ""
            return
        }
        
        let keyPair = NostrKeyPair(
            privateKey: nostrSDKKeypair.privateKey.nsec,
            publicKey: nostrSDKKeypair.publicKey.npub
        )
        derivedNpub = keyPair.publicKey
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
        .environmentObject(NostrService())
}