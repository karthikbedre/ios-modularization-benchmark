import DesignSystem
import SwiftUI

struct BookingScreen: View {
    @State private var viewModel: BookingViewModel
    @Environment(\.dismiss) private var dismiss

    init(venue: BookableVenue, service: any ReservationsService) {
        _viewModel = State(initialValue: BookingViewModel(venue: venue, service: service))
    }

    var body: some View {
        Group {
            if let reservation = viewModel.confirmed {
                BookingConfirmation(reservation: reservation) { dismiss() }
            } else {
                form
            }
        }
        .navigationTitle(viewModel.venue.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(viewModel.selectedDay.timeIntervalSince1970)-\(viewModel.partySize)") {
            await viewModel.loadSlots()
        }
    }

    private var form: some View {
        Form {
            Section("Day") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.small * 2) {
                        ForEach(viewModel.days, id: \.self) { day in
                            DayChip(day: day, isSelected: day == viewModel.selectedDay) {
                                viewModel.selectedDay = day
                            }
                        }
                    }
                }
                Stepper("Party of \(viewModel.partySize)", value: $viewModel.partySize, in: 1...viewModel.maxPartySize)
            }
            Section("Time") {
                AsyncContentView(state: viewModel.slots, retry: viewModel.loadSlots) { slots in
                    if slots.isEmpty {
                        Text("No times left on this day.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: Spacing.small * 2)], spacing: Spacing.small * 2) {
                            ForEach(slots) { slot in
                                SlotButton(slot: slot, isSelected: slot.start == viewModel.selectedSlot?.start) {
                                    viewModel.selectedSlot = slot
                                }
                            }
                        }
                        .padding(.vertical, Spacing.small)
                    }
                }
                .frame(minHeight: 60)
            }
            Section("Notes") {
                TextField("Allergies, accessibility, occasion", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            if let message = viewModel.errorMessage {
                Section {
                    Text(message).foregroundStyle(Palette.negative)
                }
            }
            Section {
                Button(viewModel.selectedSlot.map { "Book \($0.start.formatted(date: .omitted, time: .shortened))" } ?? "Choose a time") {
                    Task { await viewModel.book() }
                }
                .buttonStyle(.primary)
                .disabled(viewModel.selectedSlot == nil || viewModel.isBooking)
                .listRowInsets(EdgeInsets())
            }
        }
    }
}

private struct DayChip: View {
    let day: Date
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(day, format: .dateTime.weekday(.abbreviated)).font(.caption)
                Text(day, format: .dateTime.day()).font(.headline)
            }
            .frame(width: 48, height: 56)
            .background(isSelected ? Palette.accent : Palette.cardBackground, in: RoundedRectangle(cornerRadius: Radius.button))
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct SlotButton: View {
    let slot: TimeSlot
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(slot.start, format: .dateTime.hour().minute())
                .font(.subheadline.monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(isSelected ? Palette.accent : Palette.cardBackground, in: RoundedRectangle(cornerRadius: Radius.button))
                .foregroundStyle(isSelected ? .white : (slot.isFull ? .secondary : .primary))
                .strikethrough(slot.isFull)
        }
        .buttonStyle(.plain)
        .disabled(slot.isFull)
        .accessibilityLabel(slot.isFull ? "\(slot.start.formatted(date: .omitted, time: .shortened)), full" : slot.start.formatted(date: .omitted, time: .shortened))
    }
}

private struct BookingConfirmation: View {
    let reservation: Reservation
    let done: () -> Void

    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Palette.positive)
            Text("You're booked")
                .font(.title2.weight(.semibold))
            Text("\(reservation.venueName)\n\(reservation.start.formatted(date: .complete, time: .shortened))\nParty of \(reservation.partySize)")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(reservation.confirmationCode)
                .font(.title3.monospaced().weight(.semibold))
                .padding(Spacing.medium)
                .background(Palette.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
            Button("Done", action: done)
                .buttonStyle(.primary)
        }
        .padding(Spacing.large)
    }
}

#Preview {
    NavigationStack {
        BookingScreen(venue: BookableVenue(id: "rest-noodle-88", name: "Noodle Bar 88", kind: .dining), service: PreviewReservationsService())
    }
}
