import Favorites
import Places
import Reservations
import SwiftUI

/// Cross-domain screens and controls the dining screens compose.
struct DiningUI {
    var places: PlacesEntryPoints
    var favorites: FavoritesEntryPoints
    var reservations: ReservationsEntryPoints

    @MainActor
    static var preview: DiningUI {
        DiningUI(
            places: PlacesEntryPoints(place: { _ in AnyView(Text("Map")) }, location: { _, _ in AnyView(Text("Map")) }),
            favorites: FavoritesEntryPoints(toggleButton: { _ in AnyView(Image(systemName: "heart")) }, list: { AnyView(Text("Saved")) }),
            reservations: ReservationsEntryPoints(booking: { _ in AnyView(Text("Booking")) }, myReservations: { AnyView(Text("Reservations")) })
        )
    }
}

extension Restaurant {
    var favoriteDraft: FavoriteDraft {
        FavoriteDraft(kind: .restaurant, itemID: id, title: name, subtitle: "\(cuisine.title) · \(district)")
    }

    var bookableVenue: BookableVenue {
        BookableVenue(id: id, name: name, kind: .dining)
    }
}

struct RatingView: View {
    let rating: Double
    let reviewCount: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            Text(rating, format: .number.precision(.fractionLength(1)))
            Text("(\(reviewCount))")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rated \(rating.formatted(.number.precision(.fractionLength(1)))) from \(reviewCount) reviews")
    }
}
