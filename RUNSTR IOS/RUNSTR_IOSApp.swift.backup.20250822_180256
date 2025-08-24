//
//  RUNSTR_IOSApp.swift
//  RUNSTR IOS
//
//  Created by Dakota Brown on 7/25/25.
//

import SwiftUI

@main
struct RUNSTR_IOSApp: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var healthKitService = HealthKitService()
    @StateObject private var locationService = LocationService()
    @StateObject private var workoutSession = WorkoutSession()
    @StateObject private var workoutStorage = WorkoutStorage()
    @StateObject private var nostrService = NostrService() // Now lightweight
    @StateObject private var unitPreferences = UnitPreferencesService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(healthKitService)
                .environmentObject(locationService)
                .environmentObject(workoutSession)
                .environmentObject(nostrService)
                .environmentObject(workoutStorage)
                .environmentObject(unitPreferences)
                .preferredColorScheme(.dark)
                .task {
                    // Configure workout session with services
                    workoutSession.configure(
                        healthKitService: healthKitService,
                        locationService: locationService
                    )
                }
        }
    }
    
    @MainActor
    private func requestInitialPermissions() async {
        // Request HealthKit authorization
        let _ = await healthKitService.requestAuthorization()
        
        // Request location permission
        locationService.requestLocationPermission()
        
        print("✅ Initial permissions requested")
    }
}
