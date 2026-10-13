import MapKit
import Models
import SwiftUI

/// Uses MapKit's user-location source for the same coordinates as the displayed map.
@MainActor
struct MemoLocationPickerMap: UIViewRepresentable {
    let location: MemoLocation?
    let selectionID: UUID
    let showsUserLocation: Bool
    let currentLocation: CurrentLocationProvider
    let onSelect: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsCompass = true
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "selected-location")
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.selectPoint(_:)))
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if map.showsUserLocation != showsUserLocation {
            map.showsUserLocation = showsUserLocation
        }
        if let location {
            if let annotation = coordinator.annotation {
                if annotation.coordinate.latitude != location.latitude || annotation.coordinate.longitude != location.longitude {
                    annotation.coordinate = location.coordinate
                }
                annotation.title = location.localizedDisplayName
            } else {
                let annotation = MKPointAnnotation()
                annotation.coordinate = location.coordinate
                annotation.title = location.localizedDisplayName
                coordinator.annotation = annotation
                map.addAnnotation(annotation)
            }
            // Recenter on a selection, while preserving pans/zooms during name lookups.
            if coordinator.appliedSelectionID != selectionID {
                map.setRegion(location.region, animated: coordinator.appliedSelectionID != nil)
            }
        } else if let annotation = coordinator.annotation {
            map.removeAnnotation(annotation)
            coordinator.annotation = nil
        }
        coordinator.appliedSelectionID = selectionID
    }

    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
        map.showsUserLocation = false
        map.delegate = nil
        coordinator.parent.currentLocation.cancel()
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MKMapViewDelegate {
        var parent: MemoLocationPickerMap
        var annotation: MKPointAnnotation?
        var appliedSelectionID: UUID?

        init(_ parent: MemoLocationPickerMap) {
            self.parent = parent
        }

        @objc func selectPoint(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let map = recognizer.view as? MKMapView else { return }
            let coordinate = map.convert(recognizer.location(in: map), toCoordinateFrom: map)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return }
            parent.onSelect(coordinate)
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let location = userLocation.location else { return }
            parent.currentLocation.receiveMapLocation(location)
            if !parent.currentLocation.showsUserLocation {
                mapView.showsUserLocation = false
            }
        }

        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            parent.currentLocation.mapLocationFailed()
            mapView.showsUserLocation = false
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard annotation === self.annotation else { return nil }
            return mapView.dequeueReusableAnnotationView(withIdentifier: "selected-location", for: annotation)
        }
    }
}
