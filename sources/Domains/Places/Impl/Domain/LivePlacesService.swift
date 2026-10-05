import CoreModels
import Foundation
import PlacesAPI

public struct LivePlacesService: PlacesService {
    private let repository: any PlacesRepository

    init(repository: any PlacesRepository) {
        self.repository = repository
    }

    public func places(in category: PlaceCategory?) async throws -> [Place] {
        try await repository.places()
            .filter { category == nil || $0.category == category }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func place(id: String) async throws -> Place {
        guard let place = try await repository.places().first(where: { $0.id == id }) else {
            throw PlacesError.notFound
        }
        return place
    }

    public func nearby(_ point: GeoPoint, radius: Measurement<UnitLength>, category: PlaceCategory?) async throws -> [NearbyPlace] {
        try await places(in: category)
            .map { NearbyPlace(place: $0, distance: distance(from: point, to: $0.location)) }
            .filter { $0.distance <= radius }
            .sorted { $0.distance < $1.distance }
    }

    public func distance(from: GeoPoint, to: GeoPoint) -> Measurement<UnitLength> {
        GeoMath.distance(from: from, to: to)
    }

    public func summary() async -> DomainSummary {
        guard let nearby = try? await nearby(GeoMath.cityCenter, radius: Measurement(value: 1, unit: .kilometers), category: nil) else {
            return DomainSummary(title: "Places", detail: "Unavailable")
        }
        return DomainSummary(title: "Places", detail: "\(nearby.count) places within 1 km")
    }
}
