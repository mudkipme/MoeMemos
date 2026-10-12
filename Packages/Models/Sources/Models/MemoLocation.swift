import Foundation

/// Memos' location payload. Coordinates use WGS 84 decimal degrees.
public struct MemoLocation: Codable, Equatable, Hashable, Sendable {
    public var placeholder: String
    public var latitude: Double
    public var longitude: Double

    public init(placeholder: String = "", latitude: Double, longitude: Double) {
        self.placeholder = placeholder
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    public var coordinatesText: String {
        String(format: "%.4f°, %.4f°", latitude, longitude)
    }

    public var displayName: String {
        let name = placeholder.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? coordinatesText : name
    }
}

/// `nil` updates leave location unchanged; `.remove` explicitly clears it.
public enum MemoLocationUpdate: Equatable, Sendable {
    case set(MemoLocation)
    case remove

    public var location: MemoLocation? {
        if case .set(let location) = self { return location }
        return nil
    }
}
