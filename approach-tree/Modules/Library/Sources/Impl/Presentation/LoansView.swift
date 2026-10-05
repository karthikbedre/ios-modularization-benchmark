import CoreKit
import DesignSystem
import SwiftUI

struct LoansView: View {
    let service: any LibraryService
    @State private var loans: LoadState<[Loan]> = .idle
    @State private var errorMessage: String?

    var body: some View {
        AsyncContentView(state: loans, retry: load) { loans in
            if loans.isEmpty {
                EmptyStateView("Nothing borrowed", systemImage: "books.vertical", message: "Books you borrow show up here with their due dates.")
            } else {
                List {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Palette.negative)
                    }
                    ForEach(loans) { loan in
                        LoanRow(loan: loan)
                            .swipeActions(edge: .trailing) {
                                Button("Return") { Task { await perform { try await service.giveBack(loanID: loan.id) } } }
                                    .tint(Palette.accent)
                            }
                            .swipeActions(edge: .leading) {
                                Button("Renew") { Task { await perform { _ = try await service.renew(loanID: loan.id) } } }
                                    .tint(Palette.positive)
                            }
                    }
                }
                .refreshable { await load() }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            loans = .loaded(try await service.loans())
        } catch {
            loans = .failed("Your loans could not be loaded.")
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        do {
            try await action()
            errorMessage = nil
        } catch {
            errorMessage = LibraryMessages.message(for: error)
        }
        await load()
    }
}

private struct LoanRow: View {
    let loan: Loan

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(loan.title)
            Text(loan.author).font(.caption).foregroundStyle(.secondary)
            HStack {
                if loan.isOverdue(at: .now) {
                    StatusBadge("Overdue", color: Palette.negative)
                } else {
                    Text("Due \(loan.dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(loan.dueDate.timeIntervalSinceNow < 3 * 86_400 ? Palette.warning : .secondary)
                }
                if loan.renewals > 0 {
                    Text("Renewed \(loan.renewals)×").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct HoldsView: View {
    let service: any LibraryService
    @State private var holds: LoadState<[HoldStatus]> = .idle

    var body: some View {
        AsyncContentView(state: holds, retry: load) { holds in
            if holds.isEmpty {
                EmptyStateView("No holds", systemImage: "hourglass", message: "Place a hold on a title that is out and we will keep your place in line.")
            } else {
                List(holds) { status in
                    HStack {
                        Text(status.hold.title)
                        Spacer()
                        if status.isReady {
                            StatusBadge("Ready", color: Palette.positive)
                        } else {
                            Text("#\(status.position) in line").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("Cancel", role: .destructive) {
                            Task {
                                try? await service.cancelHold(id: status.hold.id)
                                await load()
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            holds = .loaded(try await service.holds())
        } catch {
            holds = .failed("Your holds could not be loaded.")
        }
    }
}
