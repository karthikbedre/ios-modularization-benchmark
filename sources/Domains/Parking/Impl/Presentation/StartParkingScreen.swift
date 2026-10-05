import CoreModels
import DesignSystem
import ParkingAPI
import PlacesAPI
import SwiftUI

struct StartParkingScreen: View {
    let availability: ZoneAvailability
    let service: any ParkingService
    let places: PlacesEntryPoints
    let onStart: () -> Void
    @State private var vehicles: [Vehicle] = []
    @State private var plate: String?
    @State private var hours = 1
    @State private var quote: ParkingQuote?
    @State private var errorMessage: String?
    @State private var isStarting = false
    @Environment(\.dismiss) private var dismiss

    private var zone: ParkingZone { availability.zone }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    places.location(zone.name, zone.location)
                } label: {
                    Label("Show on map", systemImage: "map")
                }
                KeyValueRow("Rate", value: "\(zone.hourlyRate.formatted) per hour")
                KeyValueRow("Free spots", value: "\(availability.availableSpots) of \(zone.totalSpots)")
                Text(zone.rules)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Vehicle") {
                if vehicles.isEmpty {
                    Text("Add a vehicle from the Vehicles screen first.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Vehicle", selection: $plate) {
                        ForEach(vehicles) { vehicle in
                            Text("\(vehicle.nickname) · \(vehicle.plate)").tag(Optional(vehicle.plate))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            Section("Time") {
                Stepper("\(hours) hour\(hours == 1 ? "" : "s")", value: $hours, in: 1...zone.maxHours)
                if let quote {
                    KeyValueRow("Ends", value: quote.end.formatted(date: .omitted, time: .shortened))
                    HStack {
                        Text("Total").font(.headline)
                        Spacer()
                        AmountText(quote.cost).font(.headline)
                    }
                }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(Palette.negative)
                }
            }
            Section {
                Button(quote.map { "Pay \($0.cost.formatted) and start" } ?? "Start parking") {
                    Task { await start() }
                }
                .buttonStyle(.primary)
                .disabled(plate == nil || isStarting)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("Paid with your default wallet method.")
            }
        }
        .navigationTitle(zone.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vehicles = (try? await service.vehicles()) ?? []
            plate = plate ?? vehicles.first?.plate
        }
        .task(id: hours) {
            quote = try? await service.quote(zoneID: zone.id, hours: hours)
        }
    }

    private func start() async {
        guard let plate else { return }
        isStarting = true
        defer { isStarting = false }
        do {
            _ = try await service.start(zoneID: zone.id, plate: plate, hours: hours)
            onStart()
            dismiss()
        } catch {
            errorMessage = ParkingMessages.message(for: error)
        }
    }
}

struct VehiclesScreen: View {
    let service: any ParkingService
    @State private var vehicles: [Vehicle] = []
    @State private var plate = ""
    @State private var nickname = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Saved vehicles") {
                if vehicles.isEmpty {
                    Text("No vehicles yet").foregroundStyle(.secondary)
                }
                ForEach(vehicles) { vehicle in
                    VStack(alignment: .leading) {
                        Text(vehicle.nickname)
                        Text(vehicle.plate).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) {
                            Task {
                                try? await service.removeVehicle(plate: vehicle.plate)
                                await load()
                            }
                        }
                    }
                }
            }
            Section("Add a vehicle") {
                TextField("Plate", text: $plate)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Nickname (optional)", text: $nickname)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Palette.negative)
                }
                Button("Add") { Task { await add() } }
                    .disabled(plate.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Vehicles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Done") { dismiss() }
        }
        .task { await load() }
    }

    private func load() async {
        vehicles = (try? await service.vehicles()) ?? []
    }

    private func add() async {
        do {
            _ = try await service.addVehicle(plate: plate, nickname: nickname)
            plate = ""
            nickname = ""
            errorMessage = nil
            await load()
        } catch {
            errorMessage = ParkingMessages.message(for: error)
        }
    }
}

#Preview {
    NavigationStack {
        StartParkingScreen(
            availability: ZoneAvailability(zone: .preview, availableSpots: 12),
            service: PreviewParkingService(),
            places: PlacesEntryPoints(place: { _ in AnyView(EmptyView()) }, location: { _, _ in AnyView(Text("Map")) })
        ) {}
    }
}
