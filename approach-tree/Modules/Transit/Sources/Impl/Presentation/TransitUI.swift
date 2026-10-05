import Favorites
import Places
import SwiftUI

struct TransitUI {
    var places: PlacesEntryPoints
    var favorites: FavoritesEntryPoints

    @MainActor
    static var preview: TransitUI {
        TransitUI(
            places: PlacesEntryPoints(place: { _ in AnyView(EmptyView()) }, location: { _, _ in AnyView(Text("Map")) }),
            favorites: FavoritesEntryPoints(toggleButton: { _ in AnyView(Image(systemName: "heart")) }, list: { AnyView(EmptyView()) })
        )
    }
}

extension TransitStop {
    func favoriteDraft(lines: [TransitLine]) -> FavoriteDraft {
        let names = lines.filter { $0.stopIDs.contains(id) }.map(\.name)
        return FavoriteDraft(kind: .transitStop, itemID: id, title: name, subtitle: names.joined(separator: ", "))
    }
}

extension TransitLine {
    var color: Color {
        let hex = colorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return .gray }
        return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

extension TransitMode {
    var systemImage: String {
        switch self {
        case .metro: "tram.fill.tunnel"
        case .tram: "tram.fill"
        case .bus: "bus.fill"
        case .ferry: "ferry.fill"
        }
    }
}

struct LineBadge: View {
    let line: TransitLine

    var body: some View {
        Label(line.name, systemImage: line.mode.systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(line.color, in: Capsule())
            .foregroundStyle(.white)
    }
}

enum TransitMessages {
    static func message(for error: any Error) -> String {
        switch error as? TransitError {
        case .stopNotFound: "That stop could not be found."
        case .sameStop: "Pick two different stops."
        case .noRoute: "No route with at most one transfer right now."
        case .passStillValid(let until): "You already have this pass until \(until.formatted(date: .abbreviated, time: .shortened))."
        case nil: "The payment did not go through. Check your wallet and try again."
        }
    }
}
