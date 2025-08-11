import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingNostrSettings = false
    @State private var selectedActivityType: ActivityType = .running
    @State private var skipStartCountdown = false
    @State private var useLocalStats = false
    @State private var autoPublishRuns = true
    @State private var autoPostRunNotes = true
    @State private var showingExportKeyAlert = false
    @State private var exportedKey = ""
    
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
        .sheet(isPresented: $showingNostrSettings) {
            NostrSettingsView()
        }
        .alert("Your RUNSTR Private Key", isPresented: $showingExportKeyAlert) {
            Button("Copy to Clipboard") {
                UIPasteboard.general.string = exportedKey
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is your private key (nsec). Keep it safe and never share it with anyone. You can use this key to recover your RUNSTR account.")
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
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var statsSettingsSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.runstrWhite)
                Text("Stats Settings")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            Toggle("Use Local Stats Only", isOn: $useLocalStats)
                .font(.runstrBody)
                .foregroundColor(.runstrWhite)
                .toggleStyle(SwitchToggleStyle(tint: .runstrWhite))
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var accountSecuritySection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.runstrWhite)
                Text("Account & Nostr Identity")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            
            if let user = authService.currentUser {
                VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                    Text("Apple ID Account")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    
                    Text(user.email ?? "No email")
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                }
                
                Divider()
                    .background(Color.runstrGray)
                
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
            
            Toggle("Auto-Post Run Notes", isOn: $autoPostRunNotes)
                .font(.runstrBody)
                .foregroundColor(.runstrWhite)
                .toggleStyle(SwitchToggleStyle(tint: .runstrWhite))
            
            Button {
                showingNostrSettings = true
            } label: {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.runstrWhite)
                    Text("Nostr Configuration")
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private func loadSettings() {
        // Load user preferences from storage or defaults
        // This would typically load from UserDefaults or the User model
    }
    
    private func exportPrivateKey() {
        guard let user = authService.currentUser else { return }
        exportedKey = user.nostrPrivateKey
        showingExportKeyAlert = true
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
        .environmentObject(NostrService())
}