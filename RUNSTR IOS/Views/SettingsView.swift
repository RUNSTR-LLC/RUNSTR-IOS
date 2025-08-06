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

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
        .environmentObject(SubscriptionService())
        .environmentObject(NostrService())
}