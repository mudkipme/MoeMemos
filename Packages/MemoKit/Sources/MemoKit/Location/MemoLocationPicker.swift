import MapKit
import Models
import SwiftUI

@MainActor
public struct MemoLocationPicker: View {
    private let onSelect: (MemoLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    @State private var name: String
    @State private var latitude: String
    @State private var longitude: String
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searchError = false
    @State private var isSearching = false
    @State private var currentLocation = CurrentLocationProvider()
    @FocusState private var coordinateFieldFocused: Bool

    public init(location: MemoLocation?, onSelect: @escaping (MemoLocation) -> Void) {
        self.onSelect = onSelect
        _name = State(initialValue: location?.placeholder ?? "")
        _latitude = State(initialValue: location.map { String($0.latitude) } ?? "")
        _longitude = State(initialValue: location.map { String($0.longitude) } ?? "")
        _position = State(initialValue: location.map { .region($0.region) } ?? .automatic)
    }

    private func number(_ text: String) -> Double? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(text.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: "."))
    }

    private var selectedLocation: MemoLocation? {
        guard let lat = number(latitude), let lon = number(longitude) else { return nil }
        let location = MemoLocation(placeholder: name, latitude: lat, longitude: lon)
        return location.isValid ? location : nil
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $position) {
                        if let location = selectedLocation {
                            Marker(location.displayName, coordinate: location.coordinate)
                        }
                    }
                    .mapControls { MapCompass() }
                    .onTapGesture { point in
                        guard let coordinate = proxy.convert(point, from: .local) else { return }
                        select(coordinate, name: "")
                    }
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
                            coordinateFieldFocused = false
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
                        TextField("location.name", text: $name)
                    } footer: {
                        Text("location.map-hint")
                    }
                    Section {
                        TextField("location.latitude", text: $latitude)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($coordinateFieldFocused)
                        TextField("location.longitude", text: $longitude)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($coordinateFieldFocused)
                    } footer: {
                        Text("location.coordinate-hint")
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
                    .disabled(selectedLocation == nil)
                }
            }
            .task(id: query) { await search() }
            .onChange(of: [selectedLocation?.latitude, selectedLocation?.longitude]) { _, _ in
                guard let location = selectedLocation else { return }
                position = .region(location.region)
            }
            .onChange(of: currentLocation.coordinate?.latitude) { _, _ in
                guard let coordinate = currentLocation.coordinate else { return }
                select(coordinate, name: "")
            }
            .onDisappear { currentLocation.cancel() }
        }
    }

    private func select(_ coordinate: CLLocationCoordinate2D, name: String) {
        currentLocation.cancel()
        coordinateFieldFocused = false
        self.name = name
        latitude = String(coordinate.latitude)
        longitude = String(coordinate.longitude)
        position = .region(MemoLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).region)
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
