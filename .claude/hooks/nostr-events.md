# Nostr Event Schema Validator for RUNSTR

Analyze this Nostr event implementation for RUNSTR's Bitcoin-native fitness tracking. Validate against protocol specifications and RUNSTR's specific requirements:

## Event Kind Validation & NIP Compliance

### Workout Data Events (NIP-101e)
- **Event Kind**: Validate proper use of kind numbers for workout tracking
- **Content Structure**: JSON schema validation for workout metrics
- **Required Fields**: Distance, duration, activity type, GPS coordinates (if outdoor)
- **Optional Fields**: Heart rate data, pace/speed, elevation, route mapping
- **Data Integrity**: Timestamp accuracy, GPS coordinate validation, metric consistency

### Team Management Events (NIP-51)
- **List Structure**: Proper formatting for team member lists
- **Metadata Handling**: Team names, descriptions, privacy settings
- **Member References**: Correct npub formatting and validation
- **Captain Privileges**: Event publishing permissions, team modification rights
- **Dynamic Updates**: Real-time roster changes, member join/leave events

### Challenge/Event Management
- **Event Creation**: Proper structure for community challenges
- **Participation Tracking**: Event join/leave mechanisms
- **Leaderboard Data**: Score calculation and ranking events
- **Reward Distribution**: Bitcoin reward allocation events

## Schema Completeness Analysis

### Workout Event Schema
```json
{
  "kind": [validate_workout_kind],
  "content": {
    "activity_type": "running|walking|cycling|other",
    "distance_meters": number,
    "duration_seconds": number,
    "start_time": "ISO8601_timestamp",
    "end_time": "ISO8601_timestamp", 
    "gps_route": [{"lat": number, "lon": number, "timestamp": string}],
    "heart_rate": {"avg": number, "max": number, "zones": []},
    "pace": {"avg_pace_per_km": number},
    "elevation": {"gain_meters": number, "loss_meters": number},
    "weather": {"temperature_c": number, "conditions": string},
    "equipment": {"shoes": string, "device": string}
  },
  "tags": [
    ["t", "workout"],
    ["activity", activity_type],
    ["team", team_id_if_applicable]
  ]
}
```

### Team List Schema (NIP-51)
```json
{
  "kind": 30001,
  "content": "",
  "tags": [
    ["d", "team_identifier"],
    ["title", "Team Name"],
    ["description", "Team Description"],
    ["p", "member_npub_1", "relay_url", "member_role"],
    ["p", "member_npub_2", "relay_url", "member_role"],
    ["privacy", "public|private"],
    ["captain", "captain_npub"],
    ["max_members", "500"],
    ["activity_focus", "running|cycling|mixed"]
  ]
}
```

## Key Delegation & Security Validation

### Delegation Implementation
- **Authority Chain**: Validate delegation tokens and signing authority
- **Permission Scope**: Verify delegation only covers intended operations
- **Expiration Handling**: Check timestamp validity and expiration logic
- **Revocation Mechanism**: Proper handling of revoked delegations

### Key Management Security
- **Private Key Protection**: Ensure nsec never appears in event content
- **Signature Validation**: Verify all events are properly signed
- **Public Key Format**: Validate npub formatting and checksum
- **Multi-Key Support**: Handle multiple keypairs for different purposes

## Encryption for Private Training Mode

### Private Workout Data
- **Content Encryption**: NIP-04 or NIP-44 implementation validation
- **Key Exchange**: Secure sharing of encrypted content with authorized parties
- **Selective Sharing**: Granular privacy controls for different data types
- **Team Privacy**: Private team workout data accessible only to members

### Encryption Schema Validation
```json
{
  "kind": [encrypted_kind],
  "content": "encrypted_json_content",
  "tags": [
    ["p", "recipient_pubkey"],
    ["encrypted"]
  ]
}
```

## Relay Publishing Logic

### Relay Strategy
- **Multiple Relays**: Redundant publishing to prevent data loss
- **Relay Selection**: Optimal relay choice based on latency and reliability
- **Fallback Handling**: Graceful degradation when primary relays fail
- **Rate Limiting**: Respect relay limits, implement backoff strategies

### Publishing Validation
- **Event Broadcasting**: Verify successful publishing to minimum relay count
- **Conflict Resolution**: Handle duplicate events and ordering issues
- **Retry Logic**: Exponential backoff for failed publications
- **Network Resilience**: Offline queue management, sync on reconnection

## Data Integrity & Performance

### Workout Data Validation
- **Metric Consistency**: Validate distance/duration/pace relationships
- **GPS Accuracy**: Check for impossible speeds or teleportation
- **Heart Rate Bounds**: Validate physiologically reasonable heart rates
- **Activity Type Matching**: Ensure metrics align with declared activity

### Team Synchronization
- **Member Limits**: Enforce 500 member maximum for Captain teams
- **Role Validation**: Verify captain privileges and member permissions
- **Update Ordering**: Handle concurrent team modifications gracefully
- **Cache Consistency**: Local team state matches relay data

## RUNSTR-Specific Validations

### Subscription Tier Integration
- **Feature Access**: Validate team creation rights based on subscription tier
- **Member Limits**: Different limits for Member vs Captain subscriptions
- **Event Publishing**: Check permissions for creating challenges/events

### Bitcoin Reward Integration
- **Reward Calculation**: Validate workout-to-reward conversion accuracy
- **Anti-Gaming**: Detect suspicious activity patterns or data manipulation
- **Audit Trail**: Comprehensive logging for reward distribution

### Performance Metrics
- **Event Size**: Monitor event payload sizes for efficiency
- **Publishing Latency**: Track time from workout completion to event publication
- **Sync Performance**: Measure team data synchronization speed

## Provide Specific Improvements

For each validation issue, provide:
1. **Schema Violation**: Exact field or structure that's incorrect
2. **NIP Reference**: Cite specific NIP sections being violated
3. **Corrected Schema**: Show proper event structure
4. **Security Impact**: Explain potential security or privacy implications
5. **RUNSTR Integration**: How this affects Bitcoin rewards or team features

## Testing Recommendations
- Unit tests for event schema validation
- Integration tests for relay publishing
- Security tests for encryption/decryption
- Performance tests for large team synchronization

Ensure all Nostr events maintain protocol compliance while supporting RUNSTR's unique Bitcoin-native fitness tracking and team management features.