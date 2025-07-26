import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingAdvancedSettings = false
    @State private var showingSubscriptionManagement = false
    
    var body: some View {
        NavigationView {
            Form {
                // User profile section
                userProfileSection
                
                // Subscription section
                subscriptionSection
                
                // Device connections
                deviceConnectionsSection
                
                // Notifications
                notificationsSection
                
                // Privacy
                privacySection
                
                // Advanced settings (hidden by default)
                if showingAdvancedSettings {
                    advancedSection
                }
                
                // Support and info
                supportSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.black)
            .foregroundColor(.white)
        }
    }
    
    private var userProfileSection: some View {
        Section {
            HStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(authService.currentUser?.profile.displayName.prefix(1) ?? "U")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(authService.currentUser?.profile.displayName ?? "User")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(authService.currentUser?.email ?? "No email")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button("Edit") {
                    // Handle profile edit
                }
                .foregroundColor(.orange)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Profile")
        }
    }
    
    private var subscriptionSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(authService.currentUser?.subscriptionTier.rawValue.capitalized ?? "None")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                if authService.currentUser?.subscriptionTier == SubscriptionTier.none {
                    Button("Upgrade") {
                        showingSubscriptionManagement = true
                    }
                    .foregroundColor(.orange)
                } else {
                    Text("$\(authService.currentUser?.subscriptionTier.monthlyPrice ?? 0, specifier: "%.2f")/month")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)
            
            Button("Manage Subscription") {
                showingSubscriptionManagement = true
            }
            .foregroundColor(.orange)
        } header: {
            Text("Subscription")
        }
    }
    
    private var deviceConnectionsSection: some View {
        Section {
            SettingsRow(
                title: "Apple Watch",
                subtitle: "Connected",
                icon: "applewatch",
                action: {}
            )
            
            SettingsRow(
                title: "Apple Music",
                subtitle: "Not connected",
                icon: "music.note",
                action: {}
            )
            
            SettingsRow(
                title: "Garmin Connect",
                subtitle: "Available",
                icon: "watch",
                action: {}
            )
        } header: {
            Text("Device Connections")
        }
    }
    
    private var notificationsSection: some View {
        Section {
            SettingsRow(
                title: "Workout Reminders",
                subtitle: "Daily at 7:00 AM",
                icon: "bell",
                action: {}
            )
            
            SettingsRow(
                title: "Team Updates",
                subtitle: "Enabled",
                icon: "person.3",
                action: {}
            )
            
            SettingsRow(
                title: "Reward Notifications",
                subtitle: "Enabled",
                icon: "bitcoinsign.circle",
                action: {}
            )
        } header: {
            Text("Notifications")
        }
    }
    
    private var privacySection: some View {
        Section {
            SettingsRow(
                title: "Activity Sharing",
                subtitle: "Team only",
                icon: "eye",
                action: {}
            )
            
            SettingsRow(
                title: "Data Export",
                subtitle: "Download your data",
                icon: "square.and.arrow.down",
                action: {}
            )
        } header: {
            Text("Privacy")
        }
    }
    
    private var advancedSection: some View {
        Section {
            SettingsRow(
                title: "Nostr Identity",
                subtitle: "View your npub",
                icon: "key",
                action: {}
            )
            
            SettingsRow(
                title: "Lightning Setup",
                subtitle: "Configure withdrawals",
                icon: "bolt",
                action: {}
            )
            
            SettingsRow(
                title: "Relay Management",
                subtitle: "4 relays connected",
                icon: "network",
                action: {}
            )
        } header: {
            Text("Advanced Settings")
        }
    }
    
    private var supportSection: some View {
        Section {
            SettingsRow(
                title: "Help & Support",
                subtitle: "Get help with RUNSTR",
                icon: "questionmark.circle",
                action: {}
            )
            
            SettingsRow(
                title: "Privacy Policy",
                subtitle: "Read our privacy policy",
                icon: "doc.text",
                action: {}
            )
            
            SettingsRow(
                title: "Terms of Service",
                subtitle: "Read our terms",
                icon: "doc.text",
                action: {}
            )
            
            // Advanced settings toggle
            Button {
                withAnimation {
                    showingAdvancedSettings.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "gearshape.2")
                        .foregroundColor(.orange)
                    
                    Text(showingAdvancedSettings ? "Hide Advanced Settings" : "Show Advanced Settings")
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Image(systemName: showingAdvancedSettings ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Sign out button
            Button {
                authService.signOut()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .foregroundColor(.red)
                    
                    Text("Sign Out")
                        .foregroundColor(.red)
                }
            }
        } header: {
            Text("Support & Legal")
        }
    }
}

struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
}