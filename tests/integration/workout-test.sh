#!/bin/bash
# Workout Tracking Test

echo "Testing Workout Tracking functionality..."

# Test workout creation and distance calculation
xcodebuild test -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:RUNSTR_IOSTests/WorkoutServiceTests
