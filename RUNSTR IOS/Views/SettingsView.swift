import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var nostrService: NostrService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingSubscriptionView = false
    @State private var showingNostrSettings = false
    @State private var selectedActivityType: ActivityType = .running
    @State private var skipStartCountdown = false
    @State private var useLocalStats = false
    @State private var autoPublishRuns = true
    @State private var autoPostRunNotes = true
    @State private var showingExportKeyAlert = false
    @State private var exportedKey = ""
    @State private var showingNsecImport = false
    
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
                    
                    // Stats Settings
                    statsSettingsSection
                    
                    // Account & Security (only show for RUNSTR login users)
                    if authService.currentUser?.loginMethod == .runstr {
                        accountSecuritySection
                    }
                    
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
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingNostrSettings) {
            NostrSettingsView()
        }
        .alert("Your RUNSTR Private Key", isPresented: $showingExportKeyAlert) {
            Button("Copy to Clipboard") {
                UIPasteboard.general.string = exportedKey
            }
            Button("Done", role: .cancel) { }
        } message: {
            Text("Write this down and store it somewhere safe. This is your only way to recover your account.\n\n\(exportedKey)")
        }
        .sheet(isPresented: $showingNsecImport) {
            SettingsNsecImportView { nsec in
                let success = authService.signInWithNsec(nsec)
                if success {
                    showingNsecImport = false
                }
                return success
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            Text("Settings")
                .font(.runstrTitle)
                .foregroundColor(.runstrWhite)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
            }
        }
    }
    
    private var activityTypesSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            Text("Activity Types")
                .font(.runstrSubheadline)
                .foregroundColor(.runstrWhite)
            
            HStack(spacing: 0) {
                Button("Run") { selectedActivityType = .running }
                    .buttonStyle(RunstrActivityButton(isSelected: selectedActivityType == .running))
                
                Button("Walk") { selectedActivityType = .walking }
                    .buttonStyle(RunstrActivityButton(isSelected: selectedActivityType == .walking))
                
                Button("Cycle") { selectedActivityType = .cycling }
                    .buttonStyle(RunstrActivityButton(isSelected: selectedActivityType == .cycling))
            }
            .runstrCard()
            
            Text("Currently tracking: \(selectedActivityType.displayName)")
                .font(.runstrCaption)
                .foregroundColor(.runstrGray)
        }
    }
    
    private var runBehaviorSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            Text("Run Behavior")
                .font(.runstrSubheadline)
                .foregroundColor(.runstrWhite)
            
            SettingsToggleRow(
                title: "Skip Start Countdown",
                description: "Start the run immediately when you tap \"Start Run\".",
                isOn: $skipStartCountdown
            )
        }
    }
    
    private var statsSettingsSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            Text("Stats Settings")
                .font(.runstrSubheadline)
                .foregroundColor(.runstrWhite)
            
            SettingsToggleRow(
                title: "Use Local Stats",
                description: "When enabled, the Stats tab shows local run history instead of Nostr workout stats.",
                isOn: $useLocalStats
            )
        }
    }
    
    private var nostrPublishingSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            Text("Nostr Publishing")
                .font(.runstrSubheadline)
                .foregroundColor(.runstrWhite)
            
            VStack(spacing: RunstrSpacing.sm) {
                SettingsToggleRow(
                    title: "Auto-publish runs to Nostr",
                    description: "Automatically publish completed runs to Nostr with your team/challenge associations. You can still manually publish from the dashboard if disabled.",
                    isOn: $autoPublishRuns
                )
                
                SettingsToggleRow(
                    title: "Auto-post Run Notes to Nostr",
                    description: nil,
                    isOn: $autoPostRunNotes
                )
            }
        }
    }
    
    private var accountSecuritySection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            Text("Account & Security")
                .font(.runstrSubheadline)
                .foregroundColor(.runstrWhite)
            
            VStack(spacing: RunstrSpacing.sm) {
                // Export Private Key Button
                Button {
                    if let privateKey = authService.exportRunstrPrivateKey() {
                        exportedKey = privateKey
                        showingExportKeyAlert = true
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                            Text("Export Private Key")
                                .font(.runstrBodyMedium)
                                .foregroundColor(.runstrWhite)
                            
                            Text("Backup your nsec key for account recovery")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "key.horizontal")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    .padding(RunstrSpacing.lg)
                    .runstrCard()
                }
                
                // Restore/Import Account Button
                Button {
                    showingNsecImport = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                            Text("Restore Different Account")
                                .font(.runstrBodyMedium)
                                .foregroundColor(.runstrWhite)
                            
                            Text("Switch to a different RUNSTR account using your backed-up nsec")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                    .padding(RunstrSpacing.lg)
                    .runstrCard()
                }
                
                // Account Info
                VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                            Text("Login Method")
                                .font(.runstrBodyMedium)
                                .foregroundColor(.runstrWhite)
                            
                            Text("RUNSTR (Self-Custody)")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                    
                    if let user = authService.currentUser {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                            Text("Your Public Key (npub)")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                            
                            Text(user.displayNostrPublicKey)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(.runstrWhite)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding(RunstrSpacing.lg)
                .runstrCard()
                
                // Sign Out Button
                Button {
                    authService.signOut()
                } label: {
                    HStack {
                        Text("Sign Out")
                            .font(.runstrBodyMedium)
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                    .padding(RunstrSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            .background(Color.clear)
                    )
                }
            }
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let description: String?
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                    Text(title)
                        .font(.runstrBodyMedium)
                        .foregroundColor(.runstrWhite)
                    
                    if let description = description {
                        Text(description)
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: Color.runstrWhite))
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
}

struct NostrSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Nostr Settings")
                    .font(.runstrTitle)
                    .foregroundColor(.runstrWhite)
                
                Spacer()
                
                Text("Coming Soon")
                    .font(.runstrBody)
                    .foregroundColor(.runstrGray)
            }
            .padding()
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.runstrWhite)
                }
            }
        }
    }
}

struct SettingsNsecImportView: View {
    let onImport: (String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var nsecInput = ""
    @State private var errorMessage = ""
    @State private var isImporting = false
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Switch RUNSTR Account")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("This will replace your current account with the account associated with the nsec you enter. Make sure you've backed up your current account first!")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRIVATE KEY (nsec)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField("nsec1...", text: $nsecInput)
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
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button {
                        showingConfirmation = true
                    } label: {
                        Text("Switch Account")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(2)
                    }
                    .disabled(nsecInput.isEmpty || !nsecInput.hasPrefix("nsec1"))
                    .opacity((nsecInput.isEmpty || !nsecInput.hasPrefix("nsec1")) ? 0.5 : 1.0)
                }
                
                VStack(spacing: 8) {
                    Text("⚠️ Warning")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                    
                    Text("This action will log you out of your current account. Make sure you have backed up your current nsec before proceeding.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .background(Color.runstrBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.runstrWhite)
                }
            }
            .alert("Confirm Account Switch", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Switch Account", role: .destructive) {
                    isImporting = true
                    errorMessage = ""
                    
                    let success = onImport(nsecInput)
                    if !success {
                        errorMessage = "Invalid nsec format. Please check your private key and try again."
                    }
                    
                    isImporting = false
                }
            } message: {
                Text("This will replace your current RUNSTR account. Are you sure you want to continue?")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
        .environmentObject(SubscriptionService())
        .environmentObject(NostrService())
}