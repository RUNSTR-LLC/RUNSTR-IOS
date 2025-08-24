import SwiftUI

/// Ultra-simple main tab view with clean navigation
struct SimpleMainTabView: View {
    @StateObject private var simpleHealthKit = SimpleHealthKitService()
    
    var body: some View {
        TabView {
            
            // Dashboard - Show all workouts from all apps
            SimpleDashboardView()
                .environmentObject(simpleHealthKit)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Dashboard")
                }
            
            // Start Workout - Create new workouts
            SimpleWorkoutView()
                .environmentObject(simpleHealthKit)
                .tabItem {
                    Image(systemName: "play.circle.fill")
                    Text("Workout")
                }
            
            // Keep your existing profile/settings
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
            
            // Keep your existing settings
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .accentColor(.orange)
        .task {
            // Request permissions when app launches
            if !simpleHealthKit.isAuthorized {
                let authorized = await simpleHealthKit.requestAuthorization()
                if authorized {
                    await simpleHealthKit.loadAllWorkouts()
                }
            }
        }
    }
}

#Preview {
    SimpleMainTabView()
}