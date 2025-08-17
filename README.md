# RUNSTR iOS

> **Nostr-native cardio tracking designed to be simple, effective, and truly yours.**

RUNSTR transforms workout tracking by making your fitness data truly portable while maintaining complete privacy. Built on the Nostr protocol with local-first architecture, it's the first fitness app where you actually own your workout data.

## 🏃‍♂️ Overview

**Simple. Effective. Yours.**
- **Local-First Architecture**: Your workout data stays on your device
- **Nostr Integration**: Share workouts using Kind 1301 events for true data portability
- **Universal Sync**: Works with any fitness app through HealthKit integration
- **Clean Interface**: Distraction-free workout tracking experience

## ✨ Key Features

### 🏃 Universal Workout Tracking
- **HealthKit Integration** - Syncs workouts from all your fitness apps
- **Real-Time Tracking** - Live GPS, heart rate, pace, distance monitoring
- **Apple Watch Support** - Seamless tracking across devices
- **Activity Types** - Running, cycling, walking, and more

### 🌐 Nostr-Native Data Portability
- **Kind 1301 Events** - Your workouts become interoperable across Nostr
- **Selective Sharing** - Choose exactly which workout data to publish
- **Decentralized Storage** - No corporate silos or data lock-in
- **Privacy Control** - Share publicly or with specific communities

### 📊 Comprehensive Analytics
- **Performance Statistics** - Weekly and monthly summaries
- **Progress Tracking** - Monitor improvements over time
- **Route Visualization** - GPS-mapped workout routes
- **Data Export** - Multiple formats for complete portability

### 🔒 Privacy-First Design
- **Local Storage** - All data stored securely on your device
- **No Cloud Dependencies** - Core functionality works completely offline
- **Optional Sharing** - Nostr publishing is entirely user-controlled
- **Zero Tracking** - No analytics, telemetry, or data collection

## 🛠 Technical Architecture

### Frontend
- **Framework**: SwiftUI + UIKit for iOS 15.0+
- **Architecture**: MVVM with ObservableObject services
- **State Management**: @StateObject, @EnvironmentObject, @Published

### Key Integrations
- **HealthKit**: Universal workout data sync (running, cycling, walking)
- **Apple Watch**: Seamless workout tracking
- **NostrSDK**: Optional workout sharing to Nostr relays
- **Core Location**: GPS tracking for outdoor workouts

### Data Storage
- **Local-First**: Core Data for workout persistence
- **Keychain**: Secure Nostr key storage (optional)
- **No Cloud Dependencies**: All data stored locally
- **Optional Nostr Publishing**: Kind 1301 events for interoperability

## 📱 App Structure

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

## 🚀 Getting Started

### Prerequisites
- **Xcode 15.0+** with iOS SDK
- **iOS 15.0+** deployment target
- **Physical iOS Device** (required for HealthKit testing)
- **Apple Developer Account** (for HealthKit entitlements)

### Installation
```bash
git clone https://github.com/your-username/runstr-ios.git
cd runstr-ios
open "RUNSTR IOS.xcodeproj"
```

### Setup Steps
1. Clone the repository
2. Open `RUNSTR IOS.xcodeproj` in Xcode
3. Configure signing & capabilities:
   - Enable HealthKit capability
   - Set up development team
4. Build and run on physical device

### Testing
```bash
# Run unit tests
xcodebuild test -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15"

# Run UI tests
xcodebuild test -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15" -testPlan UITests
```

## 🌐 Nostr Integration

RUNSTR implements **Kind 1301 events** for workout data interoperability:

```swift
// Example: Publishing a workout to Nostr
let workoutEvent = try NostrEvent.builder()
    .kind(.custom(1301))
    .content(workoutSummary)
    .tags(workoutTags)
    .build(signedBy: keypair)
```

**Supported Features:**
- Selective workout data sharing
- Granular privacy controls
- Multi-relay publishing
- Decentralized fitness communities

## 📊 Core Services

### AuthenticationService
- Apple Sign-In integration
- Optional Nostr keypair generation
- Secure key storage in iOS Keychain

### HealthKitService
- Universal workout data sync
- Real-time health metrics
- Background data synchronization

### LocationService
- GPS tracking for outdoor workouts
- Battery-optimized location tracking
- Route recording and visualization

### WorkoutStorage
- Local workout data persistence
- Core Data integration
- Export functionality

## 🚀 Development

### Key Principles
- **No Mock Data** - Production app uses real data only
- **Privacy-First** - All data stays on device by default
- **Minimalistic** - Clean, distraction-free interface
- **Local-First** - Core functionality works offline

### Code Conventions
- SwiftUI views: PascalCase (`DashboardView.swift`)
- Services: Suffix with "Service" (`HealthKitService`)
- Models: Clean, Codable structs
- Constants: Organized in dedicated file

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🔒 Security & Privacy

**True Data Ownership**
- All workout data stored locally on device
- Optional Nostr sharing is user-controlled
- No corporate data collection or analytics
- Secure Nostr key storage in iOS Keychain

**Privacy Features**
- All data stays on device
- Optional Nostr sharing (user controlled)
- No analytics or telemetry
- No user account required for core features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Resources

- [Nostr Protocol](https://nostr.com/) - Decentralized social networking protocol
- [Apple HealthKit](https://developer.apple.com/documentation/healthkit/) - iOS health data framework
- [NostrSDK for iOS](https://github.com/nostr-sdk/nostr-sdk-ios) - Nostr integration library

---

**Built with ❤️ for the decentralized fitness community**

*Your workouts. Your data. Your choice.*