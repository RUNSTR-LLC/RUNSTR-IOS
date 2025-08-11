# RUNSTR iOS App

## Project Overview

RUNSTR is a minimalistic fitness tracking app focused on core workout functionality. The app provides clean, simple workout tracking with HealthKit integration and basic Nostr workout sharing.

**Core Value Proposition:**
- **Simple Workout Tracking**: Clean, distraction-free fitness tracking
- **Universal Sync**: Works with any fitness app through HealthKit integration
- **Privacy-First**: Your workout data stays on your device
- **Nostr Integration**: Optional workout sharing to decentralized social networks

**Key Features:**
- Universal workout sync via HealthKit (running, walking, cycling supported)
- Real-time workout tracking with GPS and heart rate
- Clean, minimal user interface
- Optional Nostr workout publishing
- Local workout history and statistics

## Technical Architecture

### Frontend
- **Framework**: SwiftUI + UIKit for iOS 15.0+
- **Architecture**: MVVM with ObservableObject services
- **State Management**: @StateObject, @EnvironmentObject, @Published

### Key Integrations
- **HealthKit**: Universal workout data sync (running, cycling, walking)
- **Apple Watch**: Seamless workout tracking
- **NostrSDK**: Optional workout sharing to Nostr relays
- **Core Location**: GPS tracking for outdoor workouts

### Data Models
- `User`: Basic authentication and preferences
- `Workout`: Local workout storage with HealthKit sync (running, walking, cycling)
- `ActivityType`: Supported workout types enumeration

## Project Structure

