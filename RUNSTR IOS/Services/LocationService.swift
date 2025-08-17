import Foundation
import CoreLocation
import MapKit

class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var route: [CLLocation] = []
    @Published var totalDistance: Double = 0.0
    @Published var currentSpeed: Double = 0.0 // m/s
    @Published var currentPace: Double = 0.0 // min/km
    @Published var currentAltitude: Double = 0.0 // meters
    @Published var accuracy: Double = 0.0 // meters
    @Published var isGPSReady: Bool = false
    
    private var isTracking = false
    private var isPaused = false
    private var lastLocation: CLLocation?
    private var startTime: Date?
    private var pausedTime: TimeInterval = 0
    
    // Route optimization
    private let minimumDistance: Double = 5.0 // meters
    private let minimumTimeInterval: TimeInterval = 2.0 // seconds
    private let maximumAccuracy: Double = 10.0 // meters (will be overridden by activity-specific values)
    
    // GPS drift detection and stationary filtering
    private let stationarySpeedThreshold: Double = 0.5 // m/s - below this is considered stationary
    private let movementSpeedThreshold: Double = 1.0 // m/s - above this resumes distance tracking
    private let stationaryTimeThreshold: TimeInterval = 10.0 // seconds - how long to be stationary before pausing
    private var stationaryStartTime: Date?
    private var isStationary: Bool = false
    
    // Speed validation for outlier rejection
    private let maxRunningSpeed: Double = 8.0 // m/s (18 mph)
    private let maxWalkingSpeed: Double = 4.0 // m/s (9 mph)  
    private let maxCyclingSpeed: Double = 20.0 // m/s (45 mph)
    
    // Activity-specific accuracy thresholds
    private var currentActivityType: ActivityType?
    private var activitySpecificAccuracy: Double {
        guard let activityType = currentActivityType else { return maximumAccuracy }
        switch activityType {
        case .running: return 5.0
        case .walking: return 8.0
        case .cycling: return 10.0
        }
    }
    
    // Simple Kalman filter for GPS smoothing
    private var smoothedSpeed: Double = 0.0
    private var smoothedSpeedVariance: Double = 1.0
    private let processNoise: Double = 0.1 // How much we expect speed to change
    private let measurementNoise: Double = 0.5 // GPS speed measurement uncertainty
    
    // Additional smoothing for distance calculation
    private var locationHistory: [CLLocation] = []
    private let maxHistorySize: Int = 10 // Keep last 10 locations for smoothing
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = minimumDistance
        locationManager.allowsBackgroundLocationUpdates = false // Will be enabled during tracking
        authorizationStatus = locationManager.authorizationStatus
        
        // Don't start GPS during init to avoid blocking app startup
        // GPS will be warmed up when permissions are granted or tracking starts
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            break
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    func setActivityType(_ activityType: ActivityType) {
        self.currentActivityType = activityType
        print("📍 Location service configured for \(activityType.displayName) with \(activitySpecificAccuracy)m accuracy threshold")
    }
    
    func startTracking() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            print("❌ Location permission not granted for tracking")
            requestLocationPermission()
            return
        }
        
        // Update @Published properties on main thread
        DispatchQueue.main.async {
            self.isTracking = true
            self.isPaused = false
            self.route.removeAll()
            self.totalDistance = 0.0
            self.lastLocation = nil
            self.currentSpeed = 0.0
            self.currentPace = 0.0
        }
        
        // Reset stationary detection state
        isStationary = false
        stationaryStartTime = nil
        
        // Reset Kalman filter state
        smoothedSpeed = 0.0
        smoothedSpeedVariance = 1.0
        locationHistory.removeAll()
        
        // Configure location manager (safe to do on any thread)
        startTime = Date()
        pausedTime = 0
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = minimumDistance
        
        // Enable background location for active workout tracking
        // This is allowed with "When In Use" permission during active use
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            locationManager.allowsBackgroundLocationUpdates = true
            print("✅ Enabled background location updates for workout tracking")
        } else {
            locationManager.allowsBackgroundLocationUpdates = false
            print("⚠️ Background location updates disabled - no permission")
        }
        locationManager.pausesLocationUpdatesAutomatically = false
        
        locationManager.startUpdatingLocation()
        print("✅ Started GPS tracking with high accuracy")
    }
    
    func stopTracking() {
        // Update @Published properties on main thread
        DispatchQueue.main.async {
            self.isTracking = false
            self.isPaused = false
        }
        
        locationManager.stopUpdatingLocation()
        
        // Always disable background location updates when stopping
        locationManager.allowsBackgroundLocationUpdates = false
        
        // Access totalDistance safely for logging
        let distance = totalDistance
        print("✅ Stopped GPS tracking. Total distance: \(String(format: "%.2f", distance/1000))km")
    }
    
    func pauseTracking() {
        guard isTracking else { return }
        
        // Update @Published properties on main thread
        DispatchQueue.main.async {
            self.isPaused = true
        }
        
        // Calculate paused time
        if let startTime = startTime {
            pausedTime += Date().timeIntervalSince(startTime)
        }
        
        locationManager.stopUpdatingLocation()
        print("⏸️ Paused GPS tracking")
    }
    
    func resumeTracking() {
        guard isTracking else { return }
        
        // Update @Published properties on main thread
        DispatchQueue.main.async {
            self.isPaused = false
        }
        
        startTime = Date() // Reset start time for pause calculation
        
        locationManager.startUpdatingLocation()
        print("▶️ Resumed GPS tracking")
    }
    
    var averagePace: Double {
        guard totalDistance > 0, !route.isEmpty else { return 0.0 }
        
        let totalTime = route.last?.timestamp.timeIntervalSince(route.first?.timestamp ?? Date()) ?? 0
        let distanceKm = totalDistance / 1000.0
        
        return (totalTime / 60.0) / distanceKm // minutes per km
    }
    
    var routeCoordinates: [CLLocationCoordinate2D] {
        return route.map { $0.coordinate }
    }
    
    func getElevationGain() -> Double {
        var elevationGain: Double = 0.0
        
        // Ensure we have at least 2 route points before creating range
        let routeCount = route.count
        guard routeCount >= 2 else { return 0.0 }
        
        for i in 1..<routeCount {
            let altitudeDifference = route[i].altitude - route[i-1].altitude
            if altitudeDifference > 0 {
                elevationGain += altitudeDifference
            }
        }
        
        return elevationGain
    }
    
    func getElevationLoss() -> Double {
        var elevationLoss: Double = 0.0
        
        // Ensure we have at least 2 route points before creating range
        let routeCount = route.count
        guard routeCount >= 2 else { return 0.0 }
        
        for i in 1..<routeCount {
            let altitudeDifference = route[i].altitude - route[i-1].altitude
            if altitudeDifference < 0 {
                elevationLoss += abs(altitudeDifference)
            }
        }
        
        return elevationLoss
    }
    
    func getElevationData() -> (gain: Double, loss: Double) {
        var elevationGain: Double = 0.0
        var elevationLoss: Double = 0.0
        
        // Ensure we have at least 2 route points before creating range
        let routeCount = route.count
        guard routeCount >= 2 else { return (0.0, 0.0) }
        
        for i in 1..<routeCount {
            let altitudeDifference = route[i].altitude - route[i-1].altitude
            if altitudeDifference > 0 {
                elevationGain += altitudeDifference
            } else if altitudeDifference < 0 {
                elevationLoss += abs(altitudeDifference)
            }
        }
        
        return (gain: elevationGain, loss: elevationLoss)
    }
    
    func getRouteMapItems() -> [MKMapItem] {
        let placemark = MKPlacemark(coordinate: route.first?.coordinate ?? CLLocationCoordinate2D())
        return [MKMapItem(placemark: placemark)]
    }
    
    private func getMaxSpeedForActivity() -> Double {
        guard let activityType = currentActivityType else { return maxRunningSpeed }
        switch activityType {
        case .running: return maxRunningSpeed
        case .walking: return maxWalkingSpeed
        case .cycling: return maxCyclingSpeed
        }
    }
    
    // MARK: - Kalman Filter for GPS Smoothing
    
    /// Apply simple Kalman filter to smooth speed measurements
    private func updateKalmanFilter(measuredSpeed: Double) -> Double {
        // Prediction step (assume speed stays roughly the same)
        let predictedSpeed = smoothedSpeed
        let predictedVariance = smoothedSpeedVariance + processNoise
        
        // Update step
        let kalmanGain = predictedVariance / (predictedVariance + measurementNoise)
        smoothedSpeed = predictedSpeed + kalmanGain * (measuredSpeed - predictedSpeed)
        smoothedSpeedVariance = (1 - kalmanGain) * predictedVariance
        
        return smoothedSpeed
    }
    
    /// Get smoothed distance using location history and weighted positioning
    private func getSmoothedDistance(from newLocation: CLLocation, to lastLocation: CLLocation) -> Double {
        // Add new location to history
        locationHistory.append(newLocation)
        
        // Keep history size manageable
        if locationHistory.count > maxHistorySize {
            locationHistory.removeFirst()
        }
        
        // For early locations, use simple distance
        if locationHistory.count < 3 {
            return newLocation.distance(from: lastLocation)
        }
        
        // Apply simple position smoothing based on accuracy
        let baseDistance = newLocation.distance(from: lastLocation)
        
        // If accuracy is good, use direct distance
        if newLocation.horizontalAccuracy <= 5.0 {
            return baseDistance
        }
        
        // For less accurate readings, apply smoothing
        // Use recent location trend to reduce GPS noise
        let recentLocations = Array(locationHistory.suffix(3))
        let weightedLat = recentLocations.enumerated().reduce(0.0) { sum, item in
            let (index, location) = item
            let weight = Double(index + 1) / Double(recentLocations.count)
            return sum + location.coordinate.latitude * weight
        }
        
        let weightedLon = recentLocations.enumerated().reduce(0.0) { sum, item in
            let (index, location) = item
            let weight = Double(index + 1) / Double(recentLocations.count)
            return sum + location.coordinate.longitude * weight
        }
        
        let smoothedCoordinate = CLLocationCoordinate2D(latitude: weightedLat, longitude: weightedLon)
        let smoothedLocation = CLLocation(coordinate: smoothedCoordinate, 
                                        altitude: newLocation.altitude, 
                                        horizontalAccuracy: newLocation.horizontalAccuracy, 
                                        verticalAccuracy: newLocation.verticalAccuracy, 
                                        timestamp: newLocation.timestamp)
        
        return smoothedLocation.distance(from: lastLocation)
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update current location for GPS readiness indicator
        DispatchQueue.main.async {
            self.currentLocation = location
            self.currentAltitude = location.altitude
            self.accuracy = location.horizontalAccuracy
            self.isGPSReady = location.horizontalAccuracy <= self.activitySpecificAccuracy
        }
        
        // Only process location updates if actively tracking and not paused
        guard isTracking && !isPaused else { return }
        
        // Filter out old, inaccurate, or invalid locations
        let locationAge = -location.timestamp.timeIntervalSinceNow
        guard locationAge < 5.0,
              location.horizontalAccuracy > 0,
              location.horizontalAccuracy <= activitySpecificAccuracy else {
            print("⚠️ Filtered out location: age=\(locationAge)s, accuracy=\(location.horizontalAccuracy)m (threshold: \(activitySpecificAccuracy)m)")
            return
        }
        
        // Check minimum distance and time requirements
        if let lastLoc = lastLocation {
            let distance = location.distance(from: lastLoc)
            let timeInterval = location.timestamp.timeIntervalSince(lastLoc.timestamp)
            
            // Skip if too close or too soon (prevents GPS noise)
            guard distance >= minimumDistance || timeInterval >= minimumTimeInterval else {
                return
            }
            
            // Calculate current speed for validation and stationary detection
            let rawCalculatedSpeed = timeInterval > 0 ? distance / timeInterval : 0.0
            
            // Use CLLocation's built-in speed if available and valid, otherwise use calculated
            let measuredSpeed: Double
            if location.speed >= 0 && location.speedAccuracy < 5.0 {
                // CLLocation provides reliable speed measurement
                measuredSpeed = location.speed
            } else {
                // Fall back to calculated speed
                measuredSpeed = rawCalculatedSpeed
            }
            
            // Apply Kalman filter for smoothing
            let currentCalculatedSpeed = updateKalmanFilter(measuredSpeed: measuredSpeed)
            
            // Speed validation - reject impossible speeds based on activity type
            let maxAllowedSpeed = getMaxSpeedForActivity()
            if currentCalculatedSpeed > maxAllowedSpeed {
                print("⚠️ Rejected location with impossible speed: \(String(format: "%.1f", currentCalculatedSpeed))m/s (max: \(maxAllowedSpeed)m/s)")
                return
            }
            
            // GPS drift detection and stationary filtering
            if currentCalculatedSpeed <= stationarySpeedThreshold {
                // User appears to be stationary
                if stationaryStartTime == nil {
                    stationaryStartTime = Date()
                    print("🛑 Potential stationary period detected (speed: \(String(format: "%.2f", currentCalculatedSpeed))m/s)")
                } else if let startTime = stationaryStartTime,
                          Date().timeIntervalSince(startTime) >= stationaryTimeThreshold {
                    // User has been stationary long enough - pause distance tracking
                    if !isStationary {
                        isStationary = true
                        print("⏸️ Stationary mode activated - pausing distance tracking")
                    }
                    // Skip distance accumulation but continue adding to route for visualization
                    DispatchQueue.main.async {
                        self.route.append(location)
                        self.lastLocation = location
                        self.currentSpeed = 0.0
                        self.currentPace = 0.0
                    }
                    return
                }
            } else if currentCalculatedSpeed >= movementSpeedThreshold {
                // User is moving again - resume tracking
                if isStationary {
                    isStationary = false
                    print("▶️ Movement detected - resuming distance tracking (speed: \(String(format: "%.2f", currentCalculatedSpeed))m/s)")
                }
                stationaryStartTime = nil
            }
            
            // Only accumulate distance if not in stationary mode
            if !isStationary {
                // Get smoothed distance for more accurate tracking
                let smoothedDistance = getSmoothedDistance(from: location, to: lastLoc)
                
                // Calculate running metrics
                DispatchQueue.main.async {
                    self.totalDistance += smoothedDistance
                    
                    if timeInterval > 0 && smoothedDistance > 0 {
                        // Use smoothed speed from Kalman filter
                        self.currentSpeed = currentCalculatedSpeed
                        
                        // Current pace (min/km) using smoothed speed
                        if self.currentSpeed > 0.1 { // Avoid division by very small numbers
                            self.currentPace = (1000.0 / self.currentSpeed) / 60.0
                        }
                    }
                }
                print("📍 Distance added: \(String(format: "%.1f", smoothedDistance))m (raw: \(String(format: "%.1f", distance))m), Smoothed Speed: \(String(format: "%.2f", currentCalculatedSpeed))m/s")
            }
        }
        
        // Add location to route (if not already added in stationary mode)
        if !isStationary {
            DispatchQueue.main.async {
                self.route.append(location)
                self.lastLocation = location
            }
        }
        
        print("📍 Location updated: accuracy=\(String(format: "%.1f", location.horizontalAccuracy))m, distance=\(String(format: "%.0f", totalDistance))m")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        switch status {
        case .authorizedWhenInUse:
            print("✅ Location permission granted (when in use)")
            // Don't start GPS immediately - wait until tracking is needed
            
        case .authorizedAlways:
            print("✅ Location permission granted (always) - background tracking available")
            // Don't start GPS immediately - wait until tracking is needed
            
        case .denied:
            print("❌ Location permission denied")
            stopTracking()
            
        case .restricted:
            print("❌ Location permission restricted")
            stopTracking()
            
        case .notDetermined:
            print("⚠️ Location permission not determined")
            
        @unknown default:
            print("⚠️ Unknown location authorization status: \(status.rawValue)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed: \(error.localizedDescription)")
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("❌ Location access denied")
            case .locationUnknown:
                print("⚠️ Location unknown - continuing to try")
            case .network:
                print("❌ Network error while getting location")
            default:
                print("❌ Other location error: \(clError.localizedDescription)")
            }
        }
    }
}