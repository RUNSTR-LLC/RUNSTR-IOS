# RUNSTR iOS App

## Project Overview

RUNSTR is a fitness club monetization platform that transforms fitness communities into thriving businesses. Organizations and influencers use RUNSTR to generate recurring revenue through member subscriptions and virtual event ticket sales, while members earn Bitcoin rewards for their workouts.

**Platform Value Proposition:**
- **For Organizations/Influencers**: Turn your fitness following into a sustainable business with monthly recurring revenue and virtual event income
- **For Members**: Keep using your favorite fitness apps (Apple Watch, Garmin, Strava) while earning Bitcoin rewards through team memberships

**Key Features:**
- Universal workout sync via HealthKit (all workout types supported)
- Three-tier subscription model (Free, Member: $3.99/mo, Captain: $19.99/mo, Organization: $49.99/mo)
- Team creation and management platform
- Virtual fitness events with ticket sales
- Bitcoin rewards via Lightning/Cashu
- Revenue sharing for team captains ($1 per member/month)
- 100% event ticket revenue for organizers

## Technical Architecture

### Frontend
- **Framework**: SwiftUI + UIKit for iOS 15.0+
- **Architecture**: MVVM with ObservableObject services
- **State Management**: @StateObject, @EnvironmentObject, @Published

### Key Integrations
- **HealthKit**: Universal workout data sync (running, cycling, walking, strength, yoga, swimming)
- **Apple Watch**: Seamless workout tracking
- **Garmin/Strava**: Coming soon - additional data sources
- **Zebedee Lightning**: Bitcoin rewards and payments
- **Cashu Protocol**: Privacy-preserving ecash system
- **StoreKit 2**: Subscription management
- **CloudKit**: Team data synchronization

### Data Models
- `User`: Authentication, subscription tier, wallet, team memberships
- `Workout`: Synced from HealthKit, all activity types
- `Team`: Captain-managed groups with revenue tracking
- `Event`: Virtual competitions with ticket sales
- `Subscription`: Tier management and revenue distribution
- `Wallet`: Lightning/Cashu for rewards and payments

## Project Structure

```
RUNSTR IOS/
├── Models/           # Data models (User, Workout, Team, Event)
├── Services/         # Core services (Auth, HealthKit, Location)  
├── Views/           # SwiftUI views organized by feature
│   ├── DashboardView.swift    # Activity tracking & sync
│   ├── TeamsView.swift        # Team discovery/management/chat
│   ├── EventsView.swift       # Virtual events & registration
│   ├── StatsView.swift        # Personal & team analytics
│   ├── LeagueView.swift       # Coming soon placeholder
│   └── SettingsView.swift     # Account & subscription
├── Extensions/      # Swift extensions
├── Utilities/       # Helper functions and constants
└── Assets.xcassets/ # App icons, colors, images
```

## Development Setup

### Prerequisites
- Xcode 15.0+
- iOS 15.0+ deployment target
- Apple Developer account (for HealthKit entitlements)
- Physical iOS device (required for HealthKit testing)

### Installation
1. Clone the repository
2. Open `RUNSTR IOS.xcodeproj` in Xcode
3. Configure signing & capabilities:
   - Enable HealthKit capability
   - Configure App Store Connect for subscriptions
4. Build and run on physical device

### Testing
```bash
# Run unit tests
⌘+U in Xcode or: 
xcodebuild test -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15"

# Run UI tests  
xcodebuild test -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15" -testPlan UITests
```

## Core Services

### AuthenticationService
- Apple Sign-In integration
- Nostr keypair generation (npub/nsec)
- Subscription tier management
- Secure key storage in iOS Keychain

### HealthKitService  
- Workout data reading/writing
- Real-time heart rate monitoring
- Background data sync
- Privacy-compliant health data handling

### LocationService
- GPS tracking for outdoor workouts
- Route mapping and analysis
- Battery-optimized background tracking

## Platform Revenue Model

