import Foundation
import Combine

/// Service responsible for managing unit preferences and conversions throughout the app
@MainActor
class UnitPreferencesService: ObservableObject {
    @Published var useMetricUnits: Bool = true {
        didSet {
            UserDefaults.standard.set(useMetricUnits, forKey: "useMetricUnits")
        }
    }
    
    init() {
        self.useMetricUnits = UserDefaults.standard.object(forKey: "useMetricUnits") as? Bool ?? true
    }
    
    // MARK: - Distance Conversion
    
    /// Convert meters to preferred distance unit
    func convertDistance(_ meters: Double) -> Double {
        if useMetricUnits {
            return meters / 1000.0 // Convert to kilometers
        } else {
            return meters * 0.000621371 // Convert to miles
        }
    }
    
    /// Get distance unit abbreviation
    var distanceUnit: String {
        useMetricUnits ? "km" : "mi"
    }
    
    /// Format distance with appropriate units
    func formatDistance(_ meters: Double, precision: Int = 2) -> String {
        let convertedDistance = convertDistance(meters)
        return String(format: "%.\(precision)f \(distanceUnit)", convertedDistance)
    }
    
    // MARK: - Pace Conversion
    
    /// Convert pace from min/km to preferred pace unit
    func convertPace(_ minPerKm: Double) -> Double {
        if useMetricUnits {
            return minPerKm // Already in min/km
        } else {
            return minPerKm * 1.60934 // Convert to min/mile (exact km to mile conversion)
        }
    }
    
    /// Get pace unit abbreviation
    var paceUnit: String {
        useMetricUnits ? "min/km" : "min/mi"
    }
    
    /// Format pace with appropriate units
    func formatPace(_ minPerKm: Double) -> String {
        guard minPerKm > 0 else { return "--:-- \(paceUnit)" }
        
        let convertedPace = convertPace(minPerKm)
        let minutes = Int(convertedPace)
        let seconds = Int((convertedPace - Double(minutes)) * 60)
        return String(format: "%d:%02d \(paceUnit)", minutes, seconds)
    }
    
    // MARK: - Speed Conversion
    
    /// Convert speed from m/s to preferred speed unit
    func convertSpeed(_ metersPerSecond: Double) -> Double {
        if useMetricUnits {
            return metersPerSecond * 3.6 // Convert to km/h
        } else {
            return metersPerSecond * 2.23694 // Convert to mph
        }
    }
    
    /// Get speed unit abbreviation
    var speedUnit: String {
        useMetricUnits ? "km/h" : "mph"
    }
    
    /// Format speed with appropriate units
    func formatSpeed(_ metersPerSecond: Double, precision: Int = 1) -> String {
        let convertedSpeed = convertSpeed(metersPerSecond)
        return String(format: "%.\(precision)f \(speedUnit)", convertedSpeed)
    }
    
    // MARK: - Elevation Conversion
    
    /// Convert meters to preferred elevation unit
    func convertElevation(_ meters: Double) -> Double {
        if useMetricUnits {
            return meters // Keep in meters
        } else {
            return meters * 3.28084 // Convert to feet
        }
    }
    
    /// Get elevation unit abbreviation
    var elevationUnit: String {
        useMetricUnits ? "m" : "ft"
    }
    
    /// Format elevation with appropriate units
    func formatElevation(_ meters: Double, precision: Int = 0) -> String {
        let convertedElevation = convertElevation(meters)
        return String(format: "%.\(precision)f \(elevationUnit)", convertedElevation)
    }
    
    // MARK: - Convenience Methods
    
    /// Toggle between metric and imperial units
    func toggleUnits() {
        useMetricUnits.toggle()
    }
    
    /// Get current unit system name
    var unitSystemName: String {
        useMetricUnits ? "Metric" : "Imperial"
    }
}