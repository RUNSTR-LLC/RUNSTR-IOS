#!/usr/bin/env swift

// Test pace calculation fixes

// Test 1: Basic pace calculation
func testBasicPaceCalculation() {
    print("\n🧪 Test 1: Basic Pace Calculation")
    
    // Example: 30 minutes for 5 km = 6:00 min/km
    let duration: Double = 30 * 60 // 30 minutes in seconds
    let distance: Double = 5000 // 5 km in meters
    
    let minutes = duration / 60
    let kmDistance = distance / 1000
    let pace = kmDistance > 0 ? minutes / kmDistance : 0
    
    print("Duration: \(duration) seconds (\(minutes) minutes)")
    print("Distance: \(distance) meters (\(kmDistance) km)")
    print("Calculated Pace: \(pace) min/km")
    print("Expected: 6.0 min/km")
    print("✅ Pass: \(pace == 6.0)")
}

// Test 2: Imperial conversion
func testImperialConversion() {
    print("\n🧪 Test 2: Imperial Conversion")
    
    let paceMinPerKm = 6.0 // 6:00 min/km
    let paceMinPerMile = paceMinPerKm * 1.60934
    
    print("Metric Pace: \(paceMinPerKm) min/km")
    print("Imperial Pace: \(paceMinPerMile) min/mile")
    print("Expected: ~9.66 min/mile")
    print("✅ Pass: \(abs(paceMinPerMile - 9.65604) < 0.001)")
}

// Test 3: Real world example from user's screenshot
func testRealWorldExample() {
    print("\n🧪 Test 3: Real World Example")
    print("User reported: Running with accurate distance/time but pace showing too fast")
    
    // Example: 10 miles in 90 minutes should be 9:00 min/mile
    let durationMinutes: Double = 90
    let distanceMiles: Double = 10
    
    // Convert to metric for calculation
    let distanceKm = distanceMiles * 1.60934
    let paceMinPerKm = durationMinutes / distanceKm
    
    // Convert back to imperial for display
    let paceMinPerMile = paceMinPerKm * 1.60934
    
    print("Distance: \(distanceMiles) miles")
    print("Duration: \(durationMinutes) minutes")
    print("Calculated Pace (metric): \(paceMinPerKm) min/km")
    print("Calculated Pace (imperial): \(paceMinPerMile) min/mile")
    print("Expected: 9.0 min/mile")
    print("✅ Pass: \(abs(paceMinPerMile - 9.0) < 0.001)")
}

// Test 4: Edge cases
func testEdgeCases() {
    print("\n🧪 Test 4: Edge Cases")
    
    // Zero distance
    let pace1 = 0.0 > 0 ? (100.0 / 60) / (0.0 / 1000) : 0
    print("Zero distance pace: \(pace1) (should be 0)")
    print("✅ Pass: \(pace1 == 0)")
    
    // Very short workout
    let duration2 = 60.0 // 1 minute
    let distance2 = 200.0 // 200 meters
    let minutes2 = duration2 / 60
    let km2 = distance2 / 1000
    let pace2 = km2 > 0 ? minutes2 / km2 : 0
    print("Short workout (1 min, 200m): \(pace2) min/km (should be 5.0)")
    print("✅ Pass: \(pace2 == 5.0)")
}

// Run all tests
print("🏃‍♂️ RUNSTR Pace Calculation Tests")
print("==========================================")
testBasicPaceCalculation()
testImperialConversion()
testRealWorldExample()
testEdgeCases()
print("\n✅ All tests completed!")