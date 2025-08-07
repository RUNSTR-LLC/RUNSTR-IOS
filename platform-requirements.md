# RUNSTR Platform - Team and Event Management Requirements

## Overview

This document outlines the specific requirements for team and event management features that enable fitness organizations and influencers to monetize their audience through the RUNSTR platform.

---

## Team Management System

### Team Creation (Captain/Organization Tier)

#### Team Setup Wizard
- **Basic Information**:
  - Team name (required, 3-50 characters)
  - Team description (required, 10-500 characters)
  - Activity focus (select multiple: running, cycling, walking, strength, yoga, swimming, etc.)
  - Team type (Running Club, Cycling Group, Mixed Fitness, Corporate Wellness)

- **Team Configuration**:
  - Maximum members (Captain: up to 500, Organization: unlimited)
  - Team visibility (Public, Private, Invite-Only)
  - Geographic focus (optional: city/region for local discovery)
  - Activity level (Beginner, Intermediate, Advanced, All Levels)

- **Branding Options**:
  - Team logo/image upload
  - Team colors (primary/secondary)
  - Social media links (Instagram, Twitter, website)
  - Team motto/slogan (optional)

#### Team Management Dashboard
- **Member Management**:
  - Member roster with join dates
  - Activity levels and engagement metrics
  - Remove member functionality
  - Invite new members (via code or link)
  - Member roles (Captain, Co-Captain, Member)

- **Revenue Tracking**:
  - Current member count
  - Monthly recurring revenue (MRR)
  - Revenue history and projections
  - Payment status and failed payments

- **Team Analytics**:
  - Team activity summary (total distance, workouts, active members)
  - Member engagement metrics
  - Popular workout types
  - Peak activity times
  - Retention rates

### Team Discovery & Joining

#### Browse/Search Interface
- **Search Functionality**:
  - Text search by team name or description
  - Filter by activity type (running, cycling, etc.)
  - Filter by location/region
  - Filter by team size (small <50, medium 50-200, large 200+)
  - Filter by activity level

- **Team Cards Display**:
  - Team name and logo
  - Member count and activity level
  - Recent activity preview
  - Join button with subscription prompt
  - Team rating/reviews (future feature)

#### Team Pages
- **Overview Tab**:
  - Team description and mission
  - Captain information
  - Activity focus and requirements
  - Recent team achievements
  - Member statistics

- **Chat Tab**:
  - Team-wide text messaging
  - Announcements (Captain/Co-Captain only)
  - Message history (subscription tier dependent)
  - File sharing (images) for Captain+ tiers

- **Challenges Tab**:
  - Active team challenges
  - Leaderboard for current challenges
  - Challenge history and results
  - Create new challenge (Captain only)

### Team Features

#### Chat System
- **Basic Messaging**:
  - Text messages only (MVP)
  - Real-time message delivery
  - Message history retention:
    - Free tier: 24 hours
    - Member tier: 7 days
    - Captain tier: unlimited

- **Advanced Features** (Post-MVP):
  - Photo/video sharing
  - Voice messages
  - Message reactions
  - Thread replies
  - Push notifications

#### Team Challenges
- **Challenge Types**:
  - Distance challenges (weekly/monthly)
  - Consistency challenges (workout streaks)
  - Activity-specific challenges
  - Time-based challenges (fastest 5K, etc.)

- **Challenge Management**:
  - Create challenge with rules and duration
  - Set prizes/rewards for winners
  - Automatic progress tracking via HealthKit
  - Leaderboard updates in real-time

---

## Virtual Events Platform

### Event Creation System

#### Event Setup Wizard
- **Event Basics**:
  - Event name and description
  - Event type (5K, 10K, Half Marathon, Monthly Challenge, Custom)
  - Start/end dates and times
  - Registration deadline

- **Event Configuration**:
  - Activity type (running, cycling, walking, mixed)
  - Difficulty level (Beginner, Intermediate, Advanced)
  - Maximum participants (optional)
  - Age restrictions (if any)
  - Equipment requirements

- **Monetization Settings**:
  - Event ticket price (free to $100+)
  - Early bird pricing
  - Team discounts
  - Prize pool allocation
  - Revenue splits (if partnered)

#### Event Rules & Requirements
- **Participation Rules**:
  - Minimum fitness requirements
  - Required workout completion criteria
  - Time windows for completion
  - Verification methods (HealthKit sync required)

- **Prize Structure**:
  - 1st place: 40% of prize pool
  - 2nd place: 30% of prize pool
  - 3rd place: 20% of prize pool
  - Participation bonus: 10% distributed equally

### Event Discovery & Registration

