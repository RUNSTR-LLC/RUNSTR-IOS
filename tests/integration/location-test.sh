#!/bin/bash
# Location Services Test

echo "Testing Location Services functionality..."

# Test location permissions
xcodebuild test -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:RUNSTR_IOSTests/LocationServiceTests
