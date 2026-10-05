#if DEBUG
import CoreModels
import Foundation

extension Place {
    public static let previewAmphitheater = Place(
        id: "place-amphitheater",
        name: "Harbor Amphitheater",
        category: .venue,
        location: GeoPoint(latitude: 40.7032, longitude: -74.0170),
        address: Address(street: "1 Pier Road", district: "Harborfront", postalCode: "10004"),
        openingHours: "Event days 5 PM to 11 PM"
    )
}

public struct PreviewPlacesService: PlacesService {
    public init() {}

    public func places(in category: PlaceCategory?) async throws -> [Place] { [.previewAmphitheater] }
    public func place(id: String) async throws -> Place { .previewAmphitheater }

    public func nearby(_ point: GeoPoint, radius: Measurement<UnitLength>, category: PlaceCategory?) async throws -> [NearbyPlace] {
        [NearbyPlace(place: .previewAmphitheater, distance: Measurement(value: 350, unit: .meters))]
    }

    public func distance(from: GeoPoint, to: GeoPoint) -> Measurement<UnitLength> {
        Measurement(value: 350, unit: .meters)
    }

    public func summary() async -> DomainSummary {
        DomainSummary(title: "Places", detail: "1 place nearby")
    }
}
#endif
