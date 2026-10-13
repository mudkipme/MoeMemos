import CoreLocation
import Foundation
import Observation

/// Manages permission and a single MapKit fix after the current-location button is tapped.
@MainActor
@Observable
final class CurrentLocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    var isRequesting = false
    var errorKey: String?
    private(set) var showsUserLocation = false
    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var requestedAt: Date?

    init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        super.init()
        manager.delegate = self
    }

    func request() {
        guard !isRequesting else { return }
        errorKey = nil
        coordinate = nil
        requestedAt = .now
        isRequesting = true
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, self.isRequesting else { return }
            self.finish(error: "location.unavailable")
        }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: showsUserLocation = true
        case .denied, .restricted: finish(error: "location.permission-denied")
        @unknown default: finish(error: "location.unavailable")
        }
    }

    func cancel() {
        timeout?.cancel()
        timeout = nil
        showsUserLocation = false
        requestedAt = nil
        isRequesting = false
    }

    private func finish(error: String? = nil) {
        cancel()
        errorKey = error
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isRequesting else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: showsUserLocation = true
        case .denied, .restricted: finish(error: "location.permission-denied")
        default: break
        }
    }

    func receiveMapLocation(_ location: CLLocation) {
        guard isRequesting, showsUserLocation, let requestedAt,
              location.horizontalAccuracy >= 0,
              CLLocationCoordinate2DIsValid(location.coordinate),
              location.timestamp >= requestedAt.addingTimeInterval(-10),
              location.timestamp <= Date.now.addingTimeInterval(5) else { return }
        // Preserve MapKit's coordinate so the saved pin matches the displayed Apple map.
        coordinate = location.coordinate
        finish()
    }

    func mapLocationFailed() {
        guard isRequesting else { return }
        finish(error: "location.unavailable")
    }
}
