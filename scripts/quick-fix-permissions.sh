#!/bin/bash

# RUNSTR Quick Fix Script - Critical Permission Issues
# Fixes the most critical permission flow issues identified in bug analysis

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fix 1: Add permission requests to app launch
fix_app_launch_permissions() {
    log "🔧 Fix 1: Adding permission requests to app launch"
    
    local app_file="$PROJECT_ROOT/RUNSTR IOS/RUNSTR_IOSApp.swift"
    
    if [ ! -f "$app_file" ]; then
        error "App file not found: $app_file"
        return 1
    fi
    
    # Check if the fix is already applied
    if grep -q "await requestInitialPermissions()" "$app_file"; then
        warning "Permission fix already applied to app launch"
        return 0
    fi
    
    # Create backup
    cp "$app_file" "$app_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Apply the fix using sed
    sed -i '' '/workoutSession\.configure(/,/)/s|)$|)\
                    \
                    // Request initial permissions for HealthKit and location\
                    await requestInitialPermissions()|' "$app_file"
    
    if [ $? -eq 0 ]; then
        success "Added permission requests to app launch"
    else
        error "Failed to apply fix to app launch"
        return 1
    fi
}

# Fix 2: Verify permission method is properly accessible
verify_permission_method() {
    log "🔍 Fix 2: Verifying permission method accessibility"
    
    local app_file="$PROJECT_ROOT/RUNSTR IOS/RUNSTR_IOSApp.swift"
    
    # Check if requestInitialPermissions method exists and is accessible
    if grep -q "private func requestInitialPermissions" "$app_file"; then
        warning "requestInitialPermissions is private - this might cause issues"
        
        # Make it internal for better accessibility
        sed -i '' 's/private func requestInitialPermissions/func requestInitialPermissions/' "$app_file"
        success "Made requestInitialPermissions accessible"
    elif grep -q "func requestInitialPermissions" "$app_file"; then
        success "requestInitialPermissions method is properly accessible"
    else
        error "requestInitialPermissions method not found"
        return 1
    fi
}

# Fix 3: Add location usage description check
verify_location_permissions() {
    log "🔍 Fix 3: Verifying location permission descriptions"
    
    local info_plist="$PROJECT_ROOT/RUNSTR IOS/Info.plist"
    
    if [ ! -f "$info_plist" ]; then
        error "Info.plist not found: $info_plist"
        return 1
    fi
    
    # Check for location usage descriptions
    if grep -q "NSLocationWhenInUseUsageDescription" "$info_plist"; then
        success "Location usage descriptions are present"
    else
        warning "Location usage descriptions might be missing"
        
        # Add basic location usage description
        cat >> "$info_plist.additional" << 'EOF'

<!-- Add these to your Info.plist if missing -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>RUNSTR needs location access to track your workout routes and provide accurate distance measurements during exercise sessions.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>RUNSTR needs location access to track your workout routes and provide accurate distance measurements, including background tracking during active workouts.</string>
EOF
        
        warning "Location permission descriptions saved to Info.plist.additional"
        warning "Please add them manually to your Info.plist if not already present"
    fi
}

# Fix 4: Create a simple test script
create_permission_test() {
    log "🧪 Fix 4: Creating permission test script"
    
    cat > "$PROJECT_ROOT/scripts/test-permissions.sh" << 'EOF'
#!/bin/bash

# Simple test script for RUNSTR permissions
echo "📱 RUNSTR Permission Test"
echo "========================"
echo ""
echo "1. Delete app from device if installed"
echo "2. Install fresh build from Xcode"
echo "3. Launch app and verify:"
echo "   ✓ HealthKit permission prompt appears within 30 seconds"
echo "   ✓ Location permission prompt appears"
echo "   ✓ Both permissions can be granted"
echo "4. Start a test workout and verify:"
echo "   ✓ GPS tracking begins"
echo "   ✓ Distance starts accumulating"
echo "   ✓ Data saves to HealthKit"
echo ""
echo "⚠️  This test requires a physical iOS device (HealthKit not available on simulator)"
echo ""
echo "To run this test:"
echo "1. Connect physical iOS device"
echo "2. Run: xcodebuild clean build -scheme 'RUNSTR IOS' -destination 'platform=iOS,name=YourDevice'"
echo "3. Install and test manually"
EOF
    
    chmod +x "$PROJECT_ROOT/scripts/test-permissions.sh"
    success "Created permission test script at scripts/test-permissions.sh"
}

# Build test to verify fixes don't break compilation
test_build() {
    log "🔨 Testing build after fixes"
    
    cd "$PROJECT_ROOT"
    
    # Test build for simulator first
    if xcodebuild clean build -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15" > /tmp/runstr_build.log 2>&1; then
        success "Build test passed - no compilation errors"
    else
        error "Build test failed - check /tmp/runstr_build.log for errors"
        echo "Last 20 lines of build log:"
        tail -20 /tmp/runstr_build.log
        return 1
    fi
}

# Main execution
main() {
    log "🚀 Starting RUNSTR Permission Quick Fix"
    log "Fixing critical permission flow issues..."
    echo ""
    
    # Apply fixes
    fix_app_launch_permissions || exit 1
    echo ""
    
    verify_permission_method || exit 1
    echo ""
    
    verify_location_permissions || exit 1
    echo ""
    
    create_permission_test || exit 1
    echo ""
    
    # Test build
    test_build || exit 1
    echo ""
    
    success "🎉 Quick fixes completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Test build on physical device: ./scripts/test-permissions.sh"
    echo "2. Verify permission prompts appear on fresh install"
    echo "3. Test distance tracking on known route"
    echo ""
    echo "For detailed analysis, see: analysis/CRITICAL-BUG-ANALYSIS.md"
    echo "For full bug fix process, run: ./scripts/activity-tracker-bugfix-hook.sh"
}

main "$@"