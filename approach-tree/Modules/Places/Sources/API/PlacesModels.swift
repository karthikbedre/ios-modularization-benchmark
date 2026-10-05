import CoreModels
import Foundation

public enum PlaceCategory: String, CaseIterable, Hashable, Sendable, Codable {
    case park, library, venue, garage, station, restaurant, civicOffice, clinic

    public var title: String {
        switch self {
        case .park: "Parks"
        case .library: "Libraries"
        case .venue: "Venues"
        case .garage: "Parking"
        case .station: "Transit"
        case .restaurant: "Restaurants"
        case .civicOffice: "City offices"
        case .clinic: "Clinics"
        }
    }
}

public struct Place: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var category: PlaceCategory
    public var location: GeoPoint
    public var address: Address
    public var openingHours: String?
    public var phone: String?

    public init(id: String, name: String, category: PlaceCategory, location: GeoPoint, address: Address, openingHours: String? = nil, phone: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.location = location
        self.address = address
        self.openingHours = openingHours
        self.phone = phone
    }
}

public struct NearbyPlace: Identifiable, Hashable, Sendable {
    public var place: Place
    public var distance: Measurement<UnitLength>

    public init(place: Place, distance: Measurement<UnitLength>) {
        self.place = place
        self.distance = distance
    }

    public var id: String { place.id }
}

public enum PlacesError: Error, Hashable, Sendable {
    case notFound
}
