# RUNSTR iOS App

## Project Overview

RUNSTR is a Bitcoin-native fitness app that rewards users with Bitcoin for running and walking activities. The app combines traditional fitness tracking with decentralized social features, team-based challenges, and AI coaching.

**Key Features:**
- Activity tracking with Apple Watch/HealthKit integration  
- Bitcoin rewards via Cashu ecash protocol
- Decentralized data storage using Nostr protocol
- Team creation and management
- Community challenges and competitions
- AI-powered coaching insights (Coach Claude)
- Subscription tiers (Member: $5.99/mo, Captain: $20.99/mo)

## Technical Architecture

### Frontend
- **Framework**: SwiftUI + UIKit for iOS 15.0+
- **Architecture**: MVVM with ObservableObject services
- **State Management**: @StateObject, @EnvironmentObject, @Published

### Key Integrations
- **HealthKit**: Primary fitness data source
- **Apple Watch**: WatchKit for seamless workout tracking
- **Nostr Protocol**: Decentralized data storage (NIP-101e for workouts, NIP-51 for teams)
- **Cashu**: Bitcoin ecash rewards system
- **Apple Music**: Workout playlist integration
- **Claude AI**: Personalized coaching insights

### Data Models
- `User`: Authentication, subscription, Nostr keys, stats
- `Workout`: GPS tracking, metrics, NIP-101e format
- `Team`: Community features, NIP-51 lists
- `Event`: Challenges and competitions
- `CashuWallet`: Bitcoin reward management

## Project Structure

```
RUNSTR IOS/
├── Models/           # Data models (User, Workout, Team, Event)
├── Services/         # Core services (Auth, HealthKit, Location)  
├── Views/           # SwiftUI views organized by feature
│   ├── DashboardView.swift    # Main activity tracking
│   ├── TeamsView.swift        # Team discovery/management
│   ├── EventsView.swift       # Competitions
│   ├── StatsView.swift        # Analytics & Coach Claude
│   └── SettingsView.swift     # Account & preferences
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

## Key Features Implementation

### Workout Tracking Flow
1. **Start Workout**: User taps start → LocationService begins GPS tracking
2. **Real-time Data**: HealthKitService streams heart rate, pace, distance
3. **Data Storage**: Workout saved as NIP-101e note to Nostr relays
4. **Reward Calculation**: Cashu wallet credited based on distance/duration
5. **Team Updates**: Activity shared with team members via NIP-51 lists

### Team Management
- **Discovery**: Browse teams with filtering (activity level, size, location)
- **Joining**: One-tap join with instant team roster updates
- **Creation**: Captains can create teams with custom branding
- **Earnings**: Captains earn 1,000 sats/month per team member
- **Data**: Teams stored as NIP-51 lists on Nostr relays

### Bitcoin Rewards System
- **Cashu Integration**: Ecash tokens for privacy and instant settlement
- **Automatic Distribution**: Rewards credited immediately after workouts
- **Withdrawal**: Lightning Network integration for Bitcoin withdrawal
- **Transparency**: Full transaction history and audit trail

## Subscription Model

### Member Tier ($5.99/month)
- Full activity tracking
- Team joining and participation  
- Event participation with Bitcoin rewards
- Basic Coach Claude insights
- Cashu wallet with withdrawal

### Captain Tier ($20.99/month)
- All Member features
- Team creation and management (up to 500 members)
- Event creation and hosting
- 1,000 sats monthly earning per team member
- Advanced analytics and team insights

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
- Bitcoin rewards self-custodial via Cashu
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

---

*This document should be updated as the codebase evolves and new features are implemented.*