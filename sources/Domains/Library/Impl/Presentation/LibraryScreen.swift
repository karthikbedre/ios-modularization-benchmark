import CoreKit
import DesignSystem
import LibraryAPI
import SwiftUI

struct LibraryScreen: View {
    enum Tab: String, CaseIterable {
        case catalog = "Catalog"
        case loans = "My loans"
        case holds = "Holds"
    }

    let service: any LibraryService
    let ui: LibraryUI
    @State private var tab = Tab.catalog
    @State private var query = ""
    @State private var format: BookFormat?
    @State private var results: LoadState<[BookAvailability]> = .idle

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.small)
            switch tab {
            case .catalog: catalog
            case .loans: LoansView(service: service)
            case .holds: HoldsView(service: service)
            }
        }
        .navigationTitle("Library")
        .navigationDestination(for: Book.self) { book in
            BookDetailScreen(bookID: book.id, service: service, ui: ui)
        }
    }

    private var catalog: some View {
        AsyncContentView(state: results, retry: search) { results in
            List {
                Section {
                    Picker("Format", selection: $format) {
                        Text("All formats").tag(BookFormat?.none)
                        ForEach(BookFormat.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                    }
                }
                if results.isEmpty {
                    Text("No titles match.").foregroundStyle(.secondary)
                }
                ForEach(results, id: \.book.id) { result in
                    NavigationLink(value: result.book) { BookRow(availability: result) }
                }
            }
        }
        .searchable(text: $query, prompt: "Title, author, subject or ISBN")
        .task(id: "\(query)|\(format?.rawValue ?? "")") { await search() }
    }

    private func search() async {
        do {
            results = .loaded(try await service.search(query, format: format))
        } catch {
            results = .failed("The catalog could not be searched.")
        }
    }
}

struct BookRow: View {
    let availability: BookAvailability

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: availability.book.format.systemImage)
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(availability.book.title)
                Text("\(availability.book.author) · \(availability.book.format.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if availability.isAvailable {
                StatusBadge("Available", color: Palette.positive)
            } else {
                StatusBadge(availability.holdQueue == 0 ? "Out" : "\(availability.holdQueue) waiting", color: Palette.warning)
            }
        }
    }
}

#Preview {
    NavigationStack {
        LibraryScreen(service: PreviewLibraryService(), ui: .preview)
    }
}
