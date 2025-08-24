#!/bin/bash

# RUNSTR Activity Tracker Bug Fix Hook
# Comprehensive analysis and fix system for distance tracking and HealthKit permission issues
# Usage: ./scripts/activity-tracker-bugfix-hook.sh [phase]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANALYSIS_DIR="$PROJECT_ROOT/analysis"
LOGS_DIR="$PROJECT_ROOT/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create necessary directories
mkdir -p "$ANALYSIS_DIR" "$LOGS_DIR"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOGS_DIR/bugfix-$(date +%Y%m%d).log"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGS_DIR/bugfix-$(date +%Y%m%d).log"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/bugfix-$(date +%Y%m%d).log"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOGS_DIR/bugfix-$(date +%Y%m%d).log"
}

phase1_core_analysis() {
    log "🔍 Phase 1: Core System Analysis"
    
    log "Analyzing HealthKit entitlements..."
    if [ -f "$PROJECT_ROOT/RUNSTR IOS.entitlements" ]; then
        grep -i health "$PROJECT_ROOT/RUNSTR IOS.entitlements" > "$ANALYSIS_DIR/healthkit-entitlements.txt" 2>/dev/null || echo "No HealthKit entitlements found" > "$ANALYSIS_DIR/healthkit-entitlements.txt"
    else
        error "Entitlements file not found"
    fi
    
    log "Analyzing Info.plist configuration..."
    find "$PROJECT_ROOT" -name "Info.plist" -exec plutil -p {} \; > "$ANALYSIS_DIR/info-plist-dump.txt" 2>/dev/null || true
    
    log "Checking for HealthKit usage descriptions..."
    grep -r "NSHealthShareUsageDescription\|NSHealthUpdateUsageDescription" "$PROJECT_ROOT" > "$ANALYSIS_DIR/health-usage-descriptions.txt" 2>/dev/null || echo "No health usage descriptions found" > "$ANALYSIS_DIR/health-usage-descriptions.txt"
    
    log "Analyzing project capabilities..."
    find "$PROJECT_ROOT" -name "*.pbxproj" -exec grep -i health {} \; > "$ANALYSIS_DIR/xcode-health-capabilities.txt" 2>/dev/null || echo "No HealthKit capabilities found in project" > "$ANALYSIS_DIR/xcode-health-capabilities.txt"
    
    success "Phase 1 completed. Results in $ANALYSIS_DIR/"
}

phase2_distance_analysis() {
    log "📏 Phase 2: Distance Tracking Analysis"
    
    log "Analyzing location services implementation..."
    find "$PROJECT_ROOT" -name "*.swift" -exec grep -l "CLLocationManager\|CoreLocation" {} \; > "$ANALYSIS_DIR/location-files.txt"
    
    log "Analyzing distance calculation methods..."
    find "$PROJECT_ROOT" -name "*.swift" -exec grep -n "distance\|CLLocation" {} \; > "$ANALYSIS_DIR/distance-calculations.txt" 2>/dev/null || echo "No distance calculations found" > "$ANALYSIS_DIR/distance-calculations.txt"
    
    log "Checking workout tracking implementation..."
    find "$PROJECT_ROOT" -name "*.swift" -exec grep -n "HKWorkout\|HKQuantity" {} \; > "$ANALYSIS_DIR/workout-tracking.txt" 2>/dev/null || echo "No workout tracking found" > "$ANALYSIS_DIR/workout-tracking.txt"
    
    log "Analyzing GPS permissions..."
    grep -r "NSLocationWhenInUseUsageDescription\|NSLocationAlwaysUsageDescription" "$PROJECT_ROOT" > "$ANALYSIS_DIR/location-permissions.txt" 2>/dev/null || echo "No location permissions found" > "$ANALYSIS_DIR/location-permissions.txt"
    
    success "Phase 2 completed. Results in $ANALYSIS_DIR/"
}

