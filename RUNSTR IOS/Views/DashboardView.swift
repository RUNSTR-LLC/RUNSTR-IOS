import SwiftUI
import HealthKit

struct DashboardView: View {
    @EnvironmentObject var workoutSession: WorkoutSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var cashuService: CashuService
    @EnvironmentObject var streakService: StreakService
    @EnvironmentObject var nostrService: NostrService
    @EnvironmentObject var workoutStorage: WorkoutStorage
    
    @State private var selectedActivityType: ActivityType = .running
    @State private var showingWorkoutView = false
    @State private var showingWalletView = false
    @State private var showingSettingsView = false
    @State private var showingSummary = false
    @State private var completedWorkout: Workout?
    @State private var recentWorkouts: [HKWorkout] = []
    
    // Goal tracking state
    @State private var selectedGoal: DistanceGoal = .none
    @State private var showingGoals = false
    
    // Weekly rewards state
    @State private var showingWeeklyRewards = false
    
    // Toast notification state
    @State private var showingRewardToast = false
    @State private var rewardToastMessage = ""
    
    // Membership state
    @State private var showingMembership = false
    @State private var selectedMembershipTier: SubscriptionTier?
    @State private var showingComingSoon = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header with activity selector and settings
                    headerSection
                    
                    // Profile avatar (right side)
                    
                    // Metrics grid (4 cards)
                    metricsSection
                    
                    // Start Run button
                    startRunButton
                    
                    // Goals section
                    goalsSection
                    
                    // Weekly Rewards Summary
                    weeklyRewardsSection
                    
                    // Membership section
                    membershipSection
                    
