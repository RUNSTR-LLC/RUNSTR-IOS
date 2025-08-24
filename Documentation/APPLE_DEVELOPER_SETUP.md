# Apple Developer Portal Configuration for RUNSTR iOS

## Overview
This guide covers the required Apple Developer portal configurations to enable RUNSTR iOS for TestFlight distribution with Apple Sign-In, HealthKit, and Location Services.

## Prerequisites
✅ Apple Developer Program membership (paid account required)
✅ RUNSTR iOS project configured with proper Bundle Identifier

## Step 1: Configure App Identifier & Capabilities

### 1.1 Create/Update App Identifier
1. Go to [Apple Developer Portal](https://developer.apple.com) → Certificates, Identifiers & Profiles
2. Navigate to **Identifiers** → **App IDs**
3. Find your RUNSTR app identifier or create new one:
   - **Description**: RUNSTR iOS App
   - **Bundle ID**: `com.yourteam.runstr` (use your actual bundle ID)

### 1.2 Enable Required Capabilities
In the App Identifier configuration, enable these capabilities:

**✅ Sign In with Apple**
- Required for user authentication
- No additional configuration needed

**✅ HealthKit** 
- Required for workout tracking and health data
- No additional configuration needed at identifier level

**✅ Background Modes**
- Select "Location updates" 
- Required for continuous GPS tracking during workouts

**✅ App Groups** (Optional but recommended)
- Create app group: `group.com.yourteam.runstr`
- For sharing data between app and potential watch extension

## Step 2: Create Provisioning Profiles

### 2.1 Development Provisioning Profile
1. Go to **Profiles** → **Development**
2. Click **+** to create new profile
3. Select **iOS App Development**
4. Choose your RUNSTR App ID
5. Select your development certificates
6. Select development devices for testing
7. Name: "RUNSTR iOS Development"
8. Download and install in Xcode

### 2.2 Distribution Provisioning Profile  
1. Go to **Profiles** → **Distribution**
2. Click **+** to create new profile
3. Select **App Store**
4. Choose your RUNSTR App ID
5. Select distribution certificate
6. Name: "RUNSTR iOS Distribution"
7. Download and install in Xcode

## Step 3: Xcode Project Configuration

### 3.1 Signing & Capabilities
In Xcode, select your project → Target → **Signing & Capabilities**:

1. **Team**: Select your Apple Developer team
2. **Bundle Identifier**: Match your App ID
3. **Provisioning Profile**: Select appropriate profile

### 3.2 Add Capabilities in Xcode
Click **+ Capability** and add:

**✅ Sign In with Apple**
- Automatically configures entitlements

**✅ HealthKit**
- Adds HealthKit.framework
- Configures health data entitlements

**✅ Background Modes**
- Enable "Location updates"
- Enable "Background processing" (for data sync)

## Step 4: Info.plist Verification

Ensure these keys exist in your Info.plist (✅ already configured):

```xml
<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>RUNSTR needs access to read your health data...</string>

<key>NSHealthUpdateUsageDescription</key>
<string>RUNSTR needs permission to save your workout data...</string>

<!-- Location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>RUNSTR needs access to your location...</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>RUNSTR needs location access to continue tracking...</string>

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
</array>

<!-- Sign In with Apple -->
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

## Step 5: Build & Archive for TestFlight

### 5.1 Build Configuration
1. Select **Generic iOS Device** as destination
2. Set scheme to **Release** mode
3. Ensure signing is configured correctly

### 5.2 Create Archive
1. **Product** → **Archive**
2. Wait for archive to complete
3. Xcode Organizer will open automatically

### 5.3 Upload to App Store Connect
1. In Xcode Organizer, select your archive
2. Click **Distribute App**
3. Select **App Store Connect**
4. Choose **Upload**
5. Review and upload

## Step 6: App Store Connect Configuration

### 6.1 App Information
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your RUNSTR app
3. Fill in required metadata:
   - **App Name**: RUNSTR
   - **Subtitle**: Run. Earn. Connect.
   - **Category**: Health & Fitness
   - **Content Rights**: Contains Bitcoin rewards

### 6.2 TestFlight Setup
1. Go to **TestFlight** tab
2. Select your uploaded build
3. Fill in:
   - **What to Test**: Core functionality - Apple Sign-In, workout tracking, Bitcoin rewards
   - **Test Information**: Instructions for testers
4. Add internal testers (your team)
5. Submit for Beta App Review

## Step 7: Privacy & Compliance

### 7.1 App Privacy Configuration
Configure data collection in App Store Connect:

**✅ Health & Fitness Data**
- Purpose: Workout tracking and performance analytics
- Linked to user identity: Yes

**✅ Precise Location Data** 
- Purpose: GPS tracking during workouts
- Linked to user identity: Yes

**✅ Email Address**
- Purpose: Account creation (Apple Sign-In)
- Linked to user identity: Yes

### 7.2 Bitcoin/Cryptocurrency Compliance
- Ensure compliance with App Store Guidelines 3.1.5(b)
- Bitcoin rewards are earned through fitness activity
- No purchase of Bitcoin within app

## Troubleshooting

### Common Issues

**❌ "Sign In with Apple" not working**
- Verify capability enabled in both Developer Portal and Xcode
- Check bundle identifier matches exactly
- Ensure using production Apple Sign-In (not simulator)

**❌ HealthKit authorization failing**
- Must test on physical device (not simulator)
- Check Info.plist usage descriptions
- Verify HealthKit capability enabled

**❌ Location permission denied**
- Check Info.plist usage descriptions
- Test background location on device
- Verify background modes enabled

**❌ Archive/Upload failing** 
- Check provisioning profile validity
- Ensure distribution certificate not expired
- Verify bundle identifier matches App ID

## Testing Checklist

Before TestFlight submission, verify:

- ✅ Apple Sign-In creates account and generates Nostr keys
- ✅ HealthKit permissions granted and workout data collected
- ✅ Location permissions granted and GPS tracking works
- ✅ Completed workouts publish to Nostr relays
- ✅ Bitcoin rewards awarded via Cashu protocol
- ✅ App works on multiple iOS devices (iPhone 12+)
- ✅ Background workout tracking functions properly

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Sign In with Apple Guide](https://developer.apple.com/sign-in-with-apple/)
- [HealthKit Programming Guide](https://developer.apple.com/documentation/healthkit/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [TestFlight Beta Testing](https://developer.apple.com/testflight/)

---

**Status**: All technical implementation is complete. This guide covers the Apple Developer portal configuration needed for TestFlight distribution.