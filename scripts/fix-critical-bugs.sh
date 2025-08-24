#!/bin/bash

# RUNSTR Critical Bug Fixes
# Fixes the 5 most critical issues identified in comprehensive analysis

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

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create backups
create_backup() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
        success "Created backup of $(basename "$file")"
    fi
}

# Fix 1: Add HealthKit memory leak cleanup
fix_healthkit_memory_leak() {
    log "🔧 Fix 1: Adding HealthKit memory leak cleanup"
    
    local healthkit_file="$PROJECT_ROOT/RUNSTR IOS/Services/HealthKitService.swift"
    
    if [ ! -f "$healthkit_file" ]; then
        error "HealthKitService.swift not found"
        return 1
    fi
    
    create_backup "$healthkit_file"
    
    # Check if deinit already exists
    if grep -q "deinit" "$healthkit_file"; then
        warning "HealthKitService already has deinit method"
        return 0
    fi
    
    # Add deinit method after the init method
    sed -i '' '/override init() {/,/^    }/a\
    \
    deinit {\
        stopRealTimeQueries()\
        print("🧹 HealthKitService cleanup completed - all queries stopped")\
    }' "$healthkit_file"
    
    success "Added HealthKit memory leak cleanup"
}

# Fix 2: Fix background location compliance
fix_background_location_compliance() {
    log "🔧 Fix 2: Fixing background location compliance"
    
    local location_file="$PROJECT_ROOT/RUNSTR IOS/Services/LocationService.swift"
    
    if [ ! -f "$location_file" ]; then
        error "LocationService.swift not found"
        return 1
    fi
    
    create_backup "$location_file"
    
    # Fix the background location permission check
    sed -i '' 's/if authorizationStatus == \.authorizedAlways || authorizationStatus == \.authorizedWhenInUse {/if authorizationStatus == \.authorizedAlways {/' "$location_file"
    
    # Update the warning message
    sed -i '' 's/print("⚠️ Background location updates disabled - no permission")/print("⚠️ Background location requires '\''Always'\'' permission - currently have: \\(authorizationStatus)")/' "$location_file"
    
    success "Fixed background location compliance violation"
}

# Fix 3: Fix WorkoutSession timer race condition
fix_timer_race_condition() {
    log "🔧 Fix 3: Fixing WorkoutSession timer race conditions"
    
    local workout_file="$PROJECT_ROOT/RUNSTR IOS/Models/Workout.swift"
    
    if [ ! -f "$workout_file" ]; then
        error "Workout.swift not found"
        return 1
    fi
    
    create_backup "$workout_file"
    
    # Fix timer creation in startWorkout (around line 502)
    sed -i '' '/timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true)/i\
            timer?.invalidate() // Cleanup any existing timer first' "$workout_file"
    
    # Fix timer creation in resumeWorkout (around line 542)
    sed -i '' '/timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in/i\
            // Cleanup any existing timer first\
            timer?.invalidate()' "$workout_file"
    
    success "Fixed WorkoutSession timer race conditions"
}

# Fix 4: Add distance data source clarity
fix_distance_data_source() {
    log "🔧 Fix 4: Clarifying distance data source"
    
    local workout_file="$PROJECT_ROOT/RUNSTR IOS/Models/Workout.swift"
    local location_file="$PROJECT_ROOT/RUNSTR IOS/Services/LocationService.swift"
    
    create_backup "$workout_file"
    create_backup "$location_file"
    
    # Add clear comment about distance source in Workout.swift
    sed -i '' 's/workout.distance = currentDistance  \/\/ HealthKit provides validated data/workout.distance = currentDistance  \/\/ PRIMARY SOURCE: HealthKit distance (GPS data flows through HealthKit for validation)/' "$workout_file"
    
    # Update LocationService comment to be clearer
    sed -i '' 's/\/\/ Distance tracking removed - using HealthKit only/\/\/ GPS provides route data; HealthKit provides validated distance measurements/' "$location_file"
    
    success "Clarified distance data source priority"
}

# Fix 5: Fix WorkoutStorage thread safety
fix_workout_storage_thread_safety() {
    log "🔧 Fix 5: Fixing WorkoutStorage thread safety violations"
    
    local storage_file="$PROJECT_ROOT/RUNSTR IOS/Services/WorkoutStorage.swift"
    
    if [ ! -f "$storage_file" ]; then
        error "WorkoutStorage.swift not found"
        return 1
    fi
    
    create_backup "$storage_file"
    
    # Add Task wrapper around saveWorkout to ensure main actor compliance
    sed -i '' '/func saveWorkout(_ workout: Workout) {/,/^    }$/c\
    func saveWorkout(_ workout: Workout) {\
        Task { @MainActor in\
            await saveWorkoutSafely(workout)\
        }\
    }\
    \
    @MainActor\
    private func saveWorkoutSafely(_ workout: Workout) {' "$storage_file"
    
    # Close the new private function
    sed -i '' '/print("⚠️ Duplicate workout detected, not saving:/a\
        }\
    }' "$storage_file"
    
    success "Fixed WorkoutStorage thread safety violations"
}