### Revenue Distribution (Member Subscription: $3.99/month)
- **$1.00** → RUNSTR platform operations
- **$1.00** → Selected team captain earnings
- **$1.00** → Charity (OpenSats/HRF/ALS)
- **$0.99** → Member rewards pool

### Captain Earnings Potential
- **Per Member**: $1.00/month recurring revenue
- **100 Members**: $100/month passive income
- **500 Members**: $500/month (max team size)
- **Virtual Events**: Keep 100% of ticket sales

### Organization Benefits
- **Event Revenue**: 100% of virtual event ticket sales
- **No Platform Fees**: On event transactions
- **Sponsorship Opportunities**: Direct brand partnerships
- **Corporate Programs**: B2B wellness contracts

## Key Features Implementation

### HealthKit Universal Sync
1. **Automatic Detection**: App detects workouts from any source (Apple Watch, Garmin, Strava)
2. **Background Sync**: Continuous monitoring for new workouts
3. **All Activity Types**: Running, cycling, walking, strength training, yoga, swimming, etc.
4. **Historical Import**: Pull past workouts on first sync
5. **Real-time Updates**: Live data during active workouts

### Team Platform Features
- **Team Creation**: Captains set up teams with custom branding and rules
- **Discovery**: Browse teams by activity type, location, or size
- **Chat System**: Team communication hub for members
- **Challenges Tab**: Team-specific competitions and goals
- **Analytics Dashboard**: Member activity and engagement metrics
- **Revenue Tracking**: Real-time earnings for captains

### Virtual Events System
- **Event Creation**: Organizations create ticketed virtual races/challenges
- **Registration**: Members sign up and pay entry fees
- **Live Leaderboards**: Real-time rankings during events
- **Prize Distribution**: Automatic Bitcoin rewards to winners
- **Event Analytics**: Participation and revenue metrics

## Subscription Tiers

### Free Tier
- Basic activity tracking (7-day history)
- View public teams and events
- Minimal streak rewards (1-2 sats)
- Limited features to encourage upgrades

### Member Tier ($3.99/month)
- Unlimited activity tracking and history
- Join unlimited teams
- Participate in all events and competitions
- Full team chat access
- Standard streak rewards (21-100 sats)
- Export workout data
- Lightning wallet access

### Captain Tier ($19.99/month)
- All Member features
- Create and manage teams (up to 500 members)
- Earn $1 per team member monthly
- Create team events and challenges
- Team analytics dashboard
- Custom team branding
- Priority support

### Organization Tier ($49.99/month)
- All Captain features
- Create public virtual events
- Sell event tickets (keep 100% revenue)
- Advanced analytics and reporting
- API access for integrations
- Multiple team management
- Dedicated account manager

## Testing Strategy

### Unit Tests
- Model validation and data persistence
- Service layer functionality 
- Reward calculation accuracy
- Nostr protocol compliance

### Integration Tests
- HealthKit data flow
- Apple Watch synchronization
- Cashu wallet operations
- Nostr relay communication

### UI Tests
- Onboarding flow completion
- Workout start/stop functionality
- Team joining/creation processes
- Subscription tier selection

## Security & Privacy

### Data Protection
- Nostr private keys stored in iOS Keychain
- Health data never leaves user's control
- Cashu ecash tokens self-custodial and private
- Cryptographic token security via secp256k1
- No personal data collection beyond fitness metrics

### Privacy Features
- User-controlled activity sharing levels
- Team visibility preferences
- Anonymous participation options
- GDPR compliance for EU users

## Deployment

### App Store Requirements
- HealthKit usage description in Info.plist
- Subscription management compliance
- Bitcoin/cryptocurrency app guidelines adherence
- Privacy policy and terms of service

### Release Process
1. Version bump and changelog update
2. Test on multiple iOS versions and devices
3. App Store Connect metadata and screenshots
4. Gradual rollout with monitoring
5. Post-launch analytics and crash reporting