```
RUNSTR IOS/
├── Models/           # Core data models (User, Workout)
├── Services/         # Core services (Auth, HealthKit, Location, WorkoutStorage)  
├── Views/           # SwiftUI views
│   ├── WorkoutView.swift         # Live workout tracking
│   ├── DashboardView.swift       # Workout history & stats
│   ├── AllWorkoutsView.swift     # Complete workout list
│   ├── WorkoutDetailView.swift   # Individual workout details
│   ├── ProfileView.swift         # User profile & settings
│   └── SettingsView.swift        # App preferences
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
- Optional Nostr keypair generation (npub/nsec)
- Secure key storage in iOS Keychain
- Basic user profile management

### HealthKitService  
- Workout data reading/writing
- Real-time heart rate monitoring
- Background data sync
- Privacy-compliant health data handling

### LocationService
- GPS tracking for outdoor workouts
- Route recording and basic mapping
- Battery-optimized location tracking

### WorkoutStorage
- Local workout data persistence
- Core Data integration for workout history
- Simple data management without cloud sync

## App Philosophy

### Minimalistic Approach
- **Core Functionality Only**: Focus on essential workout tracking features
- **No Monetization**: Free app with no subscriptions or in-app purchases
- **Privacy-First**: All data stored locally on device
- **No Social Features**: Optional Nostr sharing only
- **Clean Interface**: Distraction-free workout experience

## Core Features

### HealthKit Integration
1. **Workout Detection**: Automatic detection of workouts from HealthKit
2. **Background Sync**: Monitors for new workouts when app is backgrounded
3. **Supported Activity Types**: Running, cycling, walking
4. **Historical Import**: Import past workouts on first sync
5. **Real-time Tracking**: Live metrics during active workouts

### Workout Tracking
- **Live Metrics**: Real-time heart rate, pace, distance, calories
- **GPS Routes**: Route mapping for outdoor activities
- **Workout History**: Simple list of past workouts
- **Basic Statistics**: Weekly/monthly summaries
- **Export Data**: Share workout summaries

### Optional Features
- **Nostr Sharing**: Publish workout summaries to Nostr relays
- **Apple Watch**: Seamless Apple Watch integration
- **Route Visualization**: Simple maps of GPS-tracked workouts

## App Features

### Core Functionality (All Free)
- **Unlimited workout tracking and history**
- **Full HealthKit integration**
- **GPS route recording**
- **Apple Watch support**
- **Workout data export**
- **Optional Nostr workout sharing**
- **Local data storage**
- **Clean, minimal interface**

## Testing Strategy

### Unit Tests
- Model validation and data persistence
- Service layer functionality (HealthKit, Location, WorkoutStorage)
- Workout calculation accuracy
- Optional Nostr protocol compliance

### Integration Tests
- HealthKit data flow
- Apple Watch synchronization
- Local data persistence
- Optional Nostr relay communication

### UI Tests
- Basic onboarding flow
- Workout start/stop functionality
- Workout history navigation
- Settings configuration

## Security & Privacy

### Data Protection
- Optional Nostr private keys stored in iOS Keychain
- Health data never leaves user's control
- All workout data stored locally only
- No cloud synchronization or data collection
- Minimal network usage (Nostr sharing only if enabled)

### Privacy Features
- All data stays on device
- Optional Nostr sharing (user controlled)
- No analytics or telemetry
- No user account required for core features

## Deployment

### App Store Requirements
- HealthKit usage description in Info.plist
- Location services usage description
- Privacy policy for optional Nostr features
- Simple terms of service

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
- **Real Data Only**: All data must come from actual sources (HealthKit, Core Location, local storage)
- **Empty States**: If no real data exists, show proper empty states, not fake data
- **Development Testing**: Use real test accounts and actual workouts, not simulated data
- **Error Handling**: If data sources fail, handle errors gracefully without falling back to mock data

#### NOSTR FRAMEWORK (OPTIONAL)
- **Use nostr-sdk-ios**: We are using the official Nostr SDK for iOS from https://github.com/nostr-sdk/nostr-sdk-ios
- **Version**: NostrSDK 0.3.0 (confirmed working version)
- **Optional Integration**: Nostr sharing is completely optional and can be disabled
- **No Custom Implementations**: Do not implement custom Nostr protocol handling; use the SDK's provided functionality
- **SDK Features**: Leverage the SDK's built-in support for events, relays, keys, and NIPs
- **Critical API Note**: Many SDK initializers are `internal` - must use Builder pattern for NostrEvent creation
- **Reference Documentation**: See `nostr-implementation-fixes-2025.md` for **ACTUAL WORKING** API patterns.

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

### Potential Future Enhancements
- Additional HealthKit data types (swimming, strength training)
- Improved route visualization
- Workout data export formats
- Basic workout statistics and trends

## Troubleshooting

### Common Issues
- **HealthKit Permission Denied**: Ensure physical device testing, check Info.plist
- **Apple Watch Sync Issues**: Verify WatchKit app installation and permissions
- **GPS Location Issues**: Check location permissions and GPS availability
- **Nostr Connection Issues** (if enabled): Test relay accessibility and network connectivity

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

- [Apple HealthKit Documentation](https://developer.apple.com/documentation/healthkit/)
- [SwiftUI Best Practices](https://developer.apple.com/tutorials/swiftui/)
- [Core Location Documentation](https://developer.apple.com/documentation/corelocation/)
- [Nostr SDK for iOS](https://github.com/nostr-sdk/nostr-sdk-ios) (for optional features)

### Project-Specific Documentation
- [`nostr-implementation-fixes-2025.md`](./nostr-implementation-fixes-2025.md) - Working NostrSDK 0.3.0 API patterns (if using Nostr features)

## MVP Requirements

### Core App Features
The MVP focuses on simple, effective workout tracking:

#### Must Have for MVP Launch
- [x] **HealthKit Integration**: Universal workout tracking from all fitness apps
- [x] **Real-time Tracking**: Live workout metrics with GPS
- [x] **Workout History**: Local storage of all workout data
- [x] **Apple Watch Support**: Seamless Apple Watch integration
- [ ] **Workout Statistics**: Basic weekly/monthly summaries
- [ ] **Data Export**: Share workout data
- [ ] **Optional Nostr Sharing**: Publish workouts to Nostr relays (user choice)

#### UI/UX Requirements
- **Workout View**: Live tracking interface with start/stop/pause
- **Dashboard**: Recent workouts and basic statistics
- **All Workouts**: Complete workout history list
- **Workout Details**: Individual workout information and maps
- **Profile/Settings**: User preferences and optional Nostr configuration

#### App Principles
- **Minimalism**: Clean, distraction-free interface
- **Privacy**: All data stored locally on device
- **No Monetization**: Completely free app
- **No Social Features**: Optional Nostr sharing only
- **Universal Compatibility**: Works with any fitness app through HealthKit

## Production Readiness Status

**RUNSTR is a minimalistic workout tracking app ready for production.**

### ✅ Production-Ready Components
- **Core Workout Tracking**: Full GPS and HealthKit integration
- **Real-time Metrics**: Live workout data during sessions
- **Local Data Storage**: WorkoutStorage with Core Data persistence
- **Apple Watch Integration**: Seamless workout sync
- **User Authentication**: Apple Sign-In for optional features

### 🔄 Currently Being Implemented
- **Workout Statistics**: Basic weekly/monthly summaries
- **Data Export**: Workout sharing capabilities
- **UI Polish**: Final interface refinements

### Production Configuration
- **Local Storage**: All data stored on device using Core Data
- **Optional Nostr Relays**: Real relay pool for optional workout sharing
- **No External Dependencies**: Core functionality works offline

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