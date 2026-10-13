import MapKit

@MainActor
enum MemoLocationGeocoder {
    static func name(for coordinate: CLLocationCoordinate2D) async throws -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if #available(iOS 26.0, macCatalyst 26.0, visionOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
            request.preferredLocale = .current
            let cancellation = Cancellation { request.cancel() }
            return try await withTaskCancellationHandler { @MainActor in
                let items = try await request.mapItems
                try Task.checkCancellation()
                return nonempty(items.first?.name)
            } onCancel: {
                Task { @MainActor in cancellation.cancel() }
            }
        } else {
            let geocoder = CLGeocoder()
            let cancellation = Cancellation { geocoder.cancelGeocode() }
            return try await withTaskCancellationHandler { @MainActor in
                let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: .current)
                try Task.checkCancellation()
                guard let place = placemarks.first else { return nil }
                return nonempty(place.name) ?? nonempty(place.locality) ?? nonempty(place.administrativeArea)
            } onCancel: {
                Task { @MainActor in cancellation.cancel() }
            }
        }
    }

    private static func nonempty(_ name: String?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        return name
    }

    // Keep the non-Sendable framework objects on the main actor during cancellation.
    @MainActor
    private final class Cancellation {
        let cancel: () -> Void

        init(cancel: @escaping () -> Void) {
            self.cancel = cancel
        }
    }
}