## Development Notes

### Critical Development Rules

#### NEVER USE MOCK DATA
- **ABSOLUTELY NO MOCK DATA**: This is a production app. Never create, use, or return mock/fake/sample data.
- **Real Data Only**: All data must come from actual sources (HealthKit, Nostr, Cashu mint, etc.)
- **Empty States**: If no real data exists, show proper empty states, not fake data
- **Development Testing**: Use real test accounts and actual workouts, not simulated data
- **Error Handling**: If data sources fail, handle errors gracefully without falling back to mock data

#### NOSTR FRAMEWORK
- **Use nostr-sdk-ios**: We are using the official Nostr SDK for iOS from https://github.com/nostr-sdk/nostr-sdk-ios
- **Version**: NostrSDK 0.3.0 (confirmed working version)
- **No Custom Implementations**: Do not implement custom Nostr protocol handling; use the SDK's provided functionality
- **SDK Features**: Leverage the SDK's built-in support for events, relays, keys, and NIPs
- **Critical API Note**: Many SDK initializers are `internal` - must use Builder pattern for NostrEvent creation
- **Reference Documentation**: See `nostr-implementation-fixes-2025.md` for **ACTUAL WORKING** API patterns. This is the ONLY source of truth - do not create other Nostr documentation files.

### Code Conventions
- SwiftUI view files: PascalCase (e.g., `DashboardView.swift`)
- Service classes: Suffix with "Service" (e.g., `HealthKitService`)
- Models: Clean, Codable structs with clear property names
- Constants: Organized in dedicated Constants file

### Performance Considerations
- Background GPS optimization for battery life
- Efficient HealthKit query batching
- Asynchronous Nostr relay communication  
- Image caching for team/user avatars

### Future Integrations
- Garmin Connect API for additional device support
- Advanced AI coaching features
- Social media sharing capabilities
- Corporate wellness program APIs

## Troubleshooting

### Common Issues
- **HealthKit Permission Denied**: Ensure physical device testing, check Info.plist
- **Apple Watch Sync Issues**: Verify WatchKit app installation and permissions
- **Cashu Wallet Errors**: Check network connectivity and mint status
- **Nostr Relay Connection**: Test relay accessibility and fallback handling

### Debug Commands
```bash
# View app logs
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "RUNSTR"'

# HealthKit debugging
# Enable HealthKit logging in device settings → Developer → Health

# Network debugging  
# Use Charles Proxy or similar for Nostr relay communication
```

## Resources

