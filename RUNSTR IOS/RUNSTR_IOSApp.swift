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
    @StateObject private var subscriptionService = SubscriptionService()
    @StateObject private var nostrService = NostrService()
    @StateObject private var cashuService = CashuService()
    @StateObject private var streakService = StreakService()
    @StateObject private var workoutStorage = WorkoutStorage()
    @StateObject private var teamService = TeamService()
    @StateObject private var eventService = EventService()
    
    init() {
        // Configuration will be done in onAppear
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(healthKitService)
                .environmentObject(locationService)
                .environmentObject(workoutSession)
                .environmentObject(subscriptionService)
                .environmentObject(nostrService)
                .environmentObject(cashuService)
                .environmentObject(streakService)
                .environmentObject(workoutStorage)
                .environmentObject(teamService)
                .environmentObject(eventService)
                .preferredColorScheme(.dark)
                .task {
                    // Configure workout session with services first
                    workoutSession.configure(
                        healthKitService: healthKitService,
                        locationService: locationService
                    )
                    
                    // Authentication service no longer needs NostrService configuration
                    
                    // Request permissions on app startup
                    await requestInitialPermissions()
                    
                    // Initialize Cashu connection
                    await cashuService.connectToMint()
                    
                    // Initialize team stats aggregator
                    teamService.setupStatsAggregator(
                        healthKitService: healthKitService,
                        workoutStorage: workoutStorage
                    )
                    
                    // Schedule periodic team stats updates
                    teamService.scheduleStatsUpdates()
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