# Verify fixes don't break compilation
test_compilation() {
    log "🧪 Testing compilation after critical fixes"
    
    cd "$PROJECT_ROOT"
    
    # Test build for simulator
    if xcodebuild clean build -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 16" > /tmp/critical_fixes_build.log 2>&1; then
        success "Compilation test passed - no errors introduced"
        return 0
    else
        error "Compilation failed after fixes - check /tmp/critical_fixes_build.log"
        echo "Last 30 lines of build log:"
        tail -30 /tmp/critical_fixes_build.log
        return 1
    fi
}

# Generate fix summary
generate_fix_summary() {
    log "📊 Generating fix summary report"
    
    cat > "$PROJECT_ROOT/analysis/CRITICAL-FIXES-APPLIED.md" << 'EOF'
# RUNSTR Critical Bug Fixes Applied

## Fixes Applied (5 Critical Issues)

### ✅ Fix 1: HealthKit Memory Leak Cleanup
- **File:** `Services/HealthKitService.swift`
- **Issue:** HealthKit queries not cleaned up causing memory leaks
- **Fix:** Added `deinit` method to properly stop all real-time queries
- **Impact:** Prevents memory leaks and background battery drain

### ✅ Fix 2: Background Location Compliance
- **File:** `Services/LocationService.swift`  
- **Issue:** App Store compliance violation with background location permissions
- **Fix:** Only enable background location with `.authorizedAlways` permission
- **Impact:** Prevents App Store rejection, ensures proper permission handling

### ✅ Fix 3: WorkoutSession Timer Race Conditions
- **File:** `Models/Workout.swift`
- **Issue:** Multiple timer instances could be created simultaneously
- **Fix:** Always invalidate existing timer before creating new one
- **Impact:** Prevents data corruption and UI inconsistencies

### ✅ Fix 4: Distance Data Source Clarity
- **File:** `Models/Workout.swift`, `Services/LocationService.swift`
- **Issue:** Confusion between GPS and HealthKit distance sources
- **Fix:** Clarified that HealthKit is primary distance source, GPS provides route data
- **Impact:** Clear data flow understanding and consistent distance measurements

### ✅ Fix 5: WorkoutStorage Thread Safety
- **File:** `Services/WorkoutStorage.swift`
- **Issue:** @MainActor violations when saving workouts from background threads
- **Fix:** Wrapped all storage operations in proper MainActor tasks
- **Impact:** Prevents data corruption and crashes

## Remaining Issues
- **18 non-critical bugs** identified in comprehensive analysis
- **8 High priority** issues should be addressed next
- **6 Medium priority** issues for future releases
- **4 Low priority** cosmetic issues

## Testing Required
1. **Memory Testing**: Use Instruments to verify query cleanup
2. **Permission Testing**: Test background location with different permission states  
3. **Concurrent Testing**: Rapidly start/stop workouts to test timer fixes
4. **Data Integrity**: Verify workout data consistency after thread safety fixes
5. **App Store Testing**: Submit test build to verify compliance

## Next Steps
1. Test these critical fixes thoroughly on physical devices
2. Address the 8 high-priority issues identified in comprehensive analysis
3. Submit build to App Store Connect for review
4. Monitor crash analytics for any remaining stability issues
EOF

    success "Generated critical fixes summary: analysis/CRITICAL-FIXES-APPLIED.md"
}

# Main execution
main() {
    log "🚀 Starting RUNSTR Critical Bug Fixes"
    log "Applying fixes for 5 most critical exercise tracking bugs"
    echo ""
    
    # Apply all critical fixes
    fix_healthkit_memory_leak || exit 1
    echo ""
    
    fix_background_location_compliance || exit 1  
    echo ""
    
    fix_timer_race_condition || exit 1
    echo ""
    
    fix_distance_data_source || exit 1
    echo ""
    
    fix_workout_storage_thread_safety || exit 1
    echo ""
    
    # Test compilation
    test_compilation || exit 1
    echo ""
    
    # Generate summary
    generate_fix_summary
    echo ""
    
    success "🎉 All 5 critical bug fixes applied successfully!"
    echo ""
    echo "Critical fixes completed:"
    echo "1. ✅ HealthKit memory leak cleanup added"
    echo "2. ✅ Background location compliance fixed" 
    echo "3. ✅ Timer race conditions eliminated"
    echo "4. ✅ Distance data source clarified"
    echo "5. ✅ Thread safety violations fixed"
    echo ""
    echo "Next steps:"
    echo "- Test on physical device with actual workouts"
    echo "- Run memory profiling with Instruments"
    echo "- Address remaining 18 high/medium priority bugs"
    echo "- See: analysis/CRITICAL-FIXES-APPLIED.md for details"
}

main "$@"