//
//  ContentView.swift
//  RUNSTR IOS
//
//  Created by Dakota Brown on 7/25/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @State private var isInitializing = true
    @State private var initializationProgress = 0.0
    
    var body: some View {
        Group {
            if isInitializing {
                // Show logo screen with Nostr connection progress
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 30) {
                        // RUNSTR Logo
                        VStack(spacing: 20) {
                            Image("runstr_logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 80)
                                .foregroundColor(.white)
                            Text("RUNSTR")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        // Connection Status
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Circle()
                                    .stroke(nostrService.isConnected ? Color.white : Color.gray, lineWidth: 1)
                                    .background(Circle().fill(nostrService.isConnected ? Color.white : Color.clear))
                                    .frame(width: 8, height: 8)
                                Text(nostrService.isConnected ? "Connected to Nostr" : "Connecting to Nostr...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            // Progress bar
                            ProgressView(value: initializationProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .frame(width: 200)
                        }
                    }
                }
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .task {
            await initializeApp()
        }
    }
    
    private func initializeApp() async {
        // Show logo for minimum 2 seconds with connection progress
        let startTime = Date()
        
        // Start Nostr connection immediately
        Task {
            await nostrService.connect()
        }
        
        // Animate progress while connecting
        withAnimation(.linear(duration: 2.0)) {
            initializationProgress = 1.0
        }
        
        // Wait minimum 2.5 seconds for logo display
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < 2.5 {
            try? await Task.sleep(nanoseconds: UInt64((2.5 - elapsed) * 1_000_000_000))
        }
        
        // Check authentication status
        authService.checkAuthenticationStatus()
        
        // Hide initialization screen
        await MainActor.run {
            isInitializing = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
        .environmentObject(HealthKitService())
        .environmentObject(LocationService())
        .environmentObject(WorkoutSession())
}
