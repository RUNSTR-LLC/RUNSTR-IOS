import XCTest
import HealthKit
@testable import RUNSTR_IOS

class ActivityTypeTests: XCTestCase {
    
    // MARK: - ActivityType Enum Tests
    
    func testActivityTypeAllCases() {
        // Test that we have all 3 activity types
        XCTAssertEqual(ActivityType.allCases.count, 3, "Should have exactly 3 activity types")
        
        let expectedTypes: [ActivityType] = [
            .running, .walking, .cycling
        ]
        
        for expectedType in expectedTypes {
            XCTAssertTrue(ActivityType.allCases.contains(expectedType), 
                         "Missing activity type: \(expectedType)")
        }
    }
    
    func testActivityTypeDisplayNames() {
        // Test that all activity types have proper display names
        let displayNameTests = [
            (ActivityType.running, "Running"),
            (ActivityType.walking, "Walking"),
            (ActivityType.cycling, "Cycling")
        ]
        
        for (activityType, expectedDisplayName) in displayNameTests {
            XCTAssertEqual(activityType.displayName, expectedDisplayName,
                          "Display name mismatch for \(activityType)")
        }
    }
    
    func testActivityTypeSystemImageNames() {
        // Test that all activity types have proper system image names
        let systemImageTests = [
            (ActivityType.running, "figure.run"),
            (ActivityType.walking, "figure.walk"),
            (ActivityType.cycling, "bicycle")
        ]
        
        for (activityType, expectedImageName) in systemImageTests {
            XCTAssertEqual(activityType.systemImageName, expectedImageName,
                          "System image name mismatch for \(activityType)")
        }
    }
    
    // MARK: - HealthKit Integration Tests
    
    func testHKWorkoutActivityTypeMappings() {
        // Test that all activity types map to valid HKWorkoutActivityType
        let healthKitMappingTests = [
            (ActivityType.running, HKWorkoutActivityType.running),
            (ActivityType.walking, HKWorkoutActivityType.walking),
            (ActivityType.cycling, HKWorkoutActivityType.cycling)
        ]
        
        for (activityType, expectedHKType) in healthKitMappingTests {
            XCTAssertEqual(activityType.hkWorkoutActivityType, expectedHKType,
                          "HealthKit mapping mismatch for \(activityType)")
        }
    }
    
    func testAllActivityTypesHaveValidHealthKitMappings() {
        // Ensure no activity type returns an invalid HealthKit type
        for activityType in ActivityType.allCases {
            let hkType = activityType.hkWorkoutActivityType
            
            // Test that the mapping doesn't crash and returns a valid type
            XCTAssertNotNil(hkType, "Activity type \(activityType) should map to a valid HKWorkoutActivityType")
            
            // Test that we can create a workout configuration with this type
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = hkType
            configuration.locationType = .unknown
            
            XCTAssertEqual(configuration.activityType, hkType,
                          "Should be able to create HKWorkoutConfiguration for \(activityType)")
        }
    }
    
    // MARK: - Subscription Tier Tests
    
    func testSubscriptionTierPricing() {
        // Test the corrected subscription pricing
        XCTAssertEqual(SubscriptionTier.none.monthlyPrice, 0.0, "Free tier should be $0")
        XCTAssertEqual(SubscriptionTier.member.monthlyPrice, 3.99, "Member tier should be $3.99")
        XCTAssertEqual(SubscriptionTier.captain.monthlyPrice, 19.99, "Captain tier should be $19.99")
        XCTAssertEqual(SubscriptionTier.organization.monthlyPrice, 49.99, "Organization tier should be $49.99")
    }
    
    func testSubscriptionTierProductIDs() {
        // Test that all paid tiers have proper product IDs
        XCTAssertEqual(SubscriptionTier.none.productID, "", "Free tier should have empty product ID")
        XCTAssertEqual(SubscriptionTier.member.productID, "com.runstr.ios.member.monthly", "Member product ID should be correct")
        XCTAssertEqual(SubscriptionTier.captain.productID, "com.runstr.ios.captain.monthly", "Captain product ID should be correct")
        XCTAssertEqual(SubscriptionTier.organization.productID, "com.runstr.ios.organization.monthly", "Organization product ID should be correct")
    }
    
    // MARK: - Phase 1 Integration Tests
    
    func testActivityTypeRawValueUniqueness() {
        // Ensure all raw values are unique
        let rawValues = ActivityType.allCases.map { $0.rawValue }
        let uniqueRawValues = Set(rawValues)
        
        XCTAssertEqual(rawValues.count, uniqueRawValues.count, 
                      "All ActivityType raw values should be unique")
    }
    
    func testActivityTypeCodableSupport() {
        // Test that ActivityType can be encoded and decoded
        for activityType in ActivityType.allCases {
            do {
                let encoded = try JSONEncoder().encode(activityType)
                let decoded = try JSONDecoder().decode(ActivityType.self, from: encoded)
                XCTAssertEqual(activityType, decoded, 
                              "ActivityType should be properly codable: \(activityType)")
            } catch {
                XCTFail("Failed to encode/decode ActivityType \(activityType): \(error)")
            }
        }
    }
    
    func testPerformanceOfActivityTypeMapping() {
        // Test that HealthKit mapping is performant
        measure {
            for _ in 0..<1000 {
                for activityType in ActivityType.allCases {
                    _ = activityType.hkWorkoutActivityType
                }
            }
        }
    }
}