- [Original RUNSTR Project](https://github.com/HealthNoteLabs/Runstr)
- [NIP-101e Specification](https://github.com/nostr-protocol/nips/pull/101)
- [Cashu Protocol Documentation](https://docs.cashu.space/)
- [Apple HealthKit Documentation](https://developer.apple.com/documentation/healthkit/)
- [SwiftUI Best Practices](https://developer.apple.com/tutorials/swiftui/)

### Project-Specific Documentation
- [`nostr-implementation-fixes-2025.md`](./nostr-implementation-fixes-2025.md) - **ONLY** source of truth for NostrSDK 0.3.0 API patterns. Contains actual working code that compiles and runs.
- [`roadmap.md`](./roadmap.md) - Comprehensive platform development roadmap with MVP specifications

## MVP Requirements

### Core Platform Features
The MVP focuses on enabling fitness organizations and influencers to monetize their audience:

#### Must Have for MVP Launch
- [x] **Authentication**: Apple Sign-In + RUNSTR login with secure key storage
- [x] **HealthKit Sync**: Universal workout tracking from all fitness apps
- [ ] **Subscription Tiers**: Free, Member ($3.99), Captain ($19.99)
- [ ] **Team Platform**: Create/join teams with chat and challenges
- [ ] **Virtual Events**: Ticketed fitness competitions with leaderboards
- [ ] **Streak Rewards**: Daily workout bonuses (21-100 sats)
- [ ] **Lightning Integration**: Zebedee for Bitcoin rewards and payments
- [ ] **Captain Earnings**: $1 per member monthly revenue tracking

#### UI/UX Requirements
- **Dashboard**: Activity sync, streak counter, team updates
- **Teams Tab**: Discover teams, join, team page with chat/challenges
- **Events Tab**: Browse virtual events, register, view leaderboards
- **League Tab**: "Season 2 Coming Soon" placeholder
- **Settings**: Subscription management, account security

#### Platform Differentiators
- **No Music Tab**: Removed as requested, focus on core platform
- **Universal Sync**: Works with any fitness app through HealthKit
- **Revenue Sharing**: Transparent revenue distribution to captains
- **Event Monetization**: 100% ticket revenue for organizations
- **Real Bitcoin**: Lightning/Cashu integration for actual rewards

### Platform Business Model
RUNSTR operates as a marketplace connecting fitness organizations with members:

1. **Organizations** create teams and events to generate revenue
2. **Members** subscribe to teams for $3.99/month (revenue splits 4 ways)
3. **Virtual Events** provide additional revenue through ticket sales
4. **Bitcoin Rewards** incentivize member engagement and retention

## Production Readiness Status

**RUNSTR is transitioning to production-ready implementation. Mock data is being systematically removed.**

### ✅ Production-Ready Components
- **Core Workout Tracking**: Full GPS and HealthKit integration
- **Cashu Service**: Complete ecash protocol implementation
- **Reward Calculation**: Real-time workout reward algorithms
- **Streak System**: Daily streak tracking with weekly reset
- **User Authentication**: Production Apple Sign-In integration

### 🔄 Currently Being Implemented
- **Cashu Token Minting**: Connecting reward calculation to actual token generation
- **Streak Bonus Distribution**: Automatic ecash rewards for daily streaks
- **Production Mint Integration**: Using https://mint.runstr.app for all operations

### ⚠️ Development/Mock Components (To Be Removed)
- **NostrService**: Currently using mock NIP-101e event publishing
- **Team Data**: Mock team events and statistics
- **BitcoinWalletService**: Legacy service replaced by CashuService

### Production Configuration
- **Cashu Mint**: `https://mint.runstr.app`
- **Nostr Relays**: Real relay pool for production events
- **API Keys**: All services configured for production endpoints

---

## Bug Fixes & Lessons Learned

### 2025-07-28: Build Compilation Errors

**Issue**: Build failed with Swift compilation errors

**Root Causes & Fixes**:

1. **FitnessTeamEvent Initializer Mismatch** (`Team.swift:86`)
   - **Problem**: Calling `FitnessTeamEvent` initializer with individual parameters (`id`, `content`, `name`, etc.) but the actual initializer only accepts `(eventContent: String, tags: [[String]], createdAt: Date)`
   - **Fix**: Updated call to use correct parameters: `eventContent: description, tags: tags, createdAt: createdAt`
   - **Lesson**: Always check initializer signatures when working with model objects, especially after refactoring

2. **Memory Access Conflict** (`NostrService.swift:416`)
   - **Problem**: Overlapping access to `memberStats[workout.userID]` in single expression: `memberStats[workout.userID]?.lastWorkoutDate = max(memberStats[workout.userID]?.lastWorkoutDate ?? Date.distantPast, workout.startTime)`
   - **Fix**: Extracted to local variable: `let currentLastWorkoutDate = memberStats[workout.userID]?.lastWorkoutDate ?? Date.distantPast`
   - **Lesson**: Avoid multiple accesses to same dictionary key in single expression; use local variables to prevent memory access conflicts

**Prevention Tips**:
- Run frequent builds during development to catch compilation errors early
- Use Xcode's static analysis to identify potential memory access issues
- When refactoring model initializers, search codebase for all usage sites
- Consider using computed properties or methods instead of complex inline expressions

---

*This document should be updated as the codebase evolves and new features are implemented.*