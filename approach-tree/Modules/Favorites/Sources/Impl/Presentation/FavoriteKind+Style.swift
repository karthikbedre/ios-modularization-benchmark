
extension FavoriteKind {
    var systemImage: String {
        switch self {
        case .event: "calendar"
        case .restaurant: "fork.knife"
        case .transitStop: "tram.fill"
        case .book: "book.fill"
        }
    }
}