phase3_permission_flow() {
    log "🔐 Phase 3: Permission Flow Analysis"
    
    log "Tracing HealthKit permission requests..."
    find "$PROJECT_ROOT" -name "*.swift" -exec grep -n "requestAuthorization\|HKHealthStore" {} \; > "$ANALYSIS_DIR/healthkit-permissions.txt" 2>/dev/null || echo "No HealthKit permission requests found" > "$ANALYSIS_DIR/healthkit-permissions.txt"
    
    log "Analyzing location permission requests..."
    find "$PROJECT_ROOT" -name "*.swift" -exec grep -n "requestWhenInUseAuthorization\|requestAlwaysAuthorization" {} \; > "$ANALYSIS_DIR/location-permission-requests.txt" 2>/dev/null || echo "No location permission requests found" > "$ANALYSIS_DIR/location-permission-requests.txt"
    
    log "Checking permission status handling..."
    find "$PROJECT_ROOT" -name "*.swift" -exec grep -n "authorizationStatus\|CLAuthorizationStatus" {} \; > "$ANALYSIS_DIR/permission-status-handling.txt" 2>/dev/null || echo "No permission status handling found" > "$ANALYSIS_DIR/permission-status-handling.txt"
    
    log "Analyzing onboarding/setup flow..."
    find "$PROJECT_ROOT" -name "*.swift" -exec grep -l "onboarding\|setup\|permission" {} \; > "$ANALYSIS_DIR/onboarding-files.txt" 2>/dev/null || echo "No onboarding files found" > "$ANALYSIS_DIR/onboarding-files.txt"
    
    success "Phase 3 completed. Results in $ANALYSIS_DIR/"
}

phase4_create_tests() {
    log "🧪 Phase 4: Creating Test Suite"
    
    mkdir -p "$PROJECT_ROOT/tests/integration"
    
    cat > "$PROJECT_ROOT/tests/integration/healthkit-test.sh" << 'EOF'
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
EOF

    cat > "$PROJECT_ROOT/tests/integration/location-test.sh" << 'EOF'
#!/bin/bash
# Location Services Test

echo "Testing Location Services functionality..."

# Test location permissions
xcodebuild test -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:RUNSTR_IOSTests/LocationServiceTests
EOF

    cat > "$PROJECT_ROOT/tests/integration/workout-test.sh" << 'EOF'
#!/bin/bash
# Workout Tracking Test

echo "Testing Workout Tracking functionality..."

# Test workout creation and distance calculation
xcodebuild test -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:RUNSTR_IOSTests/WorkoutServiceTests
EOF

    chmod +x "$PROJECT_ROOT/tests/integration/"*.sh
    
    success "Phase 4 completed. Test suite created in tests/integration/"
}

phase5_analyze_fixes() {
    log "🔧 Phase 5: Analyzing Required Fixes"
    
    log "Generating fix recommendations based on analysis..."
    
    cat > "$ANALYSIS_DIR/fix-recommendations.md" << 'EOF'
# RUNSTR Activity Tracker Fix Recommendations

## Critical Issues Identified

### HealthKit Permission Issues
- [ ] Check if HealthKit entitlements are properly configured
- [ ] Verify Info.plist contains required usage descriptions
- [ ] Ensure permission request flow is implemented in onboarding
- [ ] Validate HKHealthStore authorization requests

### Distance Tracking Issues  
- [ ] Verify CLLocationManager is properly initialized
- [ ] Check location permission requests
- [ ] Validate distance calculation algorithms
- [ ] Ensure workout data is properly saved to HealthKit

### Configuration Issues
- [ ] Verify Xcode project capabilities include HealthKit
- [ ] Check location services are enabled in capabilities
- [ ] Validate deployment target supports required features
- [ ] Ensure code signing includes health entitlements

## Recommended Implementation Order
1. Fix HealthKit entitlements and permissions
2. Implement proper location services setup
3. Fix distance calculation and storage
4. Add comprehensive error handling
5. Implement user-friendly permission prompts

## Testing Strategy
1. Test on physical device (required for HealthKit)
2. Verify all permissions are properly requested
3. Test workout tracking end-to-end
4. Validate data persistence and HealthKit sync
EOF

    success "Phase 5 completed. Recommendations in $ANALYSIS_DIR/fix-recommendations.md"
}

