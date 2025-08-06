# Comprehensive iOS Development Roadmap for RUNSTR

## Executive Summary

This roadmap outlines a phased approach for developing RUNSTR, a cardio tracking app with Bitcoin/Lightning rewards and team features, targeting TestFlight release within 6 months. The strategy prioritizes core fitness functionality and Apple compliance while gradually introducing advanced Nostr and cryptocurrency features.

## Phase 1: Foundation and Core Architecture (Weeks 1-4)

### Development Environment Setup

**Technical Stack Configuration:**
```swift
// Package.swift dependencies
dependencies: [
    .package(url: "https://github.com/zeugmaster/CashuSwift.git", .upToNextMajor(from: "1.0.0")),
    .package(url: "https://github.com/nostr-sdk/nostr-sdk-ios.git", .upToNextMajor(from: "0.3.0")),
    // Activity tracking
    .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0")
]
```

**Project Architecture:**
- **MVVM pattern** with clear separation of concerns
- **Core Data** for local persistence with CloudKit sync
- **Combine framework** for reactive programming
- **SwiftUI** for all UI components

**Key Implementation Steps:**
1. Set up GitHub repository with CI/CD using GitHub Actions
2. Configure SwiftLint and SwiftFormat for code consistency
3. Create modular architecture with separate frameworks:
   - `RunstrCore`: Business logic and models
   - `RunstrUI`: SwiftUI views and components
   - `RunstrNetworking`: API and external service integrations
   - `RunstrCrypto`: Cashu and Lightning functionality

**Apple Developer Account Setup:**
- Enroll as an **organization** (required for cryptocurrency apps)
- Configure Sign in with Apple capability
- Set up App Groups for data sharing between extensions
- Create StoreKit configuration file for subscription testing

### Core Data Models

```swift
// Core entities
@Model class Activity {
    let id: UUID
    let type: ActivityType // running, walking, cycling
    let startDate: Date
    let endDate: Date
    let distance: Double
    let calories: Int
    let route: [CLLocation]?
    let heartRateData: [HeartRateReading]?
}

@Model class User {
    let id: UUID
    let appleID: String
    let nostrPublicKey: String?
    let subscriptionLevel: SubscriptionLevel
    let currentStreak: Int
    let totalRewards: Int // in sats
}

@Model class Team {
    let id: UUID
    let name: String
    let creatorId: UUID
    let members: [User]
    let maxSize: Int
}
```

## Phase 2: Core Fitness Features (Weeks 5-8)

### Activity Tracking Implementation

**HealthKit Integration:**
```swift
class ActivityTracker: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var currentActivity: Activity?
    @Published var isTracking = false
    
    func requestPermissions() async throws {
        let types: Set<HKSampleType> = [
            .workoutType(),
            .quantityType(forIdentifier: .heartRate)!,
            .quantityType(forIdentifier: .activeEnergyBurned)!,
            .quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        try await healthStore.requestAuthorization(toShare: types, read: types)
    }
    
    func startTracking(type: ActivityType) {
        // Implementation with location tracking
        // Real-time heart rate monitoring
        // Calorie calculation
    }
}
```

**UI Components:**
- Activity selection screen (running/walking/cycling)
- Real-time tracking view with map
- Post-activity summary
- History list with basic filtering

**Streak System (Without Rewards):**
- Track consecutive days of activity
- Visual streak counter
- Local notifications for streak reminders
- Achievement badges (visual only, no crypto)

## Phase 3: Authentication and User Management (Weeks 9-10)

### Sign in with Apple Implementation

```swift
struct SignInView: View {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        VStack {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    await authManager.handleSignIn(authorization)
                case .failure(let error):
                    // Handle error
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            
            // Secondary Nostr login option (hidden initially)
            if FeatureFlags.nostrLoginEnabled {
                Button("Sign in with Nostr") {
                    // Implement in later phase
                }
                .foregroundColor(.secondary)
            }
        }
    }
}
```

