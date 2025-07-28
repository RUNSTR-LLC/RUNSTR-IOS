# Bug Triage Hook for RUNSTR

Automatically analyze and categorize bugs and crashes for RUNSTR iOS app components. Provide structured triage with severity assessment and component classification:

## Component Classification

### Activity Tracking Issues
- **GPS/Location Service**: Location accuracy, route tracking, background processing
- **HealthKit Integration**: Data sync, permissions, Apple Watch connectivity
- **Workout Management**: Start/stop functionality, data persistence, metric calculation
- **Performance Tracking**: Battery drain, memory usage, long workout handling

### Music Integration Issues
- **Apple Music API**: Playlist access, streaming, background playback
- **Audio Management**: Volume control, audio routing, interruption handling
- **Workout Integration**: Music controls during workouts, audio focus management
- **Offline Support**: Downloaded music, network transition handling

### Team Management Issues
- **Team Discovery**: Search functionality, filtering, recommendation engine
- **Team Synchronization**: Real-time updates, member roster changes, captain privileges
- **Communication**: Team chat, activity sharing, notification delivery
- **Data Consistency**: Team state synchronization, conflict resolution

### Payment & Bitcoin Issues
- **Lightning Integration**: Payment processing, invoice generation, fee calculation
- **Cashu Operations**: Token management, mint communication, proof validation
- **Wallet Management**: Balance updates, transaction history, withdrawal processing
- **Security**: Key management, transaction validation, fraud prevention

### Nostr Protocol Issues
- **Event Publishing**: Workout data publishing, event format validation, relay communication
- **Key Management**: Private key security, public key validation, delegation handling
- **Relay Connectivity**: Connection management, failover, offline synchronization
- **Data Privacy**: Encryption, metadata protection, selective sharing

## Severity Assessment Matrix

### Critical (P0) - Immediate Fix Required
- **User Fund Loss**: Any issue that could result in Bitcoin/Cashu token loss
- **Data Corruption**: Health data corruption or loss
- **Security Breach**: Private key exposure, unauthorized access
- **App Crashes**: Consistent crashes during core workflows
- **Payment Failures**: Lightning payments failing to process

### High (P1) - Fix Within 24-48 Hours
- **Core Feature Broken**: GPS tracking failure, workout recording issues
- **Subscription Issues**: Payment processing for subscription tiers
- **Team Functionality**: Cannot join/create teams, data sync failures
- **Performance Degradation**: Severe battery drain, memory leaks
- **Apple Watch Sync**: Complete failure of Watch integration

### Medium (P2) - Fix Within 1-2 Weeks
- **Minor Feature Issues**: UI glitches, cosmetic problems
- **Performance Issues**: Slow loading, minor battery drain
- **Notification Problems**: Delayed or missing notifications
- **Music Integration**: Non-critical music playback issues
- **Analytics Issues**: Metrics tracking problems

### Low (P3) - Fix in Next Release Cycle
- **Enhancement Requests**: Feature improvements, UX optimizations
- **Minor UI Issues**: Cosmetic improvements, accessibility enhancements
- **Documentation**: Code documentation, user guide updates
- **Testing Improvements**: Additional test coverage, test automation

## Impact Assessment Framework

### User Impact Scoring
```
Business Impact = (Affected Users × Severity × Revenue Impact)

Critical Business Features:
- Workout tracking and GPS accuracy
- Bitcoin reward distribution
- Team synchronization and social features
- Apple Watch integration
- Subscription payment processing
```

### Subscription Tier Impact
- **Member Tier ($5.99/mo)**: Issues affecting basic tracking, team joining, event participation
- **Captain Tier ($20.99/mo)**: Issues affecting team creation, event hosting, advanced analytics
- **Revenue Impact**: Prioritize issues that could cause subscription cancellations

### Platform-Specific Considerations
- **iOS Version Compatibility**: Issues affecting specific iOS versions
- **Device Models**: iPhone vs Apple Watch specific issues
- **Network Conditions**: WiFi vs cellular vs offline scenarios

## Bug Analysis Template

