import CoreKit
import DesignSystem
import SwiftUI

struct StopDetailScreen: View {
    let stop: TransitStop
    let lines: [TransitLine]
    let service: any TransitService
    let ui: TransitUI
    @State private var departures: LoadState<[Departure]> = .idle

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ui.places.location(stop.name, stop.location)
                } label: {
                    Label("Show on map", systemImage: "map")
                }
            }
            Section("Next departures") {
                switch departures {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity)
                case .failed(let message):
                    Text(message).foregroundStyle(.secondary)
                case .loaded(let departures):
                    if departures.isEmpty {
                        Text("No more service today.").foregroundStyle(.secondary)
                    }
                    ForEach(departures) { departure in
                        DepartureRow(departure: departure)
                    }
                }
            }
        }
        .navigationTitle(stop.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ui.favorites.toggleButton(stop.favoriteDraft(lines: lines))
        }
        .refreshable { await load() }
        .task {
            // Departures are minute based, so refresh once a minute while the screen is open.
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private func load() async {
        do {
            departures = .loaded(try await service.departures(stopID: stop.id, limit: 10))
        } catch {
            departures = .failed(TransitMessages.message(for: error))
        }
    }
}

private struct DepartureRow: View {
    let departure: Departure

    var body: some View {
        HStack {
            LineBadge(line: departure.line)
            Text(departure.destination)
                .lineLimit(1)
            Spacer()
            VStack(alignment: .trailing) {
                Text(departure.time, style: .relative)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Text(departure.time.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StopLookupScreen: View {
    let stopID: String
    let service: any TransitService
    let ui: TransitUI
    @State private var data: LoadState<(stop: TransitStop, lines: [TransitLine])> = .idle

    var body: some View {
        AsyncContentView(state: data, retry: load) { data in
            StopDetailScreen(stop: data.stop, lines: data.lines, service: service, ui: ui)
        }
        .task {
            if case .idle = data { await load() }
        }
    }

    private func load() async {
        do {
            data = .loaded((try await service.stop(id: stopID), try await service.lines()))
        } catch {
            data = .failed(TransitMessages.message(for: error))
        }
    }
}

#Preview {
    NavigationStack {
        StopDetailScreen(stop: .preview, lines: [.preview], service: PreviewTransitService(), ui: .preview)
    }
}
