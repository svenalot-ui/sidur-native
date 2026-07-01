import Foundation
import CoreLocation

// Wraps CoreLocation. Reports a GeoLoc (with reverse-geocoded city name) via `onUpdate`.
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    var onUpdate: ((GeoLoc) -> Void)?
    var onHeading: ((Double) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break   // denied/restricted → keep the current fallback
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        var loc = GeoLoc(lat: c.latitude, lng: c.longitude, name: nil)
        DispatchQueue.main.async { [weak self] in self?.onUpdate?(loc) }
        // Reverse geocode for a city label (best-effort).
        geocoder.reverseGeocodeLocation(CLLocation(latitude: c.latitude, longitude: c.longitude)) { [weak self] places, _ in
            if let p = places?.first {
                loc.name = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? p.country
                DispatchQueue.main.async { self?.onUpdate?(loc) }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the existing fallback location.
    }

    // MARK: compass heading
    func startHeading() {
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }
    func stopHeading() { manager.stopUpdatingHeading() }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading h: CLHeading) {
        let v = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        DispatchQueue.main.async { [weak self] in self?.onHeading?(v) }
    }
}
