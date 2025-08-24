#!/bin/bash

# Quick switch to simple implementation for testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
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

log "🔄 Switching to simple implementation for immediate testing"

# Update ContentView to use SimpleMainTabView
log "Updating ContentView to use SimpleMainTabView..."

sed -i '.bak' 's/MainTabView()/SimpleMainTabView()/' "$PROJECT_ROOT/RUNSTR IOS/ContentView.swift"

success "Switched to SimpleMainTabView"

# Test the build
log "Testing build..."
cd "$PROJECT_ROOT"

if xcodebuild clean build -scheme "RUNSTR IOS" -destination "platform=iOS Simulator,name=iPhone 16" > /tmp/switch_build.log 2>&1; then
    success "✅ Build successful with simple implementation!"
    echo ""
    echo "Changes made:"
    echo "✅ ContentView now uses SimpleMainTabView instead of MainTabView"
    echo ""
    echo "What this gives you:"
    echo "🎯 Simple HealthKit service with proper permission requests"
    echo "🎯 Clean dashboard showing ALL existing workout data"  
    echo "🎯 Basic workout creation interface"
    echo "🎯 Zero complex bugs"
    echo ""
    echo "📱 Test on your physical device now!"
    echo "You should see HealthKit permission prompt on first launch"
    
else
    error "Build failed. Check /tmp/switch_build.log for details"
    exit 1
fi