import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var workoutSession: WorkoutSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var workoutStorage: WorkoutStorage
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Activity Tab - always loaded (default tab)
            DashboardView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("ACTIVITY")
                }
                .tag(0)
            
            // Profile Tab - only load when selected to prevent startup delay
            Group {
                if selectedTab == 1 {
                    ProfileView()
                } else {
                    Color.runstrBackground // Placeholder to prevent loading
                }
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("PROFILE")
            }
            .tag(1)
        }
        .accentColor(.runstrWhite)
        .background(Color.runstrBackground)
        .onAppear {
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.runstrBackground)
            
            // Normal state
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.runstrGray)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(Color.runstrGray),
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
            
            // Selected state
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.runstrWhite)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color.runstrWhite),
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(WorkoutSession())
        .environmentObject(LocationService())
        .environmentObject(HealthKitService())
        .environmentObject(AuthenticationService())
        .environmentObject(NostrService())
        .environmentObject(WorkoutStorage())
}