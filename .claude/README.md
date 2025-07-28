# RUNSTR Claude Code Hooks

Comprehensive hook system for RUNSTR's Bitcoin-native fitness app development. These hooks provide automated code review, security auditing, performance optimization, and bug triage specifically tailored for RUNSTR's unique requirements.

## Hook Overview

### 1. Swift/SwiftUI Code Review Hook (`swift-review.md`)
**Triggers**: All `.swift` files
**Purpose**: Comprehensive code review focusing on:
- SwiftUI best practices and MVVM patterns
- Nostr protocol integration patterns
- Bitcoin/Lightning integration security
- HealthKit and Apple Watch optimization
- Performance and battery efficiency
- RUNSTR-specific business logic validation

### 2. Nostr Event Schema Validator (`nostr-events.md`)
**Triggers**: Nostr-related files (`**/Models/*Nostr*.swift`, `**/Services/NostrService.swift`)
**Purpose**: Validates Nostr protocol implementation:
- NIP-101e workout event compliance
- NIP-51 team list validation
- Event schema completeness
- Key delegation security
- Relay publishing efficiency
- Encryption for private training mode

### 3. Performance Optimization Hook (`performance-check.md`)
**Triggers**: Performance-critical files (HealthKit, Location, Workout services)
**Purpose**: Monitors and optimizes:
- GPS accuracy vs battery drain
- Background processing efficiency
- Memory usage during long workouts
- Apple Watch synchronization
- Network efficiency for Nostr relays
- Music streaming impact assessment

### 4. Security Audit Hook (`security-audit.md`)
**Triggers**: Bitcoin/Cashu related files, security-sensitive operations
**Purpose**: Comprehensive security review:
- Private key management and storage
- Lightning payment processing security
- Cashu token handling and validation
- Encrypted storage patterns
- Key exposure prevention
- Transaction security validation

### 5. Bug Triage Hook (`bug-triage.md`)
**Triggers**: Error reports, crash logs, user issues
**Purpose**: Automated issue categorization:
- Component classification (Tracking, Music, Teams, Payments, Nostr)
- Severity assessment based on user impact
- Impact on core features and revenue
- Subscription tier considerations
- Structured bug reporting and escalation

## Configuration Structure

```
RUNSTR IOS/
├── .claude/
│   ├── settings.json          # Hook configuration
│   ├── README.md             # This documentation
│   └── hooks/
│       ├── swift-review.md
│       ├── nostr-events.md
│       ├── performance-check.md
│       ├── security-audit.md
│       └── bug-triage.md
```

## Hook Triggers

### Automatic Code Review Triggers
- **Swift Files**: Any `.swift` file edit triggers general Swift/SwiftUI review
- **Nostr Components**: Nostr-related files trigger protocol validation
- **Performance Critical**: HealthKit, Location, Workout files trigger performance analysis
- **Security Sensitive**: Bitcoin, Cashu, wallet files trigger security audit

### User Prompt Triggers
- **Performance Issues**: Keywords like "performance", "slow", "battery", "memory"
- **Security Concerns**: Keywords like "security", "bitcoin", "private key", "cashu"
- **Nostr Questions**: Keywords like "nostr", "event", "relay", "nip"
- **Bug Reports**: Keywords like "crash", "error", "bug", "issue"

### Custom Commands
- `/review_bitcoin` - Comprehensive Bitcoin/Lightning security review
- `/review_nostr` - Nostr protocol implementation validation
- `/review_performance` - Performance optimization analysis
- `/triage_issue` - Structured bug triage and categorization

## RUNSTR-Specific Focus Areas

### Bitcoin Integration
- Secure private key generation and storage
- Lightning payment processing validation
- Cashu ecash token management
- Transaction security and validation
- Reward calculation accuracy

### Nostr Protocol
- NIP-101e workout event compliance
- NIP-51 team list management
- Event publishing efficiency
- Relay communication security
- Privacy and encryption handling

