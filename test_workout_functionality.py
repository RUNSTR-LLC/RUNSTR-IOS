#!/usr/bin/env python3
"""
RUNSTR Workout Functionality Test Script
Comprehensive testing checklist for workout start functionality
"""

import subprocess
import json
import time
from dataclasses import dataclass
from typing import List, Dict, Any

@dataclass
class TestCase:
    name: str
    description: str
    steps: List[str]
    expected_result: str
    priority: str  # CRITICAL, HIGH, MEDIUM, LOW

class RunstrWorkoutTester:
    def __init__(self):
        self.test_results = []
        
    def run_xcode_build(self) -> bool:
        """Build the project to verify compilation"""
        print("🔨 Building RUNSTR iOS project...")
        try:
            result = subprocess.run([
                'xcodebuild', 
                '-scheme', 'RUNSTR IOS', 
                '-destination', 'platform=iOS Simulator,name=iPhone 16',
                'build'
            ], 
            cwd='/Users/dakotabrown/RUNSTR-IOS',
            capture_output=True, 
            text=True, 
            timeout=300
            )
            
            if result.returncode == 0:
                print("✅ Build successful")
                return True
            else:
                print(f"❌ Build failed: {result.stderr}")
                return False
        except Exception as e:
            print(f"❌ Build error: {str(e)}")
            return False
    
    def get_test_cases(self) -> List[TestCase]:
        """Define comprehensive test cases"""
        return [
            TestCase(
                name="Fresh Install Permission Flow",
                description="Test workout start on fresh install with no pre-granted permissions",
                steps=[
                    "1. Delete app from simulator/device",
                    "2. Clean build and install",
                    "3. Launch app",
                    "4. Tap 'Start Running' button",
                    "5. Verify HealthKit permission prompt appears",
                    "6. Grant HealthKit permission", 
                    "7. Verify Location permission prompt appears",
                    "8. Grant Location permission",
                    "9. Verify workout starts successfully",
                    "10. Check GPS tracking begins",
                    "11. Verify UI updates with metrics"
                ],
                expected_result="Permissions requested in order, workout starts successfully",
                priority="CRITICAL"
            ),
            
            TestCase(
                name="Permission Denial Handling",
                description="Test behavior when permissions are denied",
                steps=[
                    "1. Fresh install",
                    "2. Tap 'Start Running'", 
                    "3. Deny HealthKit permission",
                    "4. Verify graceful failure (no crash)",
                    "5. Repeat with Location permission denied",
                    "6. Verify appropriate user feedback"
                ],
                expected_result="App handles denials gracefully, provides user feedback",
                priority="HIGH"
            ),
            
            TestCase(
                name="Background Threading Safety",
                description="Verify no threading violations during workout start",
                steps=[
                    "1. Start workout with permissions granted",
                    "2. Monitor console for threading warnings",
                    "3. Verify no 'Publishing changes from background threads' errors",
                    "4. Verify no UIKit main thread violations"
                ],
                expected_result="No threading violations or warnings",
                priority="CRITICAL"
            ),
            
            TestCase(
                name="Location Service Integration",
                description="Test GPS tracking during workout",
                steps=[
                    "1. Start workout",
                    "2. Verify GPS accuracy indicator",
                    "3. Simulate location changes (if in simulator)",
                    "4. Verify distance/pace calculations update",
                    "5. Verify map updates with route"
                ],
                expected_result="GPS tracking works, metrics calculate correctly",
                priority="HIGH"
            ),
            
            TestCase(
                name="HealthKit Integration", 
                description="Test HealthKit data collection",
                steps=[
                    "1. Start workout",
                    "2. Verify HealthKit session starts",
                    "3. Check heart rate collection (if available)",
                    "4. Verify calorie calculation",
                    "5. End workout and verify HealthKit save"
                ],
                expected_result="HealthKit data collection and saving works",
                priority="HIGH"
            ),
            
            TestCase(
                name="App State Transitions",
                description="Test workout during app backgrounding/foregrounding", 
                steps=[
                    "1. Start workout",
                    "2. Background app",
                    "3. Wait 30 seconds",
                    "4. Foreground app", 
                    "5. Verify workout still active",
                    "6. Verify data continued collecting"
                ],
                expected_result="Workout persists through state changes",
                priority="MEDIUM"
            ),
            
            TestCase(
                name="Error Recovery",
                description="Test handling of error conditions",
                steps=[
                    "1. Start workout with poor GPS signal",
                    "2. Verify app doesn't crash",
                    "3. Test with airplane mode enabled mid-workout",
                    "4. Test with low battery warnings",
                    "5. Verify graceful error handling"
                ],
                expected_result="App handles errors gracefully without crashing",
                priority="MEDIUM"
            ),
            
            TestCase(
                name="Multiple Activity Types",
                description="Test different workout types (Running, Walking, Cycling)",
                steps=[
                    "1. Test 'Start Running' flow",
                    "2. Test 'Start Walking' flow", 
                    "3. Test 'Start Cycling' flow",
                    "4. Verify each type starts correctly",
                    "5. Verify appropriate HealthKit activity type set"
                ],
                expected_result="All activity types work correctly",
                priority="HIGH"
            ),
            
            TestCase(
                name="Memory and Performance",
                description="Monitor memory usage and performance during workout",
                steps=[
                    "1. Monitor memory usage before workout",
                    "2. Start workout",
                    "3. Run for 5+ minutes",
                    "4. Monitor for memory leaks",
                    "5. Check CPU usage",
                    "6. Verify smooth UI performance"
                ],
                expected_result="No memory leaks, acceptable performance",
                priority="LOW"
            ),
            
            TestCase(
                name="Edge Cases",
                description="Test edge cases and boundary conditions",
                steps=[
                    "1. Start workout with 0.0 distance",
                    "2. Test with negative time intervals",
                    "3. Test with empty location arrays",
                    "4. Test splits calculation with minimal data",
                    "5. Verify no crashes with edge case data"
                ],
                expected_result="No crashes with edge case inputs",
                priority="MEDIUM"
            )
        ]
    
    def print_test_plan(self):
        """Print the comprehensive test plan"""
        test_cases = self.get_test_cases()
        
        print("🧪 RUNSTR WORKOUT FUNCTIONALITY TEST PLAN")
        print("=" * 50)
        
        priority_order = ["CRITICAL", "HIGH", "MEDIUM", "LOW"]
        
        for priority in priority_order:
            priority_tests = [tc for tc in test_cases if tc.priority == priority]
            if priority_tests:
                print(f"\n📋 {priority} PRIORITY TESTS ({len(priority_tests)} tests)")
                print("-" * 30)
                
                for i, test in enumerate(priority_tests, 1):
                    print(f"\n{priority[0]}{i}. {test.name}")
                    print(f"   Description: {test.description}")
                    print(f"   Expected: {test.expected_result}")
                    print(f"   Steps:")
                    for step in test.steps:
                        print(f"      {step}")
    
    def run_build_test(self):
        """Run the build test and report results"""
        print("\n🔧 AUTOMATED BUILD TEST")
        print("=" * 30)
        
        build_success = self.run_xcode_build()
        if build_success:
            print("✅ BUILD TEST PASSED - Code compiles successfully")
        else:
            print("❌ BUILD TEST FAILED - Fix compilation errors first")
        
        return build_success
    
    def check_critical_code_patterns(self):
        """Check for critical code patterns that could cause crashes"""
        print("\n🔍 STATIC CODE ANALYSIS")
        print("=" * 30)
        
        issues_found = []
        
        # Check for permission flows
        try:
            with open('/Users/dakotabrown/RUNSTR-IOS/RUNSTR IOS/Views/DashboardView.swift', 'r') as f:
                dashboard_content = f.read()
                if 'requestPermissions()' in dashboard_content:
                    print("✅ DashboardView has permission checking")
                else:
                    print("❌ DashboardView missing permission checks")
                    issues_found.append("DashboardView missing permission checks")
        except Exception as e:
            print(f"❌ Could not analyze DashboardView: {e}")
            
        # Check for threading safety
        try:
            with open('/Users/dakotabrown/RUNSTR-IOS/RUNSTR IOS/Services/LocationService.swift', 'r') as f:
                location_content = f.read()
                if 'DispatchQueue.main.async' in location_content:
                    print("✅ LocationService has main thread dispatching")
                else:
                    print("❌ LocationService missing main thread safety")
                    issues_found.append("LocationService threading issues")
        except Exception as e:
            print(f"❌ Could not analyze LocationService: {e}")
            
        return issues_found
    
    def generate_test_report(self):
        """Generate a comprehensive test report"""
        print("\n📊 RUNSTR WORKOUT TESTING REPORT")
        print("=" * 50)
        
        print(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Test Cases Defined: {len(self.get_test_cases())}")
        
        # Run automated checks
        build_passed = self.run_build_test()
        code_issues = self.check_critical_code_patterns()
        
        print(f"\n📈 AUTOMATED TEST RESULTS:")
        print(f"   Build Success: {'✅ PASS' if build_passed else '❌ FAIL'}")
        print(f"   Code Issues Found: {len(code_issues)}")
        
        if code_issues:
            print(f"\n⚠️  ISSUES REQUIRING ATTENTION:")
            for issue in code_issues:
                print(f"   - {issue}")
        
        # Risk assessment
        risk_level = "HIGH" if code_issues or not build_passed else "MEDIUM"
        print(f"\n🎯 RISK ASSESSMENT: {risk_level}")
        
        if risk_level == "HIGH":
            print("   ⚠️  Critical issues found - high chance of crashes")
            print("   ⚠️  Manual testing required before deployment")
        else:
            print("   ✅ Basic checks passed - ready for manual testing")
        
        print(f"\n📋 RECOMMENDED TESTING ORDER:")
        print(f"   1. Fix any critical issues found")
        print(f"   2. Run CRITICAL priority tests first")
        print(f"   3. Test on physical device with fresh install")
        print(f"   4. Run full test suite")
        
        return {
            'build_passed': build_passed,
            'code_issues': code_issues,
            'risk_level': risk_level,
            'total_test_cases': len(self.get_test_cases())
        }

def main():
    tester = RunstrWorkoutTester()
    
    print("🏃 RUNSTR iOS Workout Functionality Tester")
    print("=" * 50)
    print("This script provides comprehensive testing for workout start functionality")
    print("and identifies potential issues before manual testing.\n")
    
    # Generate full report
    report = tester.generate_test_report()
    
    # Print test plan
    tester.print_test_plan()
    
    print(f"\n💡 NEXT STEPS:")
    if report['code_issues']:
        print(f"   1. Fix the {len(report['code_issues'])} critical issues identified")
        print(f"   2. Re-run this script to verify fixes")
        print(f"   3. Proceed with manual testing")
    else:
        print(f"   1. Run CRITICAL priority tests on physical device")
        print(f"   2. Test fresh install scenario thoroughly") 
        print(f"   3. Verify no crashes occur during workout start")
    
    print(f"\n📄 Full analysis available in: WORKOUT_ISSUES_ANALYSIS.md")

if __name__ == "__main__":
    main()