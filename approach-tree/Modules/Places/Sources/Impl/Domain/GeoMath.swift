import CoreModels
import Foundation

enum GeoMath {
    private static let earthRadiusMeters = 6_371_000.0

    /// Great-circle distance using the haversine formula.
    static func distance(from a: GeoPoint, to b: GeoPoint) -> Measurement<UnitLength> {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let deltaLat = (b.latitude - a.latitude) * .pi / 180
        let deltaLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let meters = 2 * earthRadiusMeters * atan2(sqrt(h), sqrt(1 - h))
        return Measurement(value: meters, unit: .meters)
    }

    /// The point a resident is assumed to be at. There is no real location service in the prototype.
    static let cityCenter = GeoPoint(latitude: 40.7149, longitude: -74.0055)
}
