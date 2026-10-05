import FavoritesAPI
import LibraryAPI
import PlacesAPI
import SwiftUI

struct LibraryUI {
    var places: PlacesEntryPoints
    var favorites: FavoritesEntryPoints

    @MainActor
    static var preview: LibraryUI {
        LibraryUI(
            places: PlacesEntryPoints(place: { _ in AnyView(Text("Branch")) }, location: { _, _ in AnyView(EmptyView()) }),
            favorites: FavoritesEntryPoints(toggleButton: { _ in AnyView(Image(systemName: "heart")) }, list: { AnyView(EmptyView()) })
        )
    }
}

extension Book {
    var favoriteDraft: FavoriteDraft {
        FavoriteDraft(kind: .book, itemID: id, title: title, subtitle: author)
    }
}

extension BookFormat {
    var systemImage: String {
        switch self {
        case .print: "book.closed.fill"
        case .ebook: "ipad"
        case .audiobook: "headphones"
        }
    }
}

enum LibraryMessages {
    static func message(for error: any Error) -> String {
        switch error as? LibraryError {
        case .bookNotFound: "This title is no longer in the catalog."
        case .unavailable: "No copies are free. Place a hold instead."
        case .alreadyBorrowed: "You already have this one out."
        case .loanLimitReached(let max): "You can have up to \(max) items out at once."
        case .loanNotFound: "This loan could not be found."
        case .renewalLimitReached(let max): "Items can be renewed \(max) times."
        case .overdue: "Overdue items cannot be renewed. Return it to the library."
        case .othersWaiting: "Someone is waiting for this title, so it cannot be renewed."
        case .holdNotNeeded: "A copy is available. Borrow it now."
        case .alreadyOnHold: "You are already in line for this title."
        case .holdNotFound: "This hold could not be found."
        case nil: "Something went wrong. Try again."
        }
    }
}
