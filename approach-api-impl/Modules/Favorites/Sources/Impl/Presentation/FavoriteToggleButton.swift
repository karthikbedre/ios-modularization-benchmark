import DesignSystem
import FavoritesAPI
import SwiftUI

struct FavoriteToggleButton: View {
    let draft: FavoriteDraft
    let service: any FavoritesService
    @State private var isFavorite = false
    @State private var isWorking = false

    var body: some View {
        Button {
            Task { await toggle() }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? Palette.negative : .primary)
                .contentTransition(.symbolEffect(.replace))
        }
        .disabled(isWorking)
        .accessibilityLabel(isFavorite ? "Remove from saved" : "Save")
        .task(id: draft.itemID) {
            isFavorite = (try? await service.isFavorite(kind: draft.kind, itemID: draft.itemID)) ?? false
        }
    }

    private func toggle() async {
        isWorking = true
        defer { isWorking = false }
        if let newValue = try? await service.toggle(draft) {
            isFavorite = newValue
        }
    }
}

#Preview {
    FavoriteToggleButton(draft: FavoriteDraft(kind: .event, itemID: "e1", title: "Jazz", subtitle: "Harbor"), service: PreviewFavoritesService())
}
