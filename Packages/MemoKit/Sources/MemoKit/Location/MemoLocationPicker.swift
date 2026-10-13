import MapKit
import Models
import SwiftUI

@MainActor
public struct MemoLocationPicker: View {
    private let onSelect: (MemoLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var selectionID = UUID()
    @State private var isResolvingName = false
    @State private var nameLookupFailed = false
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searchError = false
    @State private var isSearching = false
    @State private var currentLocation = CurrentLocationProvider()

    public init(location: MemoLocation?, onSelect: @escaping (MemoLocation) -> Void) {
        self.onSelect = onSelect
        _name = State(initialValue: location?.placeholder ?? "")
        _coordinate = State(initialValue: location?.coordinate)
    }

    private var selectedLocation: MemoLocation? {
        guard let coordinate else { return nil }
        let location = MemoLocation(placeholder: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.isValid ? location : nil
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MemoLocationPickerMap(
                    location: selectedLocation,
                    selectionID: selectionID,
                    showsUserLocation: currentLocation.showsUserLocation,
                    currentLocation: currentLocation
                ) { coordinate in
                    select(coordinate, name: "")
                }
                .frame(minHeight: 180, idealHeight: 260, maxHeight: 300)
                .accessibilityHint(Text("location.map-hint"))

                Form {
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section("location.search-results") {
                            if isSearching {
                                ProgressView()
                            } else if results.isEmpty {
                                Text(LocalizedStringKey(searchError ? "location.search-failed" : "location.no-results"))
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(results.indices, id: \.self) { index in
                                let item = results[index]
                                Button {
                                    select(item.placemark.coordinate, name: item.name ?? "")
                                    query = ""
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(item.name ?? "").foregroundStyle(.primary)
                                        if let address = item.placemark.title {
                                            Text(address).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Section {
                        Button {
                            currentLocation.request()
                        } label: {
                            HStack {
                                Label("location.use-current", systemImage: "location.fill")
                                if currentLocation.isRequesting { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(currentLocation.isRequesting)
                        if let error = currentLocation.errorKey {
                            Text(LocalizedStringKey(error)).foregroundStyle(.secondary).font(.footnote)
                        }
                        HStack {
                            TextField("location.name", text: $name)
                            if isResolvingName { ProgressView() }
                        }
                        if nameLookupFailed {
                            Text("location.name-unavailable").foregroundStyle(.secondary).font(.footnote)
                        }
                    } footer: {
                        Text("location.map-hint")
                    }
                }
            }
            .navigationTitle(Text("location.title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("location.search"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        guard let location = selectedLocation else { return }
                        onSelect(location)
                        dismiss()
                    }
                    .disabled(selectedLocation == nil || isResolvingName || currentLocation.isRequesting)
                }
            }
            .task(id: query) { await search() }
            .task(id: selectionID) { await resolveName() }
            .onChange(of: [currentLocation.coordinate?.latitude, currentLocation.coordinate?.longitude]) { _, _ in
                guard let coordinate = currentLocation.coordinate else { return }
                select(coordinate, name: "")
            }
            .onDisappear { currentLocation.cancel() }
        }
    }

    private func select(_ coordinate: CLLocationCoordinate2D, name: String) {
        currentLocation.cancel()
        currentLocation.errorKey = nil
        self.name = name
        self.coordinate = coordinate
        selectionID = UUID()
        nameLookupFailed = false
        isResolvingName = false
    }

    private func resolveName() async {
        guard let coordinate, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let id = selectionID
        let originalName = name
        isResolvingName = true
        do {
            // Debounce map taps so moving a pin doesn't flood the geocoding service.
            try await Task.sleep(for: .milliseconds(300))
            let resolvedName = try await MemoLocationGeocoder.name(for: coordinate)
            guard !Task.isCancelled, selectionID == id else { return }
            isResolvingName = false
            // Keep a name typed by the user while the lookup was in flight.
            guard name == originalName else { return }
            if let resolvedName {
                name = resolvedName
            } else {
                nameLookupFailed = true
            }
        } catch {
            guard !Task.isCancelled, selectionID == id else { return }
            isResolvingName = false
            nameLookupFailed = name == originalName
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []
        searchError = false
        isSearching = !text.isEmpty
        guard !text.isEmpty else { return }
        do {
            try await Task.sleep(for: .milliseconds(300))
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            if let location = selectedLocation { request.region = location.region }
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            results = response.mapItems
            isSearching = false
        } catch {
            guard !Task.isCancelled else { return }
            isSearching = false
            searchError = true
        }
    }
}
