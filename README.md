# RUNSTR iOS

A Bitcoin-native fitness app that rewards users with real Bitcoin (sats) for their workout activities. RUNSTR leverages the Nostr protocol for decentralized data storage and social features, creating a unique fitness ecosystem where users can earn, compete, and connect.

## 🏃‍♂️ Overview

RUNSTR transforms fitness tracking into a rewarding experience by:
- **Earning Bitcoin**: Get sats for every workout, personal best, and achievement
- **Nostr Integration**: Decentralized workout data and social features
- **Team Challenges**: Join teams, compete in events, and climb leaderboards
- **AI Coaching**: Get personalized training advice from Coach Claude

## ✨ Key Features

### 🏃 Activity Tracking
- **Multi-Sport Support**: Running, walking, cycling with GPS tracking
- **Real-time Stats**: Distance, pace, heart rate, elevation
- **Apple Health Integration**: Sync with HealthKit and Apple Watch
- **Nostr Publishing**: Workouts stored as NIP-101e events

### ₿ Bitcoin Rewards
- **Instant Rewards**: Earn 5-10 sats per workout
- **Lightning Integration**: Zebedee API for instant payments
- **Gift Cards**: Spend sats on Amazon, Visa, fitness retailers
- **Streak Bonuses**: Extra rewards for consistency

### 🌐 Nostr-Powered Social
- **Decentralized Identity**: Auto-generated npub/nsec pairs
- **Delegated Signing**: Link existing Nostr identity
- **Workout Sharing**: Public fitness achievements
- **Team Chat**: Real-time messaging via Nostr

### 👥 Teams & Events
- **Team Formation**: Captains create and manage teams
- **Virtual Events**: Distance challenges, time trials
- **Leaderboards**: Team and individual rankings
- **Challenge System**: 1v1 competitions with push notifications

### 💎 Subscription Tiers
- **Member ($3.99/month)**: Access to teams and events
- **Captain ($10.99/month)**: Create teams, earn per member
- **Organization ($24.99/month)**: Create events, member rewards

## 🛠 Technical Architecture

### Frontend
- **SwiftUI**: Native iOS interface with dark theme
- **Combine**: Reactive data flow
- **Core Location**: GPS tracking
- **HealthKit**: Fitness data integration
- **AuthenticationServices**: Apple Sign-In

### Backend Services
- **Nostr Protocol**: Decentralized data storage
  - NIP-01: Basic event publishing
  - NIP-101e: Workout data format
  - NIP-51: Team and event lists
- **Lightning Network**: Bitcoin payments via Zebedee
- **Bitcoin Company API**: Gift card redemption

### Data Storage
- **Keychain**: Secure nsec storage
- **CoreData**: Local workout cache
- **Nostr Relays**: Distributed workout history
- **iCloud**: Settings and preferences sync

## 📱 App Structure

```
RUNSTR IOS/
├── Models/
│   ├── User.swift              # User profile and authentication
│   ├── Workout.swift           # Workout data and session
│   ├── Team.swift              # Team management
│   ├── Event.swift             # Events and challenges
│   ├── CashuWallet.swift       # Bitcoin wallet integration
│   └── NostrModels.swift       # Nostr event structures
├── Services/
│   ├── AuthenticationService.swift    # User authentication
│   ├── HealthKitService.swift         # Apple Health integration
│   ├── LocationService.swift          # GPS tracking
│   └── NostrService.swift             # Nostr client (planned)
├── Views/
│   ├── DashboardView.swift     # Main workout interface
│   ├── WorkoutView.swift       # Active workout tracking
│   ├── StatsView.swift         # Profile and statistics
│   ├── TeamsView.swift         # Team management
│   ├── EventsView.swift        # Events and challenges
│   └── OnboardingView.swift    # User onboarding
└── Supporting Files/
    ├── Assets.xcassets         # App icons and images
    └── Info.plist             # App configuration
```

## 🚀 Getting Started

### Prerequisites
- iOS 17.0+
- Xcode 15.0+
- Apple Developer Account (for device testing)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/HealthNoteLabs/RUNSTR-IOS.git
   ```
2. Open `RUNSTR IOS.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run on simulator or device

### Configuration
- **Mock Authentication**: Development uses mock Apple Sign-In
- **Test Data**: Sample workouts and users for testing
- **Simulator**: GPS simulation available in Debug menu

## 🔮 Roadmap

### Phase 1: Core Features ✅
- [x] Basic UI and navigation
- [x] Mock authentication system
- [x] Activity tracking foundation
- [x] Minimalist black/white design

### Phase 2: Nostr Integration 🚧
- [ ] Enhanced npub/nsec generation
- [ ] Delegated signing implementation
- [ ] NIP-101e workout publishing
- [ ] Basic social features

### Phase 3: Bitcoin Integration
- [ ] Zebedee Lightning wallet
- [ ] Rewards calculation system
- [ ] Gift card redemption
- [ ] Apple Pay subscriptions

### Phase 4: Social Features
- [ ] Team creation and management
- [ ] Real-time chat system
- [ ] Challenge notifications
- [ ] Event leaderboards

### Phase 5: AI & Advanced Features
- [ ] Coach Claude integration
- [ ] Voice coaching during workouts
- [ ] Advanced analytics
- [ ] Social media sharing

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🔒 Security

- **Private Keys**: nsec stored in iOS Keychain
- **Delegated Signing**: No private key exposure
- **Secure Communication**: HTTPS/WSS only
- **Apple Guidelines**: Follows iOS security best practices

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Nostr Protocol**: For decentralized social infrastructure
- **Lightning Network**: For instant Bitcoin payments
- **Apple HealthKit**: For comprehensive fitness tracking
- **Zebedee**: For Lightning wallet services

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/HealthNoteLabs/RUNSTR-IOS/issues)
- **Discussions**: [GitHub Discussions](https://github.com/HealthNoteLabs/RUNSTR-IOS/discussions)
- **Email**: support@runstr.app

---

**RUNSTR** - Where fitness meets Bitcoin. Every step counts, every sat earned. 🏃‍♂️₿