### Fitness Tracking
- GPS accuracy optimization
- Battery life preservation
- HealthKit integration patterns
- Apple Watch synchronization
- Long workout session handling

### Team Management
- Real-time synchronization
- Captain privilege validation
- Member limit enforcement
- Earning calculation (1,000 sats/month per member)
- Data consistency across relays

### Subscription Model
- Member vs Captain tier validation
- Feature access control
- Payment processing security
- Subscription restoration handling

## Usage Examples

### Automatic Hook Activation
```bash
# Editing a Swift file automatically triggers swift-review.md
claude edit RUNSTR\ IOS/Services/NostrService.swift

# This will trigger both swift-review.md and nostr-events.md hooks
```

### Manual Hook Invocation
```bash
# Use custom commands for specific reviews
claude "/review_bitcoin - analyze the BitcoinWalletService for security issues"
claude "/review_performance - check HealthKitService for battery optimization"
claude "/triage_issue - categorize this crash report in WorkoutView"
```

### User Prompt Hook Triggers
```bash
# These prompts automatically trigger relevant hooks
claude "I'm seeing performance issues with GPS tracking during long runs"
claude "Review the security of our Lightning payment implementation"
claude "Validate our Nostr event schemas for NIP compliance"
```

## Hook Benefits

### For Development
- **Automated Code Review**: Instant feedback on code quality and RUNSTR-specific patterns
- **Security Validation**: Continuous security assessment of Bitcoin/Nostr integrations
- **Performance Monitoring**: Real-time performance optimization guidance
- **Protocol Compliance**: Automatic validation against Nostr NIPs and Bitcoin standards

### For Quality Assurance
- **Consistent Standards**: Enforced coding standards across the team
- **Early Issue Detection**: Catch problems before they reach production
- **Structured Bug Reports**: Standardized issue classification and prioritization
- **Security Auditing**: Comprehensive security review of sensitive components

### For Project Management
- **Priority Assessment**: Automatic severity and impact assessment for issues
- **Component Tracking**: Clear categorization of issues by system component
- **Revenue Impact**: Assessment of issues affecting subscription revenue
- **Resource Allocation**: Data-driven decisions on development priorities

## Customization

### Adding New Hooks
1. Create new `.md` file in `.claude/hooks/` directory
2. Add trigger configuration to `settings.json`
3. Define specific patterns and analysis requirements
4. Test with relevant file modifications

### Modifying Existing Hooks
1. Edit the appropriate `.md` file in `.claude/hooks/`
2. Update trigger patterns in `settings.json` if needed
3. Test changes with representative code samples

### Project-Specific Adaptations
The hooks are specifically designed for RUNSTR's architecture and can be adapted for:
- Different Bitcoin integration approaches
- Alternative Nostr relay strategies
- Modified subscription models
- Additional fitness tracking features

## Testing the Hook System

### Validation Steps
1. Edit a Swift file to trigger automatic review
2. Test user prompt triggers with performance/security keywords
3. Verify custom commands work correctly
4. Check hook-specific analysis quality and relevance

### Expected Behavior
- Swift file edits should trigger comprehensive code review
- Security-sensitive file edits should trigger security audit
- Performance-critical file edits should trigger optimization analysis
- Bug-related prompts should trigger structured triage

## Troubleshooting

### Common Issues
- **Hooks not triggering**: Check file path patterns in `settings.json`
- **Wrong hook activated**: Verify trigger patterns match intended files
- **Missing analysis**: Ensure hook files exist in `.claude/hooks/` directory

### Configuration Validation
```bash
# Check if settings.json is valid JSON
cat .claude/settings.json | python -m json.tool

# Verify hook files exist
ls -la .claude/hooks/
```

---

This hook system provides comprehensive, automated analysis tailored specifically to RUNSTR's Bitcoin-native fitness tracking requirements, ensuring code quality, security, and performance optimization throughout the development process.