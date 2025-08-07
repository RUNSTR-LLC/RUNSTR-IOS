# RUNSTR Platform Roadmap - Fitness Club Monetization Platform

## Executive Summary

RUNSTR transforms fitness communities into thriving businesses by providing infrastructure for clubs to monetize through subscriptions and virtual events, while members earn Bitcoin rewards for their workouts. This roadmap outlines the path to MVP launch focusing on platform capabilities that enable fitness organizations and influencers to generate recurring revenue.

## Platform Vision

**For Organizations/Influencers**: Turn your fitness following into a sustainable business with monthly recurring revenue and virtual event income.

**For Members**: Keep using your favorite fitness apps (Apple Watch, Garmin, Strava) while earning Bitcoin rewards through team memberships and competitions.

---

## Phase 1: Foundation & Core Infrastructure (Week 1-2)
**Goal**: Establish robust platform architecture supporting multi-tenant team management

### Technical Foundation
- [ ] Configure project for iOS 15.0+ deployment target
- [ ] Set up modular MVVM architecture with clear service separation
- [ ] Implement core data models for platform entities
- [ ] Configure CloudKit for team data synchronization
- [ ] Set up proper error handling and logging infrastructure

### Authentication System
- [ ] Apple Sign-In with automatic npub/nsec generation
- [ ] RUNSTR native login with local key storage
- [ ] Secure key management using iOS Keychain
- [ ] Session management and auto-refresh tokens
- [ ] Account recovery flow with nsec backup

### Core Data Models
```swift
// Platform-centric models
- User (with subscription status)
- Team (with captain/member hierarchy)
- Event (virtual fitness events)
- Workout (synced from HealthKit)
- Subscription (tier management)
- Wallet (Cashu/Lightning integration)
```

### HealthKit Integration
- [ ] Request comprehensive HealthKit permissions
- [ ] Support all workout types (running, cycling, walking, strength, yoga, swimming)
- [ ] Real-time workout data sync during activities
- [ ] Historical workout import capability
- [ ] Background sync for automatic updates

**Deliverables**: 
- Functioning authentication system
- HealthKit sync for all workout types
- Core data persistence layer

---

## Phase 2: Subscription & Monetization System (Week 3-4)
**Goal**: Implement three-tier subscription model with proper payment processing

### Subscription Tiers

#### Free Tier
- Basic activity tracking
- View public teams and events
- Limited workout history (7 days)
- Minimal streak rewards (1-2 sats)

#### Member Tier ($3.99/month)
- Full activity tracking & history
- Join unlimited teams
- Participate in events and competitions
- Team chat access
- Standard streak rewards (21-100 sats)
- Export workout data

#### Captain Tier ($19.99/month)
- All Member features
- Create and manage teams (up to 500 members)
- Create team events and challenges
- Earn $1 per team member monthly
- Team analytics dashboard
- Custom team branding

#### Organization Tier ($49.99/month)
- All Captain features
- Create public virtual events
- Sell event tickets (keep 100% revenue)
- Advanced analytics & reporting
- API access for integrations
- Priority support

### Payment Infrastructure
- [ ] StoreKit 2 integration for Apple Pay
- [ ] Subscription management UI
- [ ] Receipt validation
- [ ] Restore purchases functionality
- [ ] Subscription status tracking
- [ ] Grace period handling

### Revenue Distribution
```
Member Subscription ($3.99):
- $1.00 → RUNSTR platform
- $1.00 → Selected team captain
- $1.00 → Charity (OpenSats/HRF/ALS)
- $0.99 → Member rewards pool
```

**Deliverables**:
- Working subscription system with Apple Pay
- Subscription management interface
- Revenue tracking dashboard for captains

---

## Phase 3: Team Management Platform (Week 5-6)
**Goal**: Build comprehensive team creation and management system

### Team Creation (Captain/Organization)
- [ ] Team setup wizard with branding options
- [ ] Team description and activity focus
- [ ] Member capacity settings
- [ ] Team rules and guidelines
- [ ] Social media integration links

### Team Discovery & Joining
- [ ] Team browse/search interface
- [ ] Filter by activity type, location, size
- [ ] Team preview with stats
- [ ] One-tap join functionality
- [ ] Team recommendations based on activity

### Team Management Dashboard
- [ ] Member roster management
- [ ] Activity leaderboards
- [ ] Team statistics and analytics
- [ ] Member engagement metrics
- [ ] Revenue tracking for captains

