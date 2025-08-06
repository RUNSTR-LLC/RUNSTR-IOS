import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var healthKitService: HealthKitService
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Header with activity selector and settings
                headerSection
                
                Spacer()
                
                // Coming Soon message
                VStack(spacing: RunstrSpacing.md) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.runstrGray)
                    
                    Text("Coming Soon")
                        .font(.runstrTitle)
                        .foregroundColor(.runstrWhite)
                    
                    Text("Your profile and achievements will appear here")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, RunstrSpacing.xl)
                
                Spacer()
            }
            .padding(.horizontal, RunstrSpacing.md)
            .padding(.top, RunstrSpacing.md)
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Activity selector
            HStack(spacing: 0) {
                Button("RUNSTR") { }
                    .buttonStyle(RunstrActivityButton(isSelected: true))
                
                Button("WALKSTR") { }
                    .buttonStyle(RunstrActivityButton(isSelected: false))
                
                Button("CYCLESTR") { }
                    .buttonStyle(RunstrActivityButton(isSelected: false))
            }
            .runstrCard()
            
            Spacer()
            
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
    ProfileView()
        .environmentObject(AuthenticationService())
        .environmentObject(HealthKitService())
}