### Issue Description
```markdown
## Bug Report: [Component] - [Brief Description]

### Environment
- iOS Version: 
- Device Model: 
- App Version: 
- Subscription Tier: 
- Network Condition: 

### Classification
- **Component**: [Activity Tracking/Music/Teams/Payments/Nostr]
- **Severity**: [Critical/High/Medium/Low]
- **Category**: [Crash/Data Loss/Performance/UI/Integration]

### Impact Assessment
- **Affected Users**: [Estimated percentage]
- **Core Feature Impact**: [Yes/No - specify which core features]
- **Revenue Impact**: [Direct subscription impact assessment]
- **Workaround Available**: [Yes/No - describe if available]

### Technical Analysis
- **Root Cause**: [Initial assessment]
- **Related Components**: [List interconnected systems]
- **Risk Factors**: [Security, data integrity, performance implications]

### Reproduction Steps
1. [Detailed steps to reproduce]
2. [Include specific test data/scenarios]
3. [Note any required setup or conditions]

### Expected vs Actual Behavior
- **Expected**: [What should happen]
- **Actual**: [What actually happens]
- **Screenshots/Logs**: [Attach relevant evidence]

### Immediate Actions Required
- [ ] Security assessment (if applicable)
- [ ] User communication plan
- [ ] Hotfix vs scheduled fix decision
- [ ] Testing strategy
- [ ] Rollback plan (if needed)
```

## RUNSTR-Specific Triage Rules

### Bitcoin/Financial Issues (Always Critical)
- Any issue affecting user Bitcoin balances
- Lightning payment failures or double-charges
- Cashu token loss or corruption
- Unauthorized transactions or wallet access
- Reward calculation errors leading to incorrect payouts

### Core Fitness Features (High Priority)
- GPS tracking accuracy issues affecting reward calculation
- HealthKit data sync failures
- Apple Watch workout disconnection
- Workout data loss or corruption
- Background tracking failures

### Team & Social Features (Medium-High Priority)
- Team synchronization failures affecting captain earnings
- Event participation issues affecting rewards
- Communication system failures
- Member roster inconsistencies

### Performance Issues (Variable Priority)
- Battery drain: High if severe (>20% per hour), Medium otherwise
- Memory leaks: High if causing crashes, Medium if gradual
- Network efficiency: Medium unless affecting core functionality
- UI responsiveness: Low unless blocking user workflows

## Automated Triage Logic

### Log Pattern Recognition
```swift
// Crash log analysis patterns
let criticalPatterns = [
    "private key",           // Security issue
    "cashu.*failed",        // Payment issue  
    "healthkit.*denied",    // Core feature issue
    "location.*failed",     // GPS tracking issue
    "subscription.*error"   // Revenue issue
]

let performancePatterns = [
    "memory.*warning",      // Memory issue
    "battery.*drain",       // Battery issue
    "network.*timeout",     // Connectivity issue
    "sync.*failed"         // Data sync issue
]
```

### Automated Severity Assignment
1. **Critical**: Contains security keywords, payment failures, data corruption
2. **High**: Core feature failures, crash during essential workflows
3. **Medium**: Performance degradation, non-essential feature issues
4. **Low**: UI cosmetic issues, minor inconveniences

## Testing & Validation Strategy

### Reproduction Testing
- **Environment Setup**: Specific iOS version, device model, network conditions
- **Data State**: User subscription tier, team membership, workout history
- **Integration Testing**: Test with actual Bitcoin testnet, Nostr relays
- **Edge Cases**: Low battery, poor network, device storage full

### Fix Validation
- **Regression Testing**: Ensure fix doesn't break related functionality
- **Performance Testing**: Validate performance impact of fix
- **Security Testing**: Verify security implications of changes
- **User Acceptance**: Test fix addresses original user pain point

## Escalation Procedures

### Critical Issue Response
1. **Immediate Assessment**: Security and financial impact evaluation
2. **User Communication**: Proactive user notification if needed
3. **Hotfix Deployment**: Expedited fix and App Store review
4. **Post-Incident Review**: Root cause analysis and prevention measures

### High Priority Issues
1. **Priority Assignment**: Assign to appropriate development team
2. **Timeline Commitment**: Establish fix timeline and communicate
3. **Progress Tracking**: Regular status updates and milestone tracking
4. **Quality Assurance**: Thorough testing before release

## Provide Structured Bug Report

For each analyzed issue, provide:
1. **Component Classification**: Specific RUNSTR component affected
2. **Severity Justification**: Clear reasoning for severity assignment
3. **Impact Analysis**: User impact, revenue impact, technical debt
4. **Immediate Actions**: Security assessment, user communication, workarounds
5. **Fix Timeline**: Recommended timeline based on severity and complexity
6. **Testing Strategy**: Specific testing approach for verification
7. **Prevention Measures**: How to prevent similar issues in the future

Focus on quick, accurate triage that enables rapid response to issues affecting RUNSTR's core Bitcoin-native fitness tracking functionality.