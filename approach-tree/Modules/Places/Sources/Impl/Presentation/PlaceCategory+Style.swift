import CoreLocation
import CoreModels
import SwiftUI

extension PlaceCategory {
    var systemImage: String {
        switch self {
        case .park: "tree.fill"
        case .library: "books.vertical.fill"
        case .venue: "music.mic"
        case .garage: "parkingsign"
        case .station: "tram.fill"
        case .restaurant: "fork.knife"
        case .civicOffice: "building.columns.fill"
        case .clinic: "cross.case.fill"
        }
    }

    var tint: Color {
        switch self {
        case .park: .green
        case .library: .brown
        case .venue: .purple
        case .garage: .blue
        case .station: .orange
        case .restaurant: .red
        case .civicOffice: .teal
        case .clinic: .pink
        }
    }
}

extension GeoPoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension Measurement where UnitType == UnitLength {
    var walkingDescription: String {
        let meters = converted(to: .meters).value
        return meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1000)
    }
}
