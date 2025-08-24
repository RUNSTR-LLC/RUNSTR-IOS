#!/bin/bash
# HealthKit Integration Test

echo "Testing HealthKit functionality..."

# Check if running on simulator (HealthKit not available)
if xcrun simctl list | grep -q "Booted"; then
    echo "WARNING: HealthKit tests require physical device"
    exit 1
fi

# Build and test HealthKit integration
xcodebuild test -scheme "RUNSTR IOS" -destination "platform=iOS,name=iPhone" -only-testing:RUNSTR_IOSTests/HealthKitServiceTests
