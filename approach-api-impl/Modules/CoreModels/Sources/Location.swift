public struct GeoPoint: Hashable, Sendable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct Address: Hashable, Sendable, Codable {
    public var street: String
    public var district: String
    public var postalCode: String

    public init(street: String, district: String, postalCode: String) {
        self.street = street
        self.district = district
        self.postalCode = postalCode
    }

    public var singleLine: String {
        "\(street), \(district) \(postalCode)"
    }
}
