import DesignSystem
import Places
import SwiftUI

struct ParkingScreen: View {
    @State private var viewModel: ParkingViewModel
    @State private var managesVehicles = false
    private let places: PlacesEntryPoints

    init(service: any ParkingService, places: PlacesEntryPoints) {
        _viewModel = State(initialValue: ParkingViewModel(service: service))
        self.places = places
    }

    var body: some View {
        AsyncContentView(state: viewModel.state, retry: viewModel.load) { content in
            List {
                if !content.active.isEmpty {
                    Section("Parked now") {
                        ForEach(content.active) { session in
                            ActiveSessionCard(session: session) { hours in
                                Task { await viewModel.extend(session, by: hours) }
                            } onEnd: {
                                Task { await viewModel.end(session) }
                            }
                        }
                    }
                }
                if let message = viewModel.errorMessage {
                    Section {
                        Text(message).foregroundStyle(Palette.negative)
                    }
                }
                Section("Zones") {
                    ForEach(content.zones) { availability in
                        NavigationLink(value: availability) {
                            ZoneRow(availability: availability)
                        }
                        .disabled(availability.isFull)
                    }
                }
            }
            .refreshable { await viewModel.load() }
        }
        .navigationTitle("Parking")
        .toolbar {
            Button("Vehicles", systemImage: "car.2") { managesVehicles = true }
        }
        .navigationDestination(for: ZoneAvailability.self) { availability in
            StartParkingScreen(availability: availability, service: viewModel.service, places: places) {
                Task { await viewModel.load() }
            }
        }
        .sheet(isPresented: $managesVehicles, onDismiss: { Task { await viewModel.load() } }) {
            NavigationStack {
                VehiclesScreen(service: viewModel.service)
            }
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
    }
}

private struct ActiveSessionCard: View {
    let session: ParkingSession
    let onExtend: (Int) -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small * 2) {
            HStack {
                Label(session.plate, systemImage: "car.fill").font(.headline)
                Spacer()
                AmountText(session.cost).font(.subheadline)
            }
            Text(session.zoneName).foregroundStyle(.secondary)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, session.end.timeIntervalSince(context.date))
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text(Duration.seconds(remaining).formatted(.time(pattern: .hourMinuteSecond)))
                        .font(.system(.title, design: .rounded).monospacedDigit().weight(.semibold))
                        .foregroundStyle(remaining < 600 ? Palette.warning : Palette.accent)
                    ProgressView(value: min(1, context.date.timeIntervalSince(session.start) / session.end.timeIntervalSince(session.start)))
                        .tint(remaining < 600 ? Palette.warning : Palette.accent)
                    Text("Until \(session.end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Menu("Extend") {
                    ForEach(1...3, id: \.self) { hours in
                        Button("+\(hours) hour\(hours == 1 ? "" : "s")") { onExtend(hours) }
                    }
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("End now", role: .destructive, action: onEnd)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, Spacing.small)
    }
}

private struct ZoneRow: View {
    let availability: ZoneAvailability

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(availability.zone.name)
                Text("\(availability.zone.hourlyRate.formatted)/h · max \(availability.zone.maxHours) h")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if availability.isFull {
                StatusBadge("Full", color: Palette.negative)
            } else {
                StatusBadge("\(availability.availableSpots) free", color: availability.availableSpots <= 2 ? Palette.warning : Palette.positive)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ParkingScreen(service: PreviewParkingService(), places: PlacesEntryPoints(place: { _ in AnyView(EmptyView()) }, location: { _, _ in AnyView(Text("Map")) }))
    }
}