phase6_validation() {
    log "✅ Phase 6: Validation and Testing"
    
    log "Running comprehensive validation..."
    
    # Build the project
    log "Building project..."
    xcodebuild clean build -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15" > "$LOGS_DIR/build-validation.log" 2>&1
    
    if [ $? -eq 0 ]; then
        success "Project builds successfully"
    else
        error "Build failed. Check $LOGS_DIR/build-validation.log"
    fi
    
    # Run available tests
    log "Running unit tests..."
    xcodebuild test -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 15" > "$LOGS_DIR/test-validation.log" 2>&1
    
    if [ $? -eq 0 ]; then
        success "Tests passed"
    else
        warning "Some tests failed. Check $LOGS_DIR/test-validation.log"
    fi
    
    success "Phase 6 completed. Validation results in $LOGS_DIR/"
}

generate_report() {
    log "📊 Generating comprehensive bug fix report..."
    
    cat > "$ANALYSIS_DIR/bug-fix-report.md" << EOF
# RUNSTR Activity Tracker Bug Fix Report
Generated: $(date)

## Issues Analyzed
1. Distance tracking not working
2. HealthKit permissions not requested

## Analysis Summary
$([ -f "$ANALYSIS_DIR/healthkit-entitlements.txt" ] && echo "- HealthKit entitlements: $(wc -l < "$ANALYSIS_DIR/healthkit-entitlements.txt") entries found")
$([ -f "$ANALYSIS_DIR/location-files.txt" ] && echo "- Location service files: $(wc -l < "$ANALYSIS_DIR/location-files.txt") files found")
$([ -f "$ANALYSIS_DIR/healthkit-permissions.txt" ] && echo "- HealthKit permission calls: $(wc -l < "$ANALYSIS_DIR/healthkit-permissions.txt") instances found")

## Files to Review
\`\`\`
$(cat "$ANALYSIS_DIR"/*.txt 2>/dev/null | head -20)
\`\`\`

## Next Steps
1. Review analysis files in $ANALYSIS_DIR/
2. Follow recommendations in fix-recommendations.md
3. Run integration tests on physical device
4. Validate fixes with comprehensive testing

## Log Files
- Analysis logs: $LOGS_DIR/bugfix-$(date +%Y%m%d).log
- Build validation: $LOGS_DIR/build-validation.log
- Test results: $LOGS_DIR/test-validation.log
EOF

    success "Comprehensive report generated: $ANALYSIS_DIR/bug-fix-report.md"
}

main() {
    log "🚀 Starting RUNSTR Activity Tracker Bug Fix Analysis"
    log "Project root: $PROJECT_ROOT"
    
    case "${1:-all}" in
        "1"|"phase1") phase1_core_analysis ;;
        "2"|"phase2") phase2_distance_analysis ;;
        "3"|"phase3") phase3_permission_flow ;;
        "4"|"phase4") phase4_create_tests ;;
        "5"|"phase5") phase5_analyze_fixes ;;
        "6"|"phase6") phase6_validation ;;
        "report") generate_report ;;
        "all"|*)
            phase1_core_analysis
            phase2_distance_analysis
            phase3_permission_flow
            phase4_create_tests
            phase5_analyze_fixes
            phase6_validation
            generate_report
            ;;
    esac
    
    success "🎉 Bug fix analysis completed! Check $ANALYSIS_DIR/ for results."
    log "Run './scripts/activity-tracker-bugfix-hook.sh report' to regenerate the summary report."
}

main "$@"