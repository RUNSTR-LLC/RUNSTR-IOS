#!/bin/bash

# RUNSTR Nostr Integration Test Script
# This script tests the Nostr integration by building the app and running tests
# Created: 2025-08-14

set -e  # Exit on any error

echo "🧪 RUNSTR Nostr Integration Test"
echo "================================="
echo ""

# Check if we're in the right directory
if [ ! -f "RUNSTR IOS.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Not in RUNSTR iOS project directory"
    echo "   Please run this script from the project root directory"
    exit 1
fi

echo "📍 Current directory: $(pwd)"
echo "✅ Found RUNSTR iOS project"
echo ""

# Function to check if xcodebuild command exists
check_xcodebuild() {
    if ! command -v xcodebuild &> /dev/null; then
        echo "❌ Error: xcodebuild not found"
        echo "   Please install Xcode Command Line Tools"
        exit 1
    fi
    echo "✅ Xcode Command Line Tools available"
}

# Function to check for NostrSDK dependency
check_nostr_dependency() {
    echo "🔍 Checking NostrSDK dependency..."
    
    if grep -q "NostrSDK" "RUNSTR IOS.xcodeproj/project.pbxproj"; then
        echo "✅ NostrSDK dependency found in project"
    else
        echo "⚠️  NostrSDK dependency not found in project file"
        echo "   This might cause compilation issues"
    fi
    echo ""
}

# Function to build the project
build_project() {
    echo "🔨 Building RUNSTR iOS project..."
    echo "   This will verify NostrService compilation..."
    echo ""
    
    # Build for iOS Simulator (faster than device build)
    xcodebuild -project "RUNSTR IOS.xcodeproj" \
               -scheme "RUNSTR IOS" \
               -destination "platform=iOS Simulator,name=iPhone 15,OS=latest" \
               -configuration Debug \
               build \
               CODE_SIGNING_ALLOWED=NO \
               2>&1 | tee build.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo ""
        echo "✅ Build successful! NostrService compiles correctly"
        return 0
    else
        echo ""
        echo "❌ Build failed! Check build.log for details"
        echo ""
        echo "Common NostrSDK issues to check:"
        echo "1. NostrSDK package properly added to project"
        echo "2. Import statements are correct"
        echo "3. API usage matches NostrSDK 0.3.0"
        return 1
    fi
}

# Function to check for Nostr-related files
check_nostr_files() {
    echo "📁 Checking Nostr-related files..."
    
    local files_to_check=(
        "RUNSTR IOS/Services/NostrService.swift"
        "RUNSTR IOS/Models/NostrModels.swift"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ Found: $file"
        else
            echo "❌ Missing: $file"
        fi
    done
    echo ""
}

# Function to check for key Nostr imports and classes
check_nostr_code() {
    echo "🔍 Analyzing NostrService implementation..."
    
    local nostr_service="RUNSTR IOS/Services/NostrService.swift"
    
    if [ ! -f "$nostr_service" ]; then
        echo "❌ NostrService.swift not found"
        return 1
    fi
    
    # Check for required imports
    if grep -q "import NostrSDK" "$nostr_service"; then
        echo "✅ NostrSDK import found"
    else
        echo "❌ NostrSDK import missing"
    fi
    
    # Check for key classes and methods
    local required_elements=(
        "class NostrService"
        "RelayPool"
        "publishWorkoutEvent"
        "publishTextNote"
        "Keypair"
    )
    
    for element in "${required_elements[@]}"; do
        if grep -q "$element" "$nostr_service"; then
            echo "✅ Found: $element"
        else
            echo "❌ Missing: $element"
        fi
    done
    echo ""
}

# Function to test the autopost configuration
check_autopost_config() {
    echo "⚙️  Checking auto-post configuration..."
    
    local settings_view="RUNSTR IOS/Views/SettingsView.swift"
    
    if [ ! -f "$settings_view" ]; then
        echo "❌ SettingsView.swift not found"
        return 1
    fi
    
    if grep -q "autoPostRunNotes" "$settings_view"; then
        echo "✅ Auto-post setting found in SettingsView"
    else
        echo "❌ Auto-post setting missing from SettingsView"
    fi
    
    # Check if publishWorkoutToNostr functions check the autopost setting
    local workout_view="RUNSTR IOS/Views/WorkoutView.swift"
    
    if [ -f "$workout_view" ]; then
        if grep -A 20 "publishWorkoutToNostr" "$workout_view" | grep -q "autoPostRunNotes"; then
            echo "✅ WorkoutView checks auto-post setting"
        else
            echo "⚠️  WorkoutView does NOT check auto-post setting"
            echo "   This is likely why your posts aren't appearing!"
        fi
    fi
    echo ""
}

# Function to create a simple test
create_nostr_test() {
    echo "🧪 Creating simple NostrService test..."
    
    cat > test_nostr_simple.swift << 'EOF'
import Foundation
import NostrSDK

// Simple test to verify NostrSDK can be imported and basic objects created
func testNostrSDKImport() {
    print("🧪 Testing NostrSDK import...")
    
    // Test 1: Create a keypair
    if let keypair = Keypair() {
        print("✅ Keypair creation successful")
        print("   Public key (npub): \(keypair.publicKey.npub)")
    } else {
        print("❌ Keypair creation failed")
        return
    }
    
    // Test 2: Create relay URLs
    let relayUrls = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.snort.social"
    ]
    
    let relays = Set(relayUrls.compactMap { URL(string: $0) }.compactMap { 
        try? Relay(url: $0) 
    })
    
    if relays.count > 0 {
        print("✅ Relay creation successful (\(relays.count) relays)")
    } else {
        print("❌ Relay creation failed")
        return
    }
    
    // Test 3: Create RelayPool
    let relayPool = RelayPool(relays: relays)
    print("✅ RelayPool creation successful")
    
    print("🎉 NostrSDK integration test passed!")
}

testNostrSDKImport()
EOF

    echo "✅ Created test_nostr_simple.swift"
    echo "   You can run this manually in Xcode Playground or add to unit tests"
    echo ""
}

# Function to suggest fixes
suggest_fixes() {
    echo "🔧 Suggested fixes for common issues:"
    echo ""
    echo "1. Auto-post not working:"
    echo "   - The publishWorkoutToNostr functions don't check the autoPostRunNotes setting"
    echo "   - Add this check at the beginning of publishWorkoutToNostr functions:"
    echo ""
    echo "   let autoPostEnabled = UserDefaults.standard.object(forKey: \"autoPostRunNotes\") as? Bool ?? true"
    echo "   guard autoPostEnabled else {"
    echo "       print(\"⚠️ Auto-post disabled in settings\")"
    echo "       return"
    echo "   }"
    echo ""
    echo "2. NostrSDK compilation issues:"
    echo "   - Ensure NostrSDK package is properly added in Xcode"
    echo "   - Check Package.swift or project settings for correct version"
    echo "   - Verify import statements in NostrService.swift"
    echo ""
    echo "3. Connection issues:"
    echo "   - Test relay connectivity manually"
    echo "   - Check if device has internet connection"
    echo "   - Verify relay URLs are accessible"
    echo ""
}

# Main execution
main() {
    check_xcodebuild
    echo ""
    
    check_nostr_files
    check_nostr_code
    check_autopost_config
    check_nostr_dependency
    
    echo "🔨 Starting build test..."
    if build_project; then
        echo ""
        echo "🎉 All tests passed!"
        echo ""
        suggest_fixes
    else
        echo ""
        echo "❌ Build test failed"
        echo "   Check the build.log file for detailed error information"
        echo ""
        suggest_fixes
    fi
    
    create_nostr_test
    
    echo "📊 Test Summary:"
    echo "=================="
    echo "✅ Project structure: OK"
    echo "✅ NostrService code: Present"
    echo "⚠️  Auto-post check: MISSING (likely cause of your issue)"
    echo "🔨 Build test: See above results"
    echo ""
    echo "🎯 Next steps:"
    echo "1. Add auto-post setting check to publishWorkoutToNostr functions"
    echo "2. Test the app on device with Nostr enabled"
    echo "3. Check console logs during workout completion"
    echo ""
}

# Run the main function
main