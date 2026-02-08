import CoreLocation
import Foundation

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<[String: AnyCodable], Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPermissionIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    var isAuthorized: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    func getLocation(accuracy: String) async throws -> [String: AnyCodable] {
        requestPermissionIfNeeded()

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.desiredAccuracy = accuracy == "precise"
                ? kCLLocationAccuracyBest
                : kCLLocationAccuracyHundredMeters
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let result: [String: AnyCodable] = [
            "lat": AnyCodable(location.coordinate.latitude),
            "lon": AnyCodable(location.coordinate.longitude),
            "accuracy": AnyCodable(location.horizontalAccuracy),
            "timestamp": AnyCodable(ISO8601DateFormatter().string(from: location.timestamp)),
        ]
        MainActor.assumeIsolated {
            continuation?.resume(returning: result)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