                    Spacer(minLength: 100) // Bottom padding for tab bar
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingWorkoutView) {
            WorkoutView(activityType: selectedActivityType)
        }
        .sheet(isPresented: $showingWalletView) {
            WalletView()
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showingSummary) {
            if let workout = completedWorkout {
                WorkoutSummaryView(workout: workout)
                    .environmentObject(workoutStorage)
            }
        }
        .overlay(
            ToastView(message: rewardToastMessage, isShowing: showingRewardToast),
            alignment: .top
        )
        .overlay(
            ComingSoonView(isPresented: $showingComingSoon)
                .opacity(showingComingSoon ? 1 : 0)
                .allowsHitTesting(showingComingSoon)
        )
        .onAppear {
            loadRecentWorkouts()
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Activity selector
            HStack(spacing: 0) {
                Button("RUNSTR") { 
                    selectedActivityType = .running
                }
                .buttonStyle(RunstrActivityButton(isSelected: selectedActivityType == .running))
                
                Button("WALKSTR") { 
                    selectedActivityType = .walking
                }
                .buttonStyle(RunstrActivityButton(isSelected: selectedActivityType == .walking))
                
                Button("CYCLESTR") { 
                    selectedActivityType = .cycling
                }
                .buttonStyle(RunstrActivityButton(isSelected: selectedActivityType == .cycling))
            }
            .runstrCard()
            
            Spacer()
            
            // Settings button
            Button {
                showingSettingsView = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
            }
        }
    }
    
    private var metricsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: RunstrSpacing.md) {
            // Distance card
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "location")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Distance")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                HStack(alignment: .bottom, spacing: RunstrSpacing.xs) {
                    Text(workoutSession.isActive ? String(format: "%.2f", workoutSession.currentDistance / 1000) : "0.00")
                        .font(.runstrMetric)
                        .foregroundColor(.runstrWhite)
                    
                    if selectedGoal != .none && workoutSession.isActive {
                        Text("/ \(String(format: "%.1f", selectedGoal.distanceInMeters / 1000))")
                            .font(.runstrSmall)
                            .foregroundColor(.runstrGray)
                    }
                }
                
                Text("mi")
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
            
            // Time card
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "clock")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Time")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                Text(workoutSession.isActive ? formatTime(workoutSession.elapsedTime) : "00:00")
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
            
            // Pace card
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "speedometer")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Pace")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                Text(workoutSession.isActive ? String(format: "%.1f", workoutSession.currentPace) : "--")
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
                
                Text("min/mi")
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
            
            // Elevation card
            VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                HStack {
                    Image(systemName: "triangle")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    Text("Elevation")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                }
                
                Text(workoutSession.isActive ? String(format: "%.0f", locationService.getElevationGain() * 3.28084) : "0")
                    .font(.runstrMetric)
                    .foregroundColor(.runstrWhite)
                
                Text("ft")
                    .font(.runstrSmall)
                    .foregroundColor(.runstrGray)
            }
            .padding(RunstrSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .runstrCard()
        }
    }
    
    private var startRunButton: some View {
        VStack(spacing: RunstrSpacing.md) {
            if workoutSession.isActive {
                // Show workout controls when active
                // Pause/Resume button
                Button {
                    if workoutSession.isPaused {
                        resumeWorkout()
                    } else {
                        pauseWorkout()
                    }
                } label: {
                    HStack {
                        Image(systemName: workoutSession.isPaused ? "play.fill" : "pause.fill")
                        Text(workoutSession.isPaused ? "Resume" : "Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RunstrSpacing.lg)
                }
                .buttonStyle(RunstrSecondaryButton())
                
                // Finish workout button
                Button {
                    endWorkout()
                } label: {
                    Text("Finish Workout")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RunstrSpacing.lg)
                }
                .buttonStyle(RunstrPrimaryButton())
            } else {
                // Show start button when inactive
                Button {
                    print("🎯 Start \(selectedActivityType.displayName) button tapped")
                    startWorkout()
                } label: {
                    Text("Start \(selectedActivityType.displayName)")
                        .font(.runstrSubheadline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RunstrSpacing.lg)
                        .background(Color.runstrWhite)
                        .cornerRadius(RunstrRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingGoals.toggle()
                }
            } label: {
                HStack {
                    Text("Goals")
                        .font(.runstrSubheadline)
                        .foregroundColor(.runstrWhite)
                    
                    if selectedGoal != .none {
                        Text("(\(selectedGoal.displayName))")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                    
                    Spacer()
                    Image(systemName: showingGoals ? "chevron.up" : "chevron.down")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                        .animation(.easeInOut(duration: 0.3), value: showingGoals)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if showingGoals {
                VStack(spacing: RunstrSpacing.sm) {
                    ForEach(DistanceGoal.allCases, id: \.self) { goal in
                        Button {
                            selectedGoal = goal
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingGoals = false
                            }
                        } label: {
                            HStack {
                                Text(goal.displayName)
                                    .font(.runstrBody)
                                    .foregroundColor(selectedGoal == goal ? .runstrWhite : .runstrGray)
                                Spacer()
                                if selectedGoal == goal {
                                    Image(systemName: "checkmark")
                                        .font(.runstrCaption)
                                        .foregroundColor(.runstrWhite)
                                }
                            }
                            .padding(.vertical, RunstrSpacing.sm)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if goal != DistanceGoal.allCases.last {
                            Rectangle()
                                .fill(Color.runstrGray.opacity(0.2))
                                .frame(height: 1)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var weeklyRewardsSection: some View {
        let summary = getWeeklyWorkoutsSummary()
        
        return VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingWeeklyRewards.toggle()
                }
            } label: {
                HStack {
                    Text("Weekly Rewards Summary")
                        .font(.runstrSubheadline)
                        .foregroundColor(.runstrWhite)
                    
                    Text("(\(summary.totalSats) sats)")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    
                    Spacer()
                    Image(systemName: showingWeeklyRewards ? "chevron.up" : "chevron.down")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                        .animation(.easeInOut(duration: 0.3), value: showingWeeklyRewards)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if showingWeeklyRewards {
                VStack(spacing: RunstrSpacing.sm) {
                    HStack {
                        Text("This Week")
                            .font(.runstrBody)
                            .foregroundColor(.runstrGray)
                        Spacer()
                        Text("\(summary.workouts.count) workouts • \(summary.totalSats) sats")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                    
                    Rectangle()
                        .fill(Color.runstrGray.opacity(0.2))
                        .frame(height: 1)
                    
                    ForEach(getWeeklyDaysSummary(), id: \.day) { daySummary in
                        HStack {
                            Text(daySummary.day)
                                .font(.runstrBody)
                                .foregroundColor(.runstrWhite)
                            
                            Spacer()
                            
                            HStack(spacing: RunstrSpacing.xs) {
                                if let workout = daySummary.workout {
                                    Image(systemName: workout.activityType.systemImageName)
                                        .font(.runstrCaption)
                                        .foregroundColor(.runstrGray)
                                    
                                    Text("50 sats")
                                        .font(.runstrCaption)
                                        .foregroundColor(.runstrWhite)
                                } else {
                                    Text("No workout")
                                        .font(.runstrCaption)
                                        .foregroundColor(.runstrGray)
                                }
                            }
                        }
                        .padding(.vertical, RunstrSpacing.xs)
                        
                        if daySummary.day != getWeeklyDaysSummary().last?.day {
                            Rectangle()
                                .fill(Color.runstrGray.opacity(0.1))
                                .frame(height: 0.5)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var membershipSection: some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingMembership.toggle()
                    // Reset selected tier when closing
                    if !showingMembership {
                        selectedMembershipTier = nil
                    }
                }
            } label: {
                HStack {
                    Text("Membership")
                        .font(.runstrSubheadline)
                        .foregroundColor(.runstrWhite)
                    
                    // Show current tier if available
                    if let currentTier = authService.currentUser?.subscriptionTier, currentTier != .none {
                        Text("(\(currentTier.displayName))")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                    
                    Spacer()
                    Image(systemName: showingMembership ? "chevron.up" : "chevron.down")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                        .animation(.easeInOut(duration: 0.3), value: showingMembership)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if showingMembership {
                if let selectedTier = selectedMembershipTier {
                    // Show tier benefits detail view
                    tierBenefitsView(for: selectedTier)
                } else {
                    // Show tier selection
                    tierSelectionView
                }
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var workoutStartSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Start Workout")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                ForEach(ActivityType.allCases, id: \.self) { activityType in
                    Button {
                        selectedActivityType = activityType
                        showingWorkoutView = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: activityType.systemImageName)
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                            
                            Text(activityType.displayName)
                                .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    private var currentWorkoutSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Active Workout")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DISTANCE")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f", workoutSession.currentDistance / 1000))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("km")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("TIME")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                        Text(formatTime(workoutSession.elapsedTime))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PACE")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f", workoutSession.currentPace))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("min/km")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if let heartRate = healthKitService.currentHeartRate {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("HEART RATE")
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundColor(.gray)
                            Text("\(Int(heartRate))")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("bpm")
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var recentWorkoutsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Recent")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 1) {
                if recentWorkouts.isEmpty {
                    Text("No recent workouts")
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundColor(.gray)
                        .padding(.vertical, 40)
                } else {
                    ForEach(Array(recentWorkouts.prefix(3).enumerated()), id: \.offset) { index, workout in
                        WorkoutSummaryCard(
                            activityType: ActivityType.from(hkWorkout: workout),
                            distance: (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000, // Convert to km
                            duration: workout.duration,
                            satsEarned: calculateSatsEarned(distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0, duration: workout.duration),
                            date: workout.startDate
                        )
                    }
                }
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func loadRecentWorkouts() {
        healthKitService.fetchRecentWorkouts { workouts in
            self.recentWorkouts = workouts
        }
    }
    
    private func calculateSatsEarned(distance: Double, duration: TimeInterval) -> Int {
        // Basic calculation: 100 sats per km + time bonus
        let distanceKm = distance / 1000
        let baseSats = Int(distanceKm * 100)
        let timeBonus = Int(duration / 60) // 1 sat per minute
        return baseSats + timeBonus
    }
    
    // MARK: - Workout Control Functions
    
    private func startWorkout() {
        // Use a test user ID if no user is logged in
        let userID = authService.currentUser?.id ?? "test-user-123"
        
        print("🎯 Starting workout with userID: \(userID)")
        if selectedGoal != .none {
            print("🎯 Goal: \(selectedGoal.displayName) (\(selectedGoal.distanceInMeters)m)")
        }
        
        // Configure WorkoutSession with required services
        workoutSession.configure(healthKitService: healthKitService, locationService: locationService)
        
        Task {
            locationService.startTracking()
            let success = await workoutSession.startWorkout(activityType: selectedActivityType, userID: userID)
            if !success {
                print("❌ Failed to start workout session")
            } else {
                // Start monitoring for goal completion if goal is set
                if selectedGoal != .none {
                    startGoalMonitoring()
                }
            }
        }
    }
    
    private func pauseWorkout() {
        workoutSession.pauseWorkout()
        locationService.pauseTracking()
    }
    
    private func resumeWorkout() {
        workoutSession.resumeWorkout()
        locationService.resumeTracking()
    }
    
    private func endWorkout() {
        Task {
            locationService.stopTracking()
            
            if var completedWorkout = await workoutSession.endWorkout() {
                // Set reward amount based on daily limit
                let todaysWorkouts = getTodaysWorkouts()
                let isFirstWorkoutToday = todaysWorkouts.isEmpty
                completedWorkout.rewardAmount = isFirstWorkoutToday ? 50 : 0
                
                // 1. Save to HealthKit
                healthKitService.saveWorkout(completedWorkout) { success in
                    print("Workout saved to HealthKit: \(success)")
                }
                
                // 2. Update streak and award Cashu tokens (only if eligible for reward)
                if completedWorkout.rewardAmount > 0 {
                    await awardWorkoutReward(for: completedWorkout)
                }
                
                // 3. Create Nostr event (if connected)
                await publishWorkoutToNostr(completedWorkout)
                
                // 4. Show reward toast if earned
                if completedWorkout.rewardAmount > 0 {
                    await showRewardToast(amount: completedWorkout.rewardAmount)
                }
                
                // 5. Store completed workout and show summary
                self.completedWorkout = completedWorkout
                self.showingSummary = true
                
                // 6. Reset goal after workout completion
                self.selectedGoal = .none
            }
        }
    }
    
    /// Award Cashu tokens based on workout performance and streak
    private func awardWorkoutReward(for workout: Workout) async {
        guard let user = authService.currentUser else {
            print("❌ No authenticated user for reward")
            return
        }
        
        // Calculate base workout reward
        let workoutReward = calculateWorkoutReward(workout)
        
        // Update streak and get streak reward
        streakService.recordWorkout(date: workout.startTime)
        let streakReward = streakService.streakRewardEarned
        
        // Check for weekly completion bonus
        let weeklyBonus = streakService.hasCompletedWeeklyChallenge() ? streakService.getWeeklyCompletionBonus() : 0
        
        let totalReward = workoutReward + streakReward + weeklyBonus
        
        guard totalReward > 0 else {
            print("❌ No reward calculated for workout")
            return
        }
        
        do {
            // Mint Cashu tokens for workout reward
            if workoutReward > 0 {
                let workoutTokens = try await cashuService.requestTokens(amount: workoutReward)
                print("✅ Minted \(workoutReward) sats for workout completion")
            }
            
            // Mint additional tokens for streak
            if streakReward > 0 {
                let streakTokens = try await cashuService.requestTokens(amount: streakReward)
                print("🔥 Minted \(streakReward) sats for day \(streakService.currentStreak) streak!")
            }
            
            // Mint weekly completion bonus
            if weeklyBonus > 0 {
                let bonusTokens = try await cashuService.requestTokens(amount: weeklyBonus)
                print("🏆 Minted \(weeklyBonus) sats for completing weekly challenge!")
            }
            
            // Update user stats
            if var currentUser = authService.currentUser {
                currentUser.stats.recordWorkout(workout, streakReward: streakReward + weeklyBonus)
                currentUser.stats.updateStreak(current: streakService.currentStreak, longest: streakService.currentStreak)
                
                if weeklyBonus > 0 {
                    currentUser.stats.recordWeeklyStreakCompletion(bonus: weeklyBonus)
                }
                
                // Save updated user (this would normally go through AuthenticationService)
                // authService.updateCurrentUser(currentUser)
            }
            
            print("✅ Total reward: \(totalReward) sats (\(workoutReward) workout + \(streakReward) streak + \(weeklyBonus) bonus)")
            print("🏃‍♂️ Distance: \(String(format: "%.2f", workout.distance/1000))km")
            print("⏱️ Duration: \(formatTime(workout.duration))")
            print("🔥 Streak: \(streakService.getStreakStatusMessage())")
            
        } catch {
            print("❌ Failed to award workout reward: \(error)")
        }
    }
    
    /// Calculate reward amount based on workout metrics
    private func calculateWorkoutReward(_ workout: Workout) -> Int {
        let distanceKm = workout.distance / 1000
        let durationMinutes = workout.duration / 60
        
        // Base reward calculation
        let distanceReward = Int(distanceKm * 50) // 50 sats per km
        let timeReward = Int(durationMinutes * 5) // 5 sats per minute
        let baseReward = max(100, distanceReward + timeReward) // Minimum 100 sats
        
        // Bonus multipliers
        var bonusMultiplier = 1.0
        
        // Distance bonus
        if distanceKm >= 10.0 {
            bonusMultiplier += 0.5 // 50% bonus for 10k+
        } else if distanceKm >= 5.0 {
            bonusMultiplier += 0.25 // 25% bonus for 5k+
        }
        
        // Pace bonus (under 5 min/km is good pace)
        if workout.averagePace < 5.0 {
            bonusMultiplier += 0.3 // 30% bonus for good pace
        }
        
        return Int(Double(baseReward) * bonusMultiplier)
    }
    
    /// Publish completed workout to Nostr relays
    private func publishWorkoutToNostr(_ workout: Workout) async {
        guard let user = authService.currentUser else {
            print("❌ No authenticated user for Nostr publishing")
            return
        }
        
        // Check if NostrService is connected to relays
        if !nostrService.isConnected {
            print("⚠️ NostrService not connected to relays, attempting connection...")
            await nostrService.connectToRelays()
            
            // Wait briefly and check connection again
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            guard nostrService.isConnected else {
                print("❌ Failed to connect to Nostr relays for workout publishing")
                return
            }
        }
        
        // Publish workout event with public privacy level
        let success = await nostrService.publishWorkoutEvent(
            workout, 
            privacyLevel: .public,
            teamID: nil, // TODO: Add team support if user is in a team
            challengeID: nil // TODO: Add challenge support if workout is part of event
        )
        
        if success {
            print("✅ Successfully published workout to Nostr!")
            print("   🏃‍♂️ Activity: \(workout.activityType.displayName)")
            print("   📏 Distance: \(String(format: "%.2f", workout.distance/1000))km")
            print("   ⏱️ Duration: \(formatTime(workout.duration))")
            print("   🔗 Event published to \(nostrService.connectedRelays.count) relays")
        } else {
            print("❌ Failed to publish workout to Nostr relays")
        }
    }
    
    // MARK: - Goal Monitoring Functions
    
    private func startGoalMonitoring() {
        guard selectedGoal != .none else { return }
        
        print("🎯 Starting goal monitoring for \(selectedGoal.displayName)")
        
        // Create a timer to check distance every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            guard workoutSession.isActive && !workoutSession.isPaused else {
                timer.invalidate()
                return
            }
            
            if checkGoalCompletion() {
                timer.invalidate()
                goalReached()
            }
        }
    }
    
    private func checkGoalCompletion() -> Bool {
        guard selectedGoal != .none else { return false }
        
        let currentDistance = workoutSession.currentDistance
        let goalDistance = selectedGoal.distanceInMeters
        
        return currentDistance >= goalDistance
    }
    
    private func goalReached() {
        print("🎯 Goal reached! \(selectedGoal.displayName) completed")
        
        // Show goal completion message (you could add an alert here)
        
        // Automatically finish the workout
        Task {
            await MainActor.run {
                endWorkout()
            }
        }
    }
    
    // MARK: - Reward Helper Functions
    
    private func getTodaysWorkouts() -> [Workout] {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? today
        
        return workoutStorage.workouts.filter { workout in
            workout.startTime >= startOfDay && workout.startTime < endOfDay
        }
    }
    
    private func showRewardToast(amount: Int) async {
        await MainActor.run {
            rewardToastMessage = "🎉 Earned \(amount) sats!"
            showingRewardToast = true
            
            // Auto-dismiss after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    showingRewardToast = false
                }
            }
        }
    }
    
    private func getWeeklyWorkoutsSummary() -> (workouts: [Workout], totalSats: Int) {
        let weeklyWorkouts = workoutStorage.getWorkouts(for: .week)
        let calendar = Calendar.current
        
        // Group workouts by day and only count first workout per day
        var dailyFirstWorkouts: [Workout] = []
        var dailyWorkoutsByDate: [String: [Workout]] = [:]
        
        // Group workouts by date
        for workout in weeklyWorkouts {
            let dateKey = calendar.startOfDay(for: workout.startTime).ISO8601Format()
            if dailyWorkoutsByDate[dateKey] == nil {
                dailyWorkoutsByDate[dateKey] = []
            }
            dailyWorkoutsByDate[dateKey]!.append(workout)
        }
        
        // Get first workout from each day
        for (_, dayWorkouts) in dailyWorkoutsByDate {
            if let firstWorkout = dayWorkouts.min(by: { $0.startTime < $1.startTime }) {
                dailyFirstWorkouts.append(firstWorkout)
            }
        }
        
        let totalSats = dailyFirstWorkouts.count * 50 // 50 sats per day
        return (workouts: dailyFirstWorkouts, totalSats: totalSats)
    }
    
    private func getWeeklyDaysSummary() -> [DaySummary] {
        let calendar = Calendar.current
        let now = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
        let startOfWeek = weekInterval.start
        
        let workoutsSummary = getWeeklyWorkoutsSummary()
        
        var daysSummary: [DaySummary] = []
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { continue }
            
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE" // Mon, Tue, Wed, etc.
            let dayName = dayFormatter.string(from: date)
            
            // Find first workout for this day
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let dayWorkout = workoutsSummary.workouts.first { workout in
                workout.startTime >= dayStart && workout.startTime < dayEnd
            }
            
            daysSummary.append(DaySummary(day: dayName, workout: dayWorkout))
        }
        
        return daysSummary
    }
    
    // MARK: - Membership Helper Views
    
    private var tierSelectionView: some View {
        VStack(spacing: RunstrSpacing.sm) {
            ForEach(SubscriptionTier.allCases.filter { $0 != .none }, id: \.self) { tier in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedMembershipTier = tier
                    }
                } label: {
                    HStack {
                        Image(systemName: tier.systemImageName)
                            .font(.runstrBody)
                            .foregroundColor(.runstrWhite)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                            Text(tier.displayName)
                                .font(.runstrBody)
                                .foregroundColor(.runstrWhite)
                            
                            Text("$\(String(format: "%.2f", tier.monthlyPrice))/month")
                                .font(.runstrCaption)
                                .foregroundColor(.runstrGray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrGray)
                    }
                    .padding(.vertical, RunstrSpacing.sm)
                }
                .buttonStyle(PlainButtonStyle())
                
                if tier != SubscriptionTier.allCases.filter({ $0 != .none }).last {
                    Rectangle()
                        .fill(Color.runstrGray.opacity(0.2))
                        .frame(height: 1)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func tierBenefitsView(for tier: SubscriptionTier) -> some View {
        VStack(alignment: .leading, spacing: RunstrSpacing.md) {
            // Header with back button
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedMembershipTier = nil
                    }
                } label: {
                    HStack(spacing: RunstrSpacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.runstrCaption)
                        Text("Back")
                            .font(.runstrCaption)
                    }
                    .foregroundColor(.runstrGray)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            
            // Tier details
            HStack {
                Image(systemName: tier.systemImageName)
                    .font(.title3)
                    .foregroundColor(.runstrWhite)
                
                VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                    Text(tier.displayName)
                        .font(.runstrSubheadline)
                        .foregroundColor(.runstrWhite)
                    
                    Text("$\(String(format: "%.2f", tier.monthlyPrice))/month")
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                }
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.runstrGray.opacity(0.2))
                .frame(height: 1)
            
            // Features list
            VStack(alignment: .leading, spacing: RunstrSpacing.sm) {
                ForEach(tier.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: RunstrSpacing.sm) {
                        Image(systemName: "checkmark")
                            .font(.runstrCaption)
                            .foregroundColor(.runstrWhite)
                            .frame(width: 12)
                        
                        Text(feature)
                            .font(.runstrBody)
                            .foregroundColor(.runstrWhite)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                }
            }
            
            // Subscribe button
            Button {
                showingComingSoon = true
            } label: {
                Text("Subscribe to \(tier.displayName)")
                    .font(.runstrBody)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RunstrSpacing.md)
                    .background(Color.runstrWhite)
                    .cornerRadius(RunstrRadius.sm)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }
}

struct WorkoutSummaryCard: View {
    let activityType: ActivityType
    let distance: Double
    let duration: TimeInterval
    let satsEarned: Int
    let date: Date
    
    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: activityType.systemImageName)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activityType.displayName)
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.white)
                
                Text(formatter.string(from: date))
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f km", distance))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    Text("\(satsEarned)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.white.opacity(0.02))
        )
    }
}

enum DistanceGoal: CaseIterable {
    case none
    case oneK
    case fiveK
    case tenK
    
    var displayName: String {
        switch self {
        case .none: return "No Goal"
        case .oneK: return "1K"
        case .fiveK: return "5K"
        case .tenK: return "10K"
        }
    }
    
    var distanceInMeters: Double {
        switch self {
        case .none: return 0
        case .oneK: return 1000
        case .fiveK: return 5000
        case .tenK: return 10000
        }
    }
}

struct DaySummary {
    let day: String
    let workout: Workout?
}

struct ToastView: View {
    let message: String
    let isShowing: Bool
    
    var body: some View {
        VStack {
            if isShowing {
                HStack(spacing: RunstrSpacing.sm) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.title3)
                        .foregroundColor(.runstrWhite)
                    
                    Text(message)
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, RunstrSpacing.lg)
                .padding(.vertical, RunstrSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: RunstrRadius.md)
                        .fill(Color.green)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            Spacer()
        }
        .padding(.horizontal, RunstrSpacing.md)
        .padding(.top, RunstrSpacing.lg)
        .animation(.easeInOut(duration: 0.5), value: isShowing)
    }
}

struct ComingSoonView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Modal content
            VStack(spacing: RunstrSpacing.lg) {
                // Icon
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.runstrWhite)
                
                // Title
                Text("Subscriptions Coming Soon!")
                    .font(.runstrTitle)
                    .foregroundColor(.runstrWhite)
                    .multilineTextAlignment(.center)
                
                // Message
                VStack(spacing: RunstrSpacing.sm) {
                    Text("We're putting the finishing touches on our subscription system.")
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                        .multilineTextAlignment(.center)
                    
                    Text("Sign up with your email to get notified when subscriptions are available!")
                        .font(.runstrBody)
                        .foregroundColor(.runstrGray)
                        .multilineTextAlignment(.center)
                }
                
                // Action buttons
                VStack(spacing: RunstrSpacing.md) {
                    Button {
                        // TODO: Add email signup functionality
                        isPresented = false
                    } label: {
                        Text("Notify Me")
                            .font(.runstrBody)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RunstrSpacing.md)
                            .background(Color.runstrWhite)
                            .cornerRadius(RunstrRadius.sm)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        isPresented = false
                    } label: {
                        Text("Got It")
                            .font(.runstrBody)
                            .foregroundColor(.runstrGray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(RunstrSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: RunstrRadius.lg)
                    .fill(Color.runstrBackground)
                    .stroke(Color.runstrGray.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, RunstrSpacing.lg)
            .scaleEffect(isPresented ? 1.0 : 0.8)
            .opacity(isPresented ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.3), value: isPresented)
        }
    }
}

extension ActivityType {
    static func from(hkWorkout: HKWorkout) -> ActivityType {
        switch hkWorkout.workoutActivityType {
        case .running:
            return .running
        case .walking:
            return .walking
        case .cycling:
            return .cycling
        default:
            return .running // Default fallback
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(WorkoutSession())
        .environmentObject(LocationService())
        .environmentObject(HealthKitService())
        .environmentObject(AuthenticationService())
        .environmentObject(CashuService())
        .environmentObject(StreakService())
        .environmentObject(NostrService())
        .environmentObject(WorkoutStorage())
}