import CoreModels
import Foundation
import SwiftUI

public protocol PlacesService: SummaryProviding {
    func places(in category: PlaceCategory?) async throws -> [Place]
    func place(id: String) async throws -> Place
    /// Places within `radius` of `point`, closest first.
    func nearby(_ point: GeoPoint, radius: Measurement<UnitLength>, category: PlaceCategory?) async throws -> [NearbyPlace]
    func distance(from: GeoPoint, to: GeoPoint) -> Measurement<UnitLength>
}

/// Screens other domains can present without importing the Places implementation.
public struct PlacesEntryPoints: Sendable {
    /// Detail for a known place, such as an event venue or a library branch.
    public var place: @MainActor @Sendable (_ id: String) -> AnyView
    /// A pin for an arbitrary location, such as a reported pothole.
    public var location: @MainActor @Sendable (_ title: String, _ point: GeoPoint) -> AnyView

    public init(
        place: @escaping @MainActor @Sendable (_ id: String) -> AnyView,
        location: @escaping @MainActor @Sendable (_ title: String, _ point: GeoPoint) -> AnyView
    ) {
        self.place = place
        self.location = location
    }
}
