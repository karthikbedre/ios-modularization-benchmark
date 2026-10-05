import AgendaAPI
import DesignSystem
import SwiftUI

struct AgendaScreen: View {
    @State private var viewModel: AgendaViewModel
    @State private var isAdding = false

    init(service: any AgendaService) {
        _viewModel = State(initialValue: AgendaViewModel(service: service))
    }

    var body: some View {
        AsyncContentView(state: viewModel.state, retry: viewModel.load) { days in
            List {
                ForEach(days) { day in
                    Section {
                        if day.entries.isEmpty {
                            Text("Nothing planned")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        ForEach(day.entries) { entry in
                            NavigationLink(value: entry) {
                                AgendaEntryRow(entry: entry)
                            }
                            .swipeActions {
                                Button("Remove", role: .destructive) {
                                    Task { await viewModel.remove(entry) }
                                }
                            }
                        }
                    } header: {
                        Text(day.day.formatted(.dateTime.weekday(.wide).day().month()))
                    }
                }
            }
            .refreshable { await viewModel.load() }
        }
        .navigationTitle(viewModel.title)
        .navigationDestination(for: CalendarEntry.self) { entry in
            AgendaEntryDetailScreen(entry: entry)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Previous week", systemImage: "chevron.left") {
                    Task { await viewModel.moveWeek(by: -1) }
                }
                Button("Next week", systemImage: "chevron.right") {
                    Task { await viewModel.moveWeek(by: 1) }
                }
                Button("New entry", systemImage: "plus") {
                    isAdding = true
                }
            }
        }
        .sheet(isPresented: $isAdding, onDismiss: { Task { await viewModel.load() } }) {
            NavigationStack {
                NewAgendaEntryScreen(service: viewModel.service)
            }
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
    }
}

struct AgendaEntryRow: View {
    let entry: CalendarEntry

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            VStack(alignment: .trailing) {
                Text(entry.start, format: .dateTime.hour().minute())
                Text(entry.end, format: .dateTime.hour().minute())
                    .foregroundStyle(.secondary)
            }
            .font(.caption.monospacedDigit())
            .frame(width: 64, alignment: .trailing)
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.accent)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                if let location = entry.location {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AgendaScreen(service: PreviewAgendaService())
    }
}
