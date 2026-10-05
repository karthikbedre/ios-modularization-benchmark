import CoreKit
import DesignSystem
import SwiftUI
import TransitAPI

struct TransitScreen: View {
    enum Tab: String, CaseIterable {
        case stops = "Stops"
        case lines = "Lines"
        case passes = "Passes"
    }

    let service: any TransitService
    let ui: TransitUI
    @State private var tab = Tab.stops
    @State private var data: LoadState<(stops: [TransitStop], lines: [TransitLine])> = .idle
    @State private var plansTrip = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.medium)
            .padding(.bottom, Spacing.small)
            switch tab {
            case .stops, .lines:
                AsyncContentView(state: data, retry: load) { data in
                    if tab == .stops {
                        List(data.stops) { stop in
                            NavigationLink(value: stop) {
                                StopRow(stop: stop, lines: data.lines.filter { $0.stopIDs.contains(stop.id) })
                            }
                        }
                    } else {
                        List(data.lines) { line in
                            LineRow(line: line, stops: data.stops)
                        }
                    }
                }
            case .passes:
                PassesView(service: service)
            }
        }
        .navigationTitle("Transit")
        .toolbar {
            Button("Plan a trip", systemImage: "point.topleft.down.to.point.bottomright.curvepath") { plansTrip = true }
        }
        .navigationDestination(for: TransitStop.self) { stop in
            StopDetailScreen(stop: stop, lines: data.value?.lines ?? [], service: service, ui: ui)
        }
        .sheet(isPresented: $plansTrip) {
            NavigationStack {
                TripPlannerScreen(service: service, stops: data.value?.stops ?? [])
            }
        }
        .task {
            if case .idle = data { await load() }
        }
    }

    private func load() async {
        do {
            async let stops = service.stops()
            async let lines = service.lines()
            data = .loaded((try await stops, try await lines))
        } catch {
            data = .failed("Transit data could not be loaded.")
        }
    }
}

private struct StopRow: View {
    let stop: TransitStop
    let lines: [TransitLine]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(stop.name)
            HStack {
                ForEach(lines) { LineBadge(line: $0) }
            }
        }
    }
}

private struct LineRow: View {
    let line: TransitLine
    let stops: [TransitStop]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                LineBadge(line: line)
                Spacer()
                Text("every \(line.headwayMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(line.stopIDs.compactMap { id in stops.first { $0.id == id }?.name }.joined(separator: " → "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        TransitScreen(service: PreviewTransitService(), ui: .preview)
    }
}
