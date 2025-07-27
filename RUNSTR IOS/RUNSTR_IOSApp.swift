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
    @StateObject private var walletService = BitcoinWalletService()
    @StateObject private var nostrService = NostrService()
    @StateObject private var cashuService = CashuService()
    
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
                .environmentObject(walletService)
                .environmentObject(nostrService)
                .environmentObject(cashuService)
                .preferredColorScheme(.dark)
                .task {
                    // Configure workout session with services first
                    workoutSession.configure(
                        healthKitService: healthKitService,
                        locationService: locationService
                    )
                    
                    // Request permissions on app startup
                    await requestInitialPermissions()
                    
                    // Initialize Cashu connection
                    await cashuService.connectToMint()
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
