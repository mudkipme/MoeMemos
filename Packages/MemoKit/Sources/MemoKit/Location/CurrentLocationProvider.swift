import CoreLocation
import Foundation
import Observation

/// Requests a single fix only in response to the current-location button.
@MainActor
@Observable
final class CurrentLocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    var isRequesting = false
    var errorKey: String?
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var timeout: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        guard !isRequesting else { return }
        errorKey = nil
        coordinate = nil
        isRequesting = true
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, self.isRequesting else { return }
            self.finish(error: "location.unavailable")
        }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish(error: "location.permission-denied")
        @unknown default: finish(error: "location.unavailable")
        }
    }

    func cancel() {
        timeout?.cancel()
        timeout = nil
        manager.stopUpdatingLocation()
        isRequesting = false
    }

    private func finish(error: String? = nil) {
        cancel()
        errorKey = error
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isRequesting else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish(error: "location.permission-denied")
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRequesting, let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        coordinate = location.coordinate
        finish()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isRequesting else { return }
        finish(error: "location.unavailable")
    }
}
