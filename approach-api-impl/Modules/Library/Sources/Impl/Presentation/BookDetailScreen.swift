import CoreKit
import DesignSystem
import LibraryAPI
import SwiftUI

struct BookDetailScreen: View {
    let bookID: String
    let service: any LibraryService
    let ui: LibraryUI
    @State private var availability: LoadState<BookAvailability> = .idle
    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        AsyncContentView(state: availability, retry: load) { availability in
            let book = availability.book
            List {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Label(book.format.title, systemImage: book.format.systemImage)
                            .font(.subheadline)
                            .foregroundStyle(Palette.accent)
                        Text(book.title).font(.title2.weight(.bold))
                        Text("\(book.author), \(String(book.year))").foregroundStyle(.secondary)
                        Text(book.synopsis).padding(.top, Spacing.small)
                    }
                    .padding(.vertical, Spacing.small)
                }
                Section {
                    KeyValueRow("Available", value: "\(availability.available) of \(book.copies)")
                    if availability.holdQueue > 0 {
                        KeyValueRow("Waiting", value: "\(availability.holdQueue)")
                    }
                    KeyValueRow("Subjects", value: book.subjects.joined(separator: ", "))
                    KeyValueRow("ISBN", value: book.isbn)
                    NavigationLink {
                        ui.places.place(book.branchPlaceID)
                    } label: {
                        KeyValueRow("Branch", value: book.branchName)
                    }
                }
                if let message {
                    Section {
                        Text(message)
                    }
                }
                Section {
                    if availability.isAvailable {
                        Button(book.format == .print ? "Borrow" : "Borrow \(book.format.title)") {
                            Task { await act { _ = try await service.borrow(bookID: book.id); return "Borrowed. Due in \(book.format.loanDays) days, added to your agenda." } }
                        }
                        .buttonStyle(.primary)
                    } else {
                        Button("Place hold") {
                            Task { await act { let hold = try await service.placeHold(bookID: book.id); return hold.isReady ? "Ready to pick up." : "You are number \(hold.position) in line." } }
                        }
                        .buttonStyle(.primary)
                    }
                }
                .disabled(isWorking)
                .listRowInsets(EdgeInsets())
            }
            .toolbar {
                ui.favorites.toggleButton(book.favoriteDraft)
            }
        }
        .navigationTitle("Title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if case .idle = availability { await load() }
        }
    }

    private func load() async {
        do {
            availability = .loaded(try await service.availability(bookID: bookID))
        } catch {
            availability = .failed(LibraryMessages.message(for: error))
        }
    }

    private func act(_ action: () async throws -> String) async {
        isWorking = true
        defer { isWorking = false }
        do {
            message = try await action()
        } catch {
            message = LibraryMessages.message(for: error)
        }
        await load()
    }
}

#Preview {
    NavigationStack {
        BookDetailScreen(bookID: "book-overstory", service: PreviewLibraryService(), ui: .preview)
    }
}
