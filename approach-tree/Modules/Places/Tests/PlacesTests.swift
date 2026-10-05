import CoreKit
import CoreModels
import Foundation
@testable import Places
import Places
import Testing

private func place(_ id: String, _ category: PlaceCategory, latitude: Double, longitude: Double, name: String? = nil) -> Place {
    Place(id: id, name: name ?? id, category: category, location: GeoPoint(latitude: latitude, longitude: longitude),
          address: Address(street: "1 Test", district: "Test", postalCode: "00000"))
}

private let origin = GeoPoint(latitude: 40.7149, longitude: -74.0055)

private let places = [
    place("near-park", .park, latitude: 40.7158, longitude: -74.0055, name: "b park"),
    place("far-park", .park, latitude: 40.7600, longitude: -74.0055, name: "A park"),
    place("mid-library", .library, latitude: 40.7200, longitude: -74.0055),
]

struct GeoMathTests {
    @Test func distanceBetweenKnownPointsIsAccurate() {
        // One hundredth of a degree of latitude is about 1.11 km.
        let distance = GeoMath.distance(from: origin, to: GeoPoint(latitude: origin.latitude + 0.01, longitude: origin.longitude))

        #expect(abs(distance.converted(to: .meters).value - 1112) < 5)
    }

    @Test func distanceToSelfIsZero() {
        #expect(GeoMath.distance(from: origin, to: origin).value == 0)
    }

    @Test(arguments: [(250.0, "250 m"), (999.4, "999 m"), (1500.0, "1.5 km")])
    func walkingDescription(meters: Double, expected: String) {
        #expect(Measurement(value: meters, unit: UnitLength.meters).walkingDescription == expected)
    }
}

struct LivePlacesServiceTests {
    private let service = LivePlacesService(repository: InMemoryPlacesRepository(stored: places))

    @Test func filtersByCategoryAndSortsByName() async throws {
        #expect(try await service.places(in: .park).map(\.id) == ["far-park", "near-park"])
        #expect(try await service.places(in: nil).count == 3)
    }

    @Test func nearbyIsWithinRadiusClosestFirst() async throws {
        let nearby = try await service.nearby(origin, radius: Measurement(value: 1, unit: .kilometers), category: nil)

        #expect(nearby.map(\.id) == ["near-park", "mid-library"])
    }

    @Test func nearbyRespectsCategory() async throws {
        let nearby = try await service.nearby(origin, radius: Measurement(value: 10, unit: .kilometers), category: .library)

        #expect(nearby.map(\.id) == ["mid-library"])
    }

    @Test func unknownPlaceThrows() async {
        await #expect(throws: PlacesError.notFound) { try await service.place(id: "missing") }
    }

    @Test func bundledPlacesDecode() async throws {
        let bundled = try await BundlePlacesRepository(loader: MockDataLoader(latency: .none)).places()

        #expect(bundled.count == 16)
        #expect(Set(bundled.map(\.category)) == Set(PlaceCategory.allCases))
    }
}

@MainActor
struct PlacesExplorerViewModelTests {
    @Test func loadsNearbyAndClearsSelectionThatNoLongerMatches() async {
        let viewModel = PlacesExplorerViewModel(service: LivePlacesService(repository: InMemoryPlacesRepository(stored: places)), origin: origin)
        await viewModel.load()
        viewModel.selectedPlaceID = "near-park"
        #expect(viewModel.selectedPlace?.place.id == "near-park")

        viewModel.category = .library
        await viewModel.load()

        #expect(viewModel.state.value?.map(\.id) == ["mid-library"])
        #expect(viewModel.selectedPlaceID == nil)
    }

    @Test func directionsLinkCarriesCoordinates() {
        #expect(DirectionsLink.url(to: origin)?.absoluteString == "maps://?daddr=40.7149,-74.0055")
    }
}
