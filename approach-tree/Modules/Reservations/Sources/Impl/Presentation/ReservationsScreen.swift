import CoreKit
import DesignSystem
import SwiftUI

struct ReservationsScreen: View {
    let service: any ReservationsService
    @State private var state: LoadState<(upcoming: [Reservation], history: [Reservation])> = .idle

    var body: some View {
        AsyncContentView(state: state, retry: load) { lists in
            if lists.upcoming.isEmpty && lists.history.isEmpty {
                EmptyStateView("No reservations", systemImage: "calendar.badge.clock", message: "Book a table or a city facility to see it here.")
            } else {
                List {
                    Section("Upcoming") {
                        if lists.upcoming.isEmpty {
                            Text("Nothing booked").foregroundStyle(.secondary)
                        }
                        ForEach(lists.upcoming) { reservation in
                            NavigationLink(value: reservation) { ReservationRow(reservation: reservation) }
                        }
                    }
                    if !lists.history.isEmpty {
                        Section("Past and cancelled") {
                            ForEach(lists.history) { reservation in
                                NavigationLink(value: reservation) { ReservationRow(reservation: reservation) }
                            }
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Reservations")
        .navigationDestination(for: Reservation.self) { reservation in
            ReservationDetailScreen(reservation: reservation, service: service) {
                Task { await load() }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            async let upcoming = service.upcoming()
            async let history = service.history()
            state = .loaded((try await upcoming, try await history))
        } catch {
            state = .failed("Your reservations could not be loaded.")
        }
    }
}

struct ReservationRow: View {
    let reservation: Reservation

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: reservation.kind == .dining ? "fork.knife" : "sportscourt")
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(reservation.venueName)
                Text("\(reservation.start.formatted(date: .abbreviated, time: .shortened)) · \(reservation.partySize) people")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if reservation.status == .cancelled {
                StatusBadge("Cancelled", color: Palette.negative)
            }
        }
    }
}

struct ReservationDetailScreen: View {
    let reservation: Reservation
    let service: any ReservationsService
    let onChange: () -> Void
    @State private var errorMessage: String?
    @State private var confirmsCancel = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                KeyValueRow("Venue", value: reservation.venueName)
                KeyValueRow("When", value: reservation.start.formatted(date: .complete, time: .shortened))
                KeyValueRow("Until", value: reservation.end.formatted(date: .omitted, time: .shortened))
                KeyValueRow("Party", value: "\(reservation.partySize)")
                KeyValueRow("Code", value: reservation.confirmationCode)
                if !reservation.notes.isEmpty {
                    KeyValueRow("Notes", value: reservation.notes)
                }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(Palette.negative)
                }
            }
            if reservation.status == .confirmed && reservation.start > .now {
                Section {
                    Button("Cancel reservation", role: .destructive) { confirmsCancel = true }
                }
            }
        }
        .navigationTitle("Reservation")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Cancel this reservation?", isPresented: $confirmsCancel, titleVisibility: .visible) {
            Button("Cancel reservation", role: .destructive) {
                Task { await cancel() }
            }
        }
    }

    private func cancel() async {
        do {
            try await service.cancel(id: reservation.id)
            onChange()
            dismiss()
        } catch let error as ReservationsError {
            errorMessage = error.message
        } catch {
            errorMessage = "The reservation could not be cancelled."
        }
    }
}

#Preview {
    NavigationStack {
        ReservationsScreen(service: PreviewReservationsService())
    }
}