**User Profile Management:**
- Basic profile screen
- Activity statistics dashboard
- Settings for notifications and privacy
- Placeholder for future wallet integration

## Phase 4: Subscription System (Weeks 11-13)

### StoreKit 2 Integration

```swift
@MainActor
class SubscriptionManager: ObservableObject {
    @Published var subscriptionLevel: SubscriptionLevel = .free
    @Published var products: [Product] = []
    
    private let productIds = [
        "com.runstr.member.monthly",      // $5
        "com.runstr.captain.monthly",     // $10
        "com.runstr.organization.monthly" // $50
    ]
    
    func loadProducts() async throws {
        products = try await Product.products(for: productIds)
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await updateSubscriptionFeatures()
                await transaction.finish()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
}
```

**Subscription Features Matrix:**
- **Free**: Basic activity tracking, 7-day history
- **Member ($5)**: Unlimited history, basic analytics, export data
- **Captain ($10)**: Create teams (up to 10 members), team chat
- **Organization ($50)**: Unlimited team size, advanced analytics, priority support

**Paywall Implementation:**
- Clean subscription selection UI
- Clear feature comparison
- Restore purchases functionality
- Proper receipt validation

## Phase 5: Basic Team Features (Weeks 14-16)

### Team Infrastructure

```swift
class TeamManager: ObservableObject {
    @Published var userTeams: [Team] = []
    @Published var selectedTeam: Team?
    
    func createTeam(name: String) async throws {
        guard subscriptionLevel >= .captain else {
            throw TeamError.subscriptionRequired
        }
        
        let team = Team(
            id: UUID(),
            name: name,
            creatorId: currentUserId,
            maxSize: subscriptionLevel == .organization ? .max : 10
        )
        
        // Save to CloudKit
        try await cloudKitManager.save(team)
    }
}
```

**Team Features:**
- Team creation and management
- Member invitation system
- Team activity leaderboard
- Basic team homepage

**Chat Implementation (Basic):**
- CloudKit-based messaging
- Text-only initially
- Push notifications for new messages
- Message history limited by subscription tier

## Phase 6: TestFlight Preparation (Weeks 17-18)

### Pre-Submission Checklist

**Technical Requirements:**
- [ ] All core features functional
- [ ] No placeholder content
- [ ] Crash-free operation
- [ ] Memory leak testing completed
- [ ] Performance optimization done

**App Store Connect Setup:**
- [ ] App metadata prepared
- [ ] Screenshots for all device sizes
- [ ] App description focusing on fitness (not crypto)
- [ ] Demo account credentials ready
- [ ] Beta testing information completed

**Compliance Documentation:**
- [ ] Privacy policy addressing data collection
- [ ] Terms of service
- [ ] Export compliance (for encryption)
- [ ] Age rating questionnaire

### TestFlight Submission Strategy

1. **Internal Testing First:**
   - Add 5-10 internal testers
   - 1-week testing period
   - Fix critical bugs

2. **External Beta:**
   - Prepare beta welcome email
   - Create feedback collection system
   - Plan for 2-week beta period
   - Target 50-100 external testers

## Phase 7: Cashu Wallet Integration (Weeks 19-22)

### Secure Wallet Implementation

```swift
class CashuWalletManager: ObservableObject {
    private let cashuSwift = CashuSwift()
    @Published var balance: Int = 0
    @Published var proofs: [Proof] = []
    
    // Use iOS Keychain for seed storage
    private func storeSeed(_ seed: String) throws {
        let data = seed.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.runstr.wallet",
            kSecAttrAccount as String: "user_seed",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WalletError.keychainError
        }
    }
    
    func claimStreakReward(day: Int) async throws {
        let rewardAmount = calculateReward(for: day)
        let tokens = try await mintTokens(amount: rewardAmount)
        proofs.append(contentsOf: tokens)
        balance += rewardAmount
    }
}
```

