import CoreKit
import CoreModels
import Foundation
import Observation
import PlacesAPI

@MainActor
@Observable
final class PlacesExplorerViewModel {
    private(set) var state: LoadState<[NearbyPlace]> = .idle
    var category: PlaceCategory?
    var selectedPlaceID: String?

    let service: any PlacesService
    private let origin: GeoPoint

    init(service: any PlacesService, origin: GeoPoint = GeoMath.cityCenter) {
        self.service = service
        self.origin = origin
    }

    var selectedPlace: NearbyPlace? {
        state.value?.first { $0.id == selectedPlaceID }
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            let places = try await service.nearby(origin, radius: Measurement(value: 5, unit: .kilometers), category: category)
            state = .loaded(places)
            if let selectedPlaceID, !places.contains(where: { $0.id == selectedPlaceID }) {
                self.selectedPlaceID = nil
            }
        } catch {
            state = .failed("Places could not be loaded.")
        }
    }
}
