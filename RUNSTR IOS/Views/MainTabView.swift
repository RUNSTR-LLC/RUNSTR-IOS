import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var workoutSession: WorkoutSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var cashuService: CashuService
    @EnvironmentObject var streakService: StreakService
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var workoutStorage: WorkoutStorage
    
    var body: some View {
        TabView {
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("DASHBOARD")
                }
                .tag(0)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("PROFILE")
                }
                .tag(1)
            
            // League Tab
            LeagueView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("LEAGUE")
                }
                .tag(2)
            
            // Teams Tab
            TeamsView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("TEAMS")
                }
                .tag(3)
            
            // Music Tab
            MusicView()
                .tabItem {
                    Image(systemName: "music.note")
                    Text("MUSIC")
                }
                .tag(4)
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
        .environmentObject(CashuService())
        .environmentObject(StreakService())
        .environmentObject(NostrService())
        .environmentObject(WorkoutStorage())
}