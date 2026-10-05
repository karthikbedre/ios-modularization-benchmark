import CoreKit
import CoreModels
import DesignSystem
import MapKit
import PlacesAPI
import SwiftUI

struct PlaceDetailScreen: View {
    let place: Place
    let service: any PlacesService
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                LocationMap(title: place.name, point: place.location, tint: place.category.tint)
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                Label(place.category.title, systemImage: place.category.systemImage)
                    .foregroundStyle(place.category.tint)
                KeyValueRow("Address", value: place.address.singleLine)
                KeyValueRow("Distance", value: service.distance(from: GeoMath.cityCenter, to: place.location).walkingDescription)
                if let hours = place.openingHours {
                    KeyValueRow("Hours", value: hours)
                }
                if let phone = place.phone {
                    KeyValueRow("Phone", value: phone)
                }
            }
            Section {
                Button("Directions", systemImage: "arrow.triangle.turn.up.right.diamond") {
                    if let url = DirectionsLink.url(to: place.location) {
                        openURL(url)
                    }
                }
            }
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Resolves a place by ID for other domains, which only know venue or branch IDs.
struct PlaceLookupScreen: View {
    let placeID: String
    let service: any PlacesService
    @State private var place: LoadState<Place> = .idle

    var body: some View {
        AsyncContentView(state: place, retry: load) { place in
            PlaceDetailScreen(place: place, service: service)
        }
        .task {
            if case .idle = place { await load() }
        }
    }

    private func load() async {
        do {
            place = .loaded(try await service.place(id: placeID))
        } catch {
            place = .failed("This place could not be found.")
        }
    }
}

struct LocationScreen: View {
    let title: String
    let point: GeoPoint

    var body: some View {
        LocationMap(title: title, point: point, tint: Palette.accent)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LocationMap: View {
    let title: String
    let point: GeoPoint
    let tint: Color

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: point.coordinate, latitudinalMeters: 600, longitudinalMeters: 600))) {
            Marker(title, coordinate: point.coordinate)
                .tint(tint)
        }
        .allowsHitTesting(false)
    }
}

enum DirectionsLink {
    static func url(to point: GeoPoint) -> URL? {
        var components = URLComponents(string: "maps://")
        components?.queryItems = [URLQueryItem(name: "daddr", value: "\(point.latitude),\(point.longitude)")]
        return components?.url
    }
}

#Preview {
    NavigationStack {
        PlaceDetailScreen(place: .previewAmphitheater, service: PreviewPlacesService())
    }
}
