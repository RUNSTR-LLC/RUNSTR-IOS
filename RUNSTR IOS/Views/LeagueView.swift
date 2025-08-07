import SwiftUI

struct LeagueView: View {
    @State private var showingSettings = false
    @State private var showingWalletView = false
    @State private var selectedActivityType: ActivityType = .running
    
    // Mock wallet balance to match dashboard
    @State private var mockWalletBalance: Int = 2500
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header with activity selector and settings
                    headerSection
                    
                    // League content placeholder
                    VStack(spacing: RunstrSpacing.md) {
                        Text("League")
                            .font(.runstrTitle)
                            .foregroundColor(.runstrWhite)
                        
                        Text("Coming Soon")
                            .font(.runstrBody)
                            .foregroundColor(.runstrGray)
                        
                        Text("Compete with other runners in leagues and tournaments")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGrayLight)
                            .multilineTextAlignment(.center)
                    }
                    .padding(RunstrSpacing.xl)
                    .runstrCard()
                    
                    Spacer(minLength: 100) // Bottom padding for tab bar
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingWalletView) {
            WalletView()
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Dynamic activity selector
            Menu {
                ForEach(ActivityType.allCases, id: \.self) { activityType in
                    Button {
                        selectedActivityType = activityType
                    } label: {
                        HStack {
                            Image(systemName: activityType.systemImageName)
                            Text(activityType.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: RunstrSpacing.sm) {
                    Image(systemName: selectedActivityType.systemImageName)
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                    
                    Text(selectedActivityType.displayName.uppercased())
                        .font(.runstrCaption)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.down")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.vertical, RunstrSpacing.sm)
            }
            .runstrCard()
            
            Spacer()
            
            // Wallet balance button
            Button {
                showingWalletView = true
            } label: {
                Text("\(mockWalletBalance)")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
                    .fontWeight(.bold)
                    .padding(.horizontal, RunstrSpacing.md)
                    .padding(.vertical, RunstrSpacing.sm)
            }
            .runstrCard()
            
            // Settings button
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
            }
        }
    }
}

#Preview {
    LeagueView()
}