# Swift/SwiftUI Code Review Hook for RUNSTR

Review this Swift code for RUNSTR fitness app with focus on Bitcoin-native fitness tracking. Apply expert-level analysis considering:

## Core Architecture Review
- **SwiftUI Best Practices**: Proper use of @StateObject, @ObservableObject, @Published patterns
- **MVVM Implementation**: Clean separation between Views, ViewModels, and Services
- **Memory Management**: Retain cycles, weak references, proper lifecycle management
- **Error Handling**: Comprehensive error states and user feedback

## RUNSTR-Specific Integration Patterns

### Nostr Protocol Integration
- **NIP Compliance**: Validate event structures against NIP-101e (workout data) and NIP-51 (team lists)
- **Key Management**: Secure npub/nsec generation, storage in iOS Keychain
- **Relay Communication**: Efficient connection handling, fallback strategies, offline support
- **Event Publishing**: Proper signature validation and timestamp handling
- **Privacy Considerations**: User-controlled data sharing levels

### Bitcoin/Lightning Integration
- **Cashu Protocol**: Proper ecash token handling, mint validation, proof management
- **Security Patterns**: No private key exposure in logs, secure withdrawal mechanisms
- **Transaction Flow**: Error handling for failed payments, network timeouts
- **Balance Management**: Real-time updates, synchronization between local and remote state

### HealthKit & Activity Tracking
- **Authorization Flow**: Proper permission requests, graceful degradation
- **Background Processing**: Efficient data sync without draining battery
- **Apple Watch Integration**: WatchKit connectivity, data synchronization patterns
- **Data Accuracy**: GPS precision vs battery optimization, heart rate validation
- **Privacy Compliance**: Health data never leaving user control

### Performance Optimization
- **Battery Efficiency**: Background location tracking optimization
- **Memory Usage**: Efficient handling during long workout sessions
- **Network Efficiency**: Batch Nostr relay operations, minimize redundant requests
- **UI Responsiveness**: Async/await patterns, main thread considerations

## RUNSTR Business Logic Validation

### Subscription Model Implementation
- **Tier Validation**: Member ($5.99) vs Captain ($20.99) feature access
- **Payment Integration**: App Store Connect compliance, subscription restoration
- **Feature Gates**: Proper access control for team creation, event hosting

### Team Management Logic
- **Captain Earnings**: 1,000 sats/month per team member calculation accuracy
- **Team Size Limits**: Validate 500 member maximum for Captain-created teams
- **Data Synchronization**: Real-time team roster updates via Nostr

### Reward Calculation System
- **Distance/Duration Mapping**: Accurate conversion to Bitcoin rewards
- **Anti-Gaming Measures**: Validation against unrealistic activity patterns
- **Fair Distribution**: Transparent reward algorithms

## Code Quality Standards

### Swift Language Features
- **Modern Swift**: Utilize latest language features appropriately
- **Type Safety**: Strong typing, avoid force unwrapping where possible
- **Concurrency**: Proper async/await usage, actor patterns for thread safety
- **Protocol Design**: Clean abstractions, testable interfaces

### iOS Integration
- **Lifecycle Management**: Proper handling of app states, background modes
- **Permissions**: Location, HealthKit, notifications - graceful handling
- **Accessibility**: VoiceOver support, Dynamic Type compatibility
- **Localization**: String externalization, RTL layout support

## Security & Privacy Analysis

### Cryptographic Implementation
- **Key Generation**: Secure randomness for Nostr keypairs
- **Data Encryption**: Proper encryption for sensitive workout data in private mode
- **Signature Validation**: Verify all Nostr event signatures
- **Secure Storage**: Keychain usage for sensitive data

### Data Protection
- **PII Handling**: Minimize collection, secure processing
- **Health Data**: HIPAA-adjacent compliance patterns
- **Financial Data**: Secure handling of Bitcoin transactions
- **Audit Trail**: Comprehensive logging without exposing sensitive data

## Provide Specific Improvements

For each identified issue, provide:
1. **Problem Description**: Clear explanation of the concern
2. **Code Example**: Show the problematic pattern
3. **Recommended Fix**: Provide corrected implementation
4. **Rationale**: Explain why this change improves the code
5. **RUNSTR Context**: How this relates to app's Bitcoin/fitness focus

## Testing Recommendations
- Unit test coverage for critical paths (rewards calculation, Nostr events)
- Integration test patterns for HealthKit/Apple Watch sync
- Security test scenarios for Bitcoin handling
- Performance test guidelines for long workout sessions

Focus on maintainability, security, and user experience while preserving RUNSTR's unique Bitcoin-native fitness tracking capabilities.