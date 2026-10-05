import DesignSystem
import SwiftUI

struct TripPlannerScreen: View {
    let service: any TransitService
    let stops: [TransitStop]
    @State private var fromID: String?
    @State private var toID: String?
    @State private var trip: Trip?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Picker("From", selection: $fromID) {
                    Text("Choose").tag(String?.none)
                    ForEach(stops) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("To", selection: $toID) {
                    Text("Choose").tag(String?.none)
                    ForEach(stops) { Text($0.name).tag(Optional($0.id)) }
                }
                Button("Swap", systemImage: "arrow.up.arrow.down") {
                    (fromID, toID) = (toID, fromID)
                }
                .disabled(fromID == nil && toID == nil)
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.secondary)
                }
            }
            if let trip, let departure = trip.departure, let arrival = trip.arrival {
                Section {
                    KeyValueRow("Leave", value: departure.formatted(date: .omitted, time: .shortened))
                    KeyValueRow("Arrive", value: arrival.formatted(date: .omitted, time: .shortened))
                    KeyValueRow("Transfers", value: "\(trip.transfers)")
                } header: {
                    Text("\(Int(arrival.timeIntervalSince(departure) / 60)) min trip")
                }
                ForEach(Array(trip.legs.enumerated()), id: \.offset) { _, leg in
                    Section {
                        HStack {
                            LineBadge(line: leg.line)
                            Spacer()
                            Text("\(leg.stopCount) stop\(leg.stopCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        KeyValueRow(leg.from.name, value: leg.departure.formatted(date: .omitted, time: .shortened))
                        KeyValueRow(leg.to.name, value: leg.arrival.formatted(date: .omitted, time: .shortened))
                    }
                }
            }
        }
        .navigationTitle("Plan a trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Done") { dismiss() }
        }
        .task(id: "\(fromID ?? "")-\(toID ?? "")") { await plan() }
    }

    private func plan() async {
        guard let fromID, let toID else {
            trip = nil
            errorMessage = nil
            return
        }
        do {
            trip = try await service.planTrip(fromStopID: fromID, toStopID: toID)
            errorMessage = nil
        } catch {
            trip = nil
            errorMessage = TransitMessages.message(for: error)
        }
    }
}

#Preview {
    NavigationStack {
        TripPlannerScreen(service: PreviewTransitService(), stops: [.preview])
    }
}