### Team Features
- [ ] Team chat (text-based initially)
- [ ] Team challenges tab
- [ ] Shared workout plans
- [ ] Member achievements
- [ ] Team announcements

**Deliverables**:
- Fully functional team creation system
- Team discovery and joining flow
- Basic team chat functionality

---

## Phase 4: Virtual Events Platform (Week 7-8)
**Goal**: Enable organizations to create and monetize virtual fitness events

### Event Creation System
- [ ] Event setup wizard
- [ ] Event types (5K, Marathon, Monthly Challenge, etc.)
- [ ] Ticket pricing configuration
- [ ] Registration management
- [ ] Event rules and requirements

### Event Discovery
- [ ] Public events feed
- [ ] Filter by type, date, difficulty
- [ ] Event details page with registration
- [ ] Upcoming events calendar
- [ ] Featured events section

### Event Participation
- [ ] Event registration flow
- [ ] Payment processing for tickets
- [ ] Event countdown timers
- [ ] Live leaderboards during events
- [ ] Progress tracking

### Event Management (Organizers)
- [ ] Participant roster
- [ ] Revenue tracking
- [ ] Event analytics
- [ ] Winner selection tools
- [ ] Prize distribution system

**Deliverables**:
- Event creation and management system
- Event discovery and registration
- Live leaderboard functionality

---

## Phase 5: Rewards & Incentive System (Week 9-10)
**Goal**: Implement Bitcoin rewards through Lightning/Cashu integration

### Streak Rewards System
- [ ] Daily workout tracking
- [ ] Progressive reward schedule (7, 14, 30 days)
- [ ] Visual streak counter
- [ ] Streak notifications
- [ ] Bonus multipliers for consistency

### Cashu Wallet Integration
- [ ] Wallet creation on signup
- [ ] Secure seed storage in Keychain
- [ ] Balance display
- [ ] Transaction history
- [ ] Backup/recovery options

### Lightning Integration (Zebedee)
- [ ] Lightning wallet connection
- [ ] Send/receive functionality
- [ ] QR code scanning
- [ ] Invoice generation
- [ ] Withdrawal to external wallets

### Reward Distribution
```
Daily Streaks:
- 7 days: 21 sats
- 14 days: 50 sats
- 30 days: 100 sats

Event Prizes:
- 1st place: 40% of prize pool
- 2nd place: 30% of prize pool
- 3rd place: 20% of prize pool
- Participation: 10% distributed
```

**Deliverables**:
- Working Cashu wallet
- Lightning send/receive
- Automated streak rewards

---

## Phase 6: UI/UX Polish & MVP Completion (Week 11-12)
**Goal**: Refine user experience and prepare for launch

### Core UI Improvements
- [ ] Smooth animations and transitions
- [ ] Loading states and skeletons
- [ ] Empty states with clear CTAs
- [ ] Error handling with user feedback
- [ ] Accessibility improvements

### Dashboard Optimization
- [ ] Quick action buttons
- [ ] Activity summary widgets
- [ ] Team updates feed
- [ ] Upcoming events carousel
- [ ] Streak progress indicator

### Performance Optimization
- [ ] Image caching and lazy loading
- [ ] Background task optimization
- [ ] Memory usage optimization
- [ ] Network request batching
- [ ] Offline mode support

### Testing & Quality Assurance
- [ ] Unit test coverage (>70%)
- [ ] UI testing for critical flows
- [ ] Beta testing program setup
- [ ] Crash reporting integration
- [ ] Analytics implementation

**Deliverables**:
- Polished, production-ready UI
- Comprehensive test coverage
- Beta testing feedback incorporated

---

## MVP Feature Checklist

### ✅ Must Have (MVP)
- [x] Apple Sign-In / RUNSTR authentication
- [x] HealthKit workout sync (all types)
- [ ] 3 subscription tiers (Free, Member $3.99, Captain $19.99)
- [ ] Team creation and management
- [ ] Team discovery and joining
- [ ] Basic team chat
- [ ] Virtual event creation
- [ ] Event registration and participation
- [ ] Live event leaderboards
- [ ] Streak rewards system
- [ ] Lightning wallet (Zebedee)
- [ ] Captain earnings tracking

