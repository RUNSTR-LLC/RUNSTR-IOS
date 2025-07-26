import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var nostrService: NostrService
    @State private var showingSubscriptionView = false
    @State private var showingNostrSettings = false
    @State private var showingAdvancedNostrSettings = false
    @State private var mainNpubInput = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                
                ScrollView {
                    VStack(spacing: 32) {
                        subscriptionSection
                        
                        profileSection
                        
                        nostrSection
                        
                        accountSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .background(Color.black)
            .foregroundColor(.white)
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingNostrSettings) {
            NostrSettingsView(mainNpubInput: $mainNpubInput)
        }
        .sheet(isPresented: $showingAdvancedNostrSettings) {
            NostrAdvancedSettingsView()
        }
    }
    
    private var headerSection: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .background(Color.black)
    }
    
    private var subscriptionSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Subscription")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Current subscription status
                if let status = subscriptionService.subscriptionStatus {
                    CurrentSubscriptionCard(status: status)
                } else {
                    // Loading or no subscription
                    FreeSubscriptionCard()
                }
                
                // Upgrade/Manage button
                Button {
                    showingSubscriptionView = true
                } label: {
                    Text(subscriptionService.subscriptionStatus?.tier == .none ? "Upgrade Plan" : "Manage Subscription")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(2)
                }
            }
        }
    }
    
    private var profileSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Profile")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Profile picture placeholder
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(authService.currentUser?.profile.displayName.prefix(1).uppercased() ?? "U")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authService.currentUser?.profile.displayName.isEmpty == false ? 
                             authService.currentUser!.profile.displayName : "Runner")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(authService.currentUser?.email ?? "No email")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                        
                        if let user = authService.currentUser {
                            Text("Member since \(user.createdAt.formatted(.dateTime.month().day().year()))")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
    
    private var nostrSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Nostr Integration")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                // RUNSTR npub (always present)
                NostrKeyRow(
                    title: "RUNSTR Identity",
                    subtitle: "Generated for workout storage",
                    key: authService.currentUser?.runstrNostrPublicKey ?? "",
                    isMainKey: false
                )
                
                // Main npub (optional)
                if let mainNpub = authService.currentUser?.mainNostrPublicKey {
                    NostrKeyRow(
                        title: "Main Identity",
                        subtitle: authService.currentUser?.isDelegatedSigning == true ? "Linked with delegation" : "Linked",
                        key: mainNpub,
                        isMainKey: true
                    )
                } else {
                    Button {
                        showingNostrSettings = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Link Main Nostr Identity")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Connect your existing npub")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    private var accountSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Account")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 1) {
                SettingsRowButton(
                    title: "Privacy Settings",
                    subtitle: "Workout visibility and data sharing",
                    icon: "lock"
                ) {
                    // Handle privacy settings
                }
                
                SettingsRowButton(
                    title: "Notifications",
                    subtitle: "Challenge alerts and reminders",
                    icon: "bell"
                ) {
                    // Handle notifications
                }
                
                SettingsRowButton(
                    title: "Nostr Advanced",
                    subtitle: "Protocol settings and key management",
                    icon: "network"
                ) {
                    showingAdvancedNostrSettings = true
                }
                
                SettingsRowButton(
                    title: "Support",
                    subtitle: "Help center and contact",
                    icon: "questionmark.circle"
                ) {
                    // Handle support
                }
                
                SettingsRowButton(
                    title: "Sign Out",
                    subtitle: nil,
                    icon: "arrow.right.square",
                    destructive: true
                ) {
                    authService.signOut()
                }
            }
        }
    }
}

struct CurrentSubscriptionCard: View {
    let status: SubscriptionStatus
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: status.tier.systemImageName)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.tier.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("$\(String(format: "%.2f", status.tier.monthlyPrice))/month")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(status.isActive ? "ACTIVE" : "EXPIRED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(status.isActive ? .green : .red)
                    
                    if let days = status.daysUntilExpiration {
                        Text("\(days) days left")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            if !status.autoRenew && status.isActive {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    
                    Text("Auto-renewal is off")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct FreeSubscriptionCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person")
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Plan")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Limited features and rewards")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("CURRENT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct NostrKeyRow: View {
    let title: String
    let subtitle: String
    let key: String
    let isMainKey: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isMainKey {
                    Text("MAIN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            
            Text(subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray)
            
            HStack {
                Text(key)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Button {
                    UIPasteboard.general.string = key
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SettingsRowButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let destructive: Bool
    let action: () -> Void
    
    init(title: String, subtitle: String?, icon: String, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.destructive = destructive
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(destructive ? .red : .white)
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(destructive ? .red : .white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if !destructive {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color.white.opacity(0.02))
            )
        }
    }
}

struct NostrSettingsView: View {
    @Binding var mainNpubInput: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Link Nostr Identity")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Connect your existing Nostr account to display your profile and enable delegated signing")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MAIN NOSTR PUBLIC KEY")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField("npub1...", text: $mainNpubInput)
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
                        // Link the npub
                        dismiss()
                    } label: {
                        Text("Link Account")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(2)
                    }
                    .disabled(mainNpubInput.isEmpty || !mainNpubInput.hasPrefix("npub1"))
                    .opacity(mainNpubInput.isEmpty || !mainNpubInput.hasPrefix("npub1") ? 0.5 : 1.0)
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
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationService())
        .environmentObject(SubscriptionService())
}