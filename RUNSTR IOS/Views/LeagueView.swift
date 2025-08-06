import SwiftUI

struct LeagueView: View {
    @State private var showingSettings = false
    
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
    LeagueView()
}