### 🔄 Nice to Have (Post-MVP)
- [ ] Organization tier ($49.99)
- [ ] Advanced team analytics
- [ ] Video/photo in team chat
- [ ] Custom workout plans
- [ ] Garmin integration
- [ ] Strava integration
- [ ] Merchandise shop
- [ ] Corporate wellness programs
- [ ] AI coaching (Coach Claude)
- [ ] Apple Watch app

### ❌ Not in MVP
- [ ] Music integration (removed as requested)
- [ ] League system (showing "Season 2 Coming Soon")
- [ ] Complex Nostr features
- [ ] Android app
- [ ] Web platform

---

## Technical Architecture

### Frontend Stack
- **SwiftUI** for all UI components
- **Combine** for reactive programming
- **MVVM** architecture pattern
- **CloudKit** for team data sync

### Key Services
```swift
// Core Services Architecture
AuthenticationService    // User authentication & session
HealthKitService        // Workout data sync
SubscriptionService     // StoreKit 2 payments
TeamService            // Team CRUD operations
EventService           // Event management
WalletService          // Lightning/Cashu
StreamService          // Real-time updates
AnalyticsService       // Usage tracking
```

### Data Flow
1. User signs up → Creates wallet → Selects subscription
2. Joins team → Subscription splits to captain/charity/rewards
3. Syncs workouts → Earns streak rewards → Participates in events
4. Captain creates events → Sells tickets → Manages team

---

## Success Metrics

### Platform KPIs
- **Monthly Recurring Revenue (MRR)**: Target $10K by month 3
- **Total Teams Created**: 100+ active teams
- **Member Retention**: 60% month-over-month
- **Event Participation Rate**: 30% of members
- **Captain Earning Average**: $200/month

### User Engagement
- **Daily Active Users**: 40% of total users
- **Workouts Synced/Week**: 3+ per user
- **Team Chat Messages**: 10+ per active team daily
- **Event Completion Rate**: 70% of registrants

### Technical Metrics
- **Crash-free rate**: >99.5%
- **API response time**: <200ms p95
- **App startup time**: <2 seconds
- **HealthKit sync reliability**: >99%

---

## Launch Strategy

### Phase 1: Private Beta (Week 13)
- 50 fitness influencers/coaches
- Focus on team creation tools
- Gather feedback on captain features
- Refine revenue model

### Phase 2: Public Beta (Week 14-15)
- Open TestFlight (1000 users)
- Marketing to running clubs
- Partnership with fitness communities
- Referral program for captains

### Phase 3: App Store Launch (Week 16)
- Full public release
- Press release to fitness media
- Influencer marketing campaign
- Community building on social media

---

## Risk Mitigation

### Technical Risks
- **HealthKit Reliability**: Implement fallback manual entry
- **Payment Processing**: Multiple payment provider support
- **Scaling Issues**: CloudKit + proper caching strategy
- **Lightning Integration**: Start with Zebedee, add alternatives

### Business Risks
- **Low Captain Adoption**: Aggressive referral incentives
- **Member Churn**: Focus on team engagement features
- **Event Participation**: Free events initially to build habit
- **Revenue Split Complexity**: Clear, transparent reporting

### Compliance Risks
- **App Store Review**: Focus on fitness, minimize crypto emphasis
- **Payment Regulations**: Proper business entity setup
- **Data Privacy**: GDPR compliance, clear privacy policy
- **Age Restrictions**: 17+ rating for financial features

---

## Post-MVP Roadmap

### Quarter 2
- Android app development
- Advanced analytics dashboard
- Custom workout plan builder
- Strava/Garmin integration

### Quarter 3
- Web platform launch
- Corporate wellness programs
- AI coaching features
- International expansion

### Quarter 4
- Merchandise integration
- NFT achievements
- Advanced Nostr features
- Partnership program

---

## Development Timeline Summary

| Week | Phase | Key Deliverables |
|------|-------|-----------------|
| 1-2 | Foundation | Auth, HealthKit, Core Models |
| 3-4 | Subscriptions | Payment system, Tiers |
| 5-6 | Teams | Creation, Management, Chat |
| 7-8 | Events | Virtual events platform |
| 9-10 | Rewards | Lightning, Streaks |
| 11-12 | Polish | UI/UX, Testing |
| 13 | Private Beta | 50 influencer testers |
| 14-15 | Public Beta | 1000 TestFlight users |
| 16 | Launch | App Store release |

---

*This roadmap is a living document and will be updated based on user feedback, technical constraints, and market opportunities.*