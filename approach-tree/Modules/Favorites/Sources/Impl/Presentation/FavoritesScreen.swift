import DesignSystem
import SwiftUI

struct FavoritesScreen: View {
    @State private var viewModel: FavoritesViewModel

    init(service: any FavoritesService) {
        _viewModel = State(initialValue: FavoritesViewModel(service: service))
    }

    var body: some View {
        AsyncContentView(state: viewModel.state, retry: viewModel.load) { items in
            if items.isEmpty {
                EmptyStateView("Nothing saved", systemImage: "heart", message: "Tap the heart on events, restaurants, stops and books to keep them here.")
            } else {
                List {
                    ForEach(viewModel.groups, id: \.kind) { group in
                        Section(group.kind.title) {
                            ForEach(group.items) { item in
                                FavoriteRow(item: item)
                                    .swipeActions {
                                        Button("Remove", role: .destructive) {
                                            Task { await viewModel.remove(item) }
                                        }
                                    }
                            }
                        }
                    }
                }
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Saved")
        .toolbar {
            Picker("Kind", selection: $viewModel.kind) {
                Text("All").tag(FavoriteKind?.none)
                ForEach(FavoriteKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(Optional(kind))
                }
            }
            .pickerStyle(.menu)
        }
        .task(id: viewModel.kind) {
            await viewModel.load()
        }
    }
}

private struct FavoriteRow: View {
    let item: FavoriteItem

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: item.kind.systemImage)
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesScreen(service: PreviewFavoritesService())
    }
}
