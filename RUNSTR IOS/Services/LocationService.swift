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
    
    private var isTracking = false
    private var lastLocation: CLLocation?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // meters
        authorizationStatus = locationManager.authorizationStatus
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
    
    func startTracking() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestLocationPermission()
            return
        }
        
        isTracking = true
        route.removeAll()
        totalDistance = 0.0
        lastLocation = nil
        
        locationManager.startUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
    }
    
    func pauseTracking() {
        locationManager.stopUpdatingLocation()
    }
    
    func resumeTracking() {
        guard isTracking else { return }
        locationManager.startUpdatingLocation()
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
        
        for i in 1..<route.count {
            let altitudeDifference = route[i].altitude - route[i-1].altitude
            if altitudeDifference > 0 {
                elevationGain += altitudeDifference
            }
        }
        
        return elevationGain
    }
    
    func getRouteMapItems() -> [MKMapItem] {
        let placemark = MKPlacemark(coordinate: route.first?.coordinate ?? CLLocationCoordinate2D())
        return [MKMapItem(placemark: placemark)]
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, isTracking else { return }
        
        // Filter out old or inaccurate locations
        let locationAge = -location.timestamp.timeIntervalSinceNow
        guard locationAge < 5.0 && location.horizontalAccuracy < 20 else { return }
        
        currentLocation = location
        route.append(location)
        
        // Calculate distance and speed
        if let lastLoc = lastLocation {
            let distance = location.distance(from: lastLoc)
            totalDistance += distance
            
            let timeInterval = location.timestamp.timeIntervalSince(lastLoc.timestamp)
            if timeInterval > 0 {
                currentSpeed = distance / timeInterval // m/s
                
                // Calculate current pace (min/km)
                if currentSpeed > 0 {
                    currentPace = (1000.0 / currentSpeed) / 60.0 // min/km
                }
            }
        }
        
        lastLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking {
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            stopTracking()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}