**Streak Rewards Implementation:**
- Progressive reward schedule (e.g., 21 sats for 7 days, 100 sats for 30 days)
- Daily claim mechanism
- Secure proof storage
- Export/backup functionality

**Compliance Considerations:**
- No in-app Bitcoin purchases
- Rewards are transferable outside app
- Clear disclosure of cryptocurrency features
- Educational content about Cashu

## Phase 8: Lightning Integration (Weeks 23-24)

### Payment Features

```swift
extension CashuWalletManager {
    func payLightningInvoice(_ invoice: String) async throws {
        let meltQuote = try await cashuSwift.getMeltQuote(
            mint: selectedMint,
            request: invoice
        )
        
        let result = try await cashuSwift.melt(
            quote: meltQuote,
            inputs: proofs,
            outputs: nil
        )
        
        if result.paid {
            // Update balance and proofs
            await updateWalletState()
        }
    }
    
    func receiveLightning(amount: Int) async throws -> String {
        // Generate Lightning invoice through mint
        let mintQuote = try await cashuSwift.getMintQuote(
            mint: selectedMint,
            amount: amount
        )
        
        return mintQuote.request // Lightning invoice
    }
}
```

**User Experience:**
- Send/receive sats within the app
- QR code scanning for invoices
- Transaction history
- Fee transparency

## Phase 9: Advanced Features and Polish (Weeks 25-26)

### Nostr Integration (Advanced)

```swift
class NostrManager: ObservableObject {
    private let nostrSDK = NostrSDK()
    @Published var isConnected = false
    
    func publishActivity(_ activity: Activity) async throws {
        guard let nostrKeys = loadNostrKeys() else { return }
        
        let event = NostrEvent(
            kind: 30001, // Custom activity kind
            content: activity.toJSON(),
            tags: [
                ["d", "runstr-activity"],
                ["type", activity.type.rawValue],
                ["distance", String(activity.distance)]
            ]
        )
        
        try await nostrSDK.publish(event, to: relays)
    }
}
```

### Events and Challenges

**Team Events System:**
- Monthly challenges
- Custom team goals
- Leaderboards with rewards
- Achievement system

## Production Launch Strategy

### App Store Submission (Month 7)

**Marketing Description Focus:**
- Emphasize fitness tracking features
- Mention team collaboration
- Briefly note "rewards" without crypto specifics
- Highlight subscription benefits

**Geographic Strategy:**
- Initial launch in crypto-friendly jurisdictions
- Gradual expansion based on regulatory clarity
- US launch leveraging new payment flexibility

### Post-Launch Roadmap

**Version 1.1 (Month 8):**
- Bug fixes from user feedback
- Performance improvements
- Additional activity types

**Version 1.2 (Month 9):**
- Apple Watch companion app
- Widget support
- Shortcuts integration

**Version 2.0 (Month 12):**
- Full Nostr social features
- Multi-mint support
- Advanced analytics dashboard
- AI-powered coaching

## Key Success Metrics

**Technical KPIs:**
- Crash-free rate > 99.5%
- App launch time < 2 seconds
- Memory usage < 150MB
- Battery drain < 5% per hour during tracking

**Business KPIs:**
- Monthly Active Users (MAU)
- Subscription conversion rate (target: 5%)
- User retention (30-day: 40%, 90-day: 25%)
- Average session duration > 5 minutes

## Risk Mitigation Strategies

**Apple Review Risks:**
- Conservative initial feature set
- Clear organization enrollment
- Comprehensive demo materials
- Legal review of crypto features

**Technical Risks:**
- Thorough testing across iOS versions
- Graceful degradation for older devices
- Offline functionality
- Regular security audits

**Market Risks:**
- Focus on fitness value proposition
- Crypto features as bonus, not core
- Strong community building
- Responsive user support

This roadmap provides a structured path to TestFlight and beyond, balancing innovation with Apple's guidelines while building a sustainable fitness platform with unique Bitcoin rewards functionality.