#### Public Events Feed
- **Event Listings**:
  - Upcoming events with countdown timers
  - Featured events (promoted/sponsored)
  - Filter by activity type, difficulty, date
  - Search by organizer or event name

- **Event Details Page**:
  - Complete event information
  - Organizer profile and credibility
  - Registration count and availability
  - Comments/questions section
  - Share functionality

#### Registration Flow
- **Registration Process**:
  - Account verification required
  - Payment processing (if paid event)
  - Terms and conditions acceptance
  - Emergency contact information
  - Fitness level self-assessment

- **Payment Integration**:
  - Apple Pay for iOS users
  - Lightning payments (Bitcoin)
  - Refund policies and processing
  - Failed payment handling

### Event Participation & Management

#### Live Event Experience
- **Real-time Leaderboards**:
  - Live ranking updates during event
  - Progress tracking for participants
  - Split times and intermediate checkpoints
  - Social sharing of achievements

- **Participant Dashboard**:
  - Personal progress tracking
  - Comparison with other participants
  - Encouragement messages from organizers
  - Achievement unlocks

#### Event Management (Organizers)
- **Participant Management**:
  - Registration roster and status
  - Communication tools (mass messages)
  - Participant support and FAQ
  - Disqualification tools (if needed)

- **Event Analytics**:
  - Registration metrics and conversion
  - Revenue tracking and projections
  - Participation rates and completion
  - Feedback and ratings summary

- **Prize Distribution**:
  - Automatic winner determination
  - Prize pool calculation and distribution
  - Bitcoin/Lightning payment processing
  - Winner announcement tools

---

## Platform Integration Requirements

### HealthKit Sync Enhancement
- **Expanded Activity Types**:
  - Current: Running, Walking, Cycling
  - Required: Strength Training, Yoga, Swimming, HIIT, Boxing, Dance, etc.
  - Map HKWorkoutActivityType to platform ActivityType

- **Enhanced Data Collection**:
  - Workout intensity and heart rate zones
  - Calories burned and active energy
  - Workout splits and intervals
  - GPS route data (when available)

### Subscription Integration
- **Team Subscription Flow**:
  - Team selection during subscription
  - Revenue distribution to selected team captain
  - Team switching options
  - Failed payment handling and grace periods

- **Tier-Based Features**:
  - Free: View teams/events, limited chat
  - Member: Join teams, full chat, event participation
  - Captain: Create teams, earn revenue, event creation
  - Organization: Multiple teams, public events, analytics

### Data Architecture

#### Team Data Model
```swift
struct Team {
    let id: String
    let name: String
    let description: String
    let captainID: String
    let createdAt: Date
    var memberIDs: [String]
    let maxMembers: Int
    let activityTypes: [ActivityType]
    let teamType: TeamType
    let location: String?
    let branding: TeamBranding
    var stats: TeamStats
    var settings: TeamSettings
}
```

#### Event Data Model
```swift
struct Event {
    let id: String
    let name: String
    let description: String
    let organizerID: String
    let eventType: EventType
    let activityType: ActivityType
    let startDate: Date
    let endDate: Date
    let registrationDeadline: Date
    let ticketPrice: Double
    let maxParticipants: Int?
    var participants: [EventParticipant]
    let prizePool: Int
    var leaderboard: [LeaderboardEntry]
    let rules: EventRules
}
```

---

## Technical Implementation Notes

### Real-time Updates
- **WebSocket/Socket.io** for live chat and leaderboards
- **Push notifications** for team messages and event updates
- **Background sync** for workout data and team stats

### Performance Considerations
- **Lazy loading** for team member lists and event participants
- **Caching strategy** for frequently accessed team data
- **Pagination** for long message histories and large events
- **Image optimization** for team logos and event media

### Security & Privacy
- **Team invite codes** with expiration
- **Content moderation** for chat and team descriptions
- **Privacy settings** for member visibility
- **GDPR compliance** for EU users

---

## Success Metrics

### Team Platform KPIs
- **Team Creation Rate**: 50+ new teams per month
- **Team Retention**: 80% of teams active after 90 days
- **Member-to-Captain Ratio**: 100:1 average
- **Chat Engagement**: 20+ messages per team per week

### Event Platform KPIs
- **Event Creation Rate**: 200+ events per month
- **Registration Conversion**: 15% of event views → registrations
- **Event Completion Rate**: 70% of registered participants
- **Revenue per Event**: $500 average for paid events

### Platform Health Metrics
- **Monthly Active Teams**: 1000+ teams with recent activity
- **Average Team Size**: 50-100 members
- **Captain Earnings**: $200+ average monthly income
- **Event Organizer Satisfaction**: 4.5+ stars average rating

---

This requirements document will guide the development of the team and event management features that are core to RUNSTR's platform business model.