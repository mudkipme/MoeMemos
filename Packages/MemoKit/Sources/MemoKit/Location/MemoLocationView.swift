import MapKit
import Models
import SwiftUI

extension MemoLocation {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    }
}

/// A compact metadata row shared by local memos, explore, and comments.
public struct MemoLocationView: View {
    public let location: MemoLocation
    @State private var showingMap = false

    public init(location: MemoLocation) {
        self.location = location
    }

    public var body: some View {
        Button {
            showingMap = true
        } label: {
            Label(location.displayName, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.borderless)
        .sheet(isPresented: $showingMap) {
            MemoLocationDetail(location: location)
        }
    }
}

private struct MemoLocationDetail: View {
    let location: MemoLocation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Map(initialPosition: .region(location.region)) {
                    Marker(location.displayName, coordinate: location.coordinate)
                }
                .mapControls { MapCompass() }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(location.displayName).font(.headline)
                Text(location.coordinatesText).foregroundStyle(.secondary).textSelection(.enabled)
                Button("location.open-maps", systemImage: "map") {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                    item.name = location.displayName
                    item.openInMaps()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle(Text("location.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }
}
