# RUNSTR iOS Configuration Guide

## Required Info.plist Entries

Add these entries to your project's Info.plist file (or in Xcode's Target Settings):

### HealthKit Permissions
```xml
<key>NSHealthShareUsageDescription</key>
<string>RUNSTR needs access to read your health data including heart rate, workouts, and activity data to track your fitness activities and provide accurate metrics.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>RUNSTR needs permission to save your workout data to HealthKit so it can be shared with other health apps and your Apple Watch.</string>
```

### Location Permissions
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>RUNSTR needs access to your location to track your route, distance, and pace during workouts.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>RUNSTR needs location access to continue tracking your workout in the background, ensuring accurate distance and route recording even when the app is not active.</string>
```

### Background Modes
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
</array>
```

## Xcode Project Settings

### Capabilities

1. **HealthKit**
   - Enable HealthKit capability in your target
   - Configure HealthKit entitlements

2. **Background Modes**
   - Enable "Location updates" background mode
   - Enable "Background processing" background mode

### Privacy Settings

1. **Location Privacy**
   - Configure location usage descriptions
   - Test both "When In Use" and "Always" authorization

2. **HealthKit Privacy**
   - Configure health data usage descriptions
   - Test HealthKit authorization flow

## Testing Requirements

### Physical Device Required
- HealthKit and precise location require testing on physical iOS device
- Simulator will not provide realistic HealthKit or GPS data

### Location Testing
1. Test outdoor GPS tracking accuracy
2. Verify background location continues during workouts
3. Test pause/resume functionality
4. Verify route recording and distance calculation

### HealthKit Testing
1. Test heart rate data collection during workouts
2. Verify calorie calculation accuracy
3. Test workout session start/stop/pause
4. Verify data saves to HealthKit correctly

## Battery Optimization

The enhanced tracking includes several battery optimization features:

1. **GPS Filtering**: Filters out inaccurate locations to reduce GPS usage
2. **Distance Filtering**: Only processes location updates that meet minimum distance thresholds
3. **Background Management**: Properly manages background location access
4. **Pause Handling**: Stops GPS tracking when workout is paused

## Deployment Notes

### App Store Review
- Apps using location and HealthKit require clear privacy explanations
- Provide detailed descriptions of how health and location data is used
- Ensure compliance with Apple's health app guidelines

### Privacy Compliance
- Health data never leaves the device without explicit user consent
- Location data is only used for workout tracking
- Clear opt-out mechanisms for data collection