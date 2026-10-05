import DesignSystem
import SwiftUI

struct SearchScreen: View {
    @State private var viewModel: SearchViewModel
    private let ui: SearchUI

    init(service: any SearchService, ui: SearchUI) {
        _viewModel = State(initialValue: SearchViewModel(service: service))
        self.ui = ui
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.small * 2) {
                        ForEach(SearchScope.allCases, id: \.self) { scope in
                            Button {
                                viewModel.toggle(scope)
                            } label: {
                                Label(scope.title, systemImage: scope.systemImage)
                                    .font(.caption)
                                    .padding(.horizontal, Spacing.medium)
                                    .padding(.vertical, Spacing.small * 2)
                                    .background(viewModel.scopes.contains(scope) ? Palette.accent : Palette.cardBackground, in: Capsule())
                                    .foregroundStyle(viewModel.scopes.contains(scope) ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.medium, bottom: 0, trailing: Spacing.medium))
                .listRowBackground(Color.clear)
            }
            if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                recentSection
            } else {
                resultSections
            }
        }
        .navigationTitle("Search")
        .searchable(text: $viewModel.query, prompt: "Events, food, books, stops, places")
        .onSubmit(of: .search) { Task { await viewModel.submit() } }
        .navigationDestination(for: SearchResult.self) { result in
            ui.destination(for: result)
        }
        .task { await viewModel.loadRecent() }
        .task(id: "\(viewModel.query)|\(viewModel.scopes.map(\.rawValue).sorted())") {
            await viewModel.search()
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if viewModel.recent.isEmpty {
            EmptyStateView("Search the city", systemImage: "magnifyingglass", message: "Try \"harbor\", \"jazz\" or \"Central\".")
        } else {
            Section {
                ForEach(viewModel.recent, id: \.self) { query in
                    Button {
                        viewModel.query = query
                    } label: {
                        Label(query, systemImage: "clock.arrow.circlepath")
                    }
                }
            } header: {
                HStack {
                    Text("Recent")
                    Spacer()
                    Button("Clear") { Task { await viewModel.clearRecent() } }
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var resultSections: some View {
        if let response = viewModel.response {
            if response.results.isEmpty {
                EmptyStateView("No results", systemImage: "magnifyingglass", message: "Nothing matches \"\(viewModel.query)\".")
            }
            ForEach(viewModel.groups, id: \.scope) { group in
                Section(group.scope.title) {
                    ForEach(group.results) { result in
                        NavigationLink(value: result) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                    Text(result.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: result.scope.systemImage).foregroundStyle(Palette.accent)
                            }
                        }
                    }
                }
            }
            if !response.unavailable.isEmpty {
                Section {
                    Text("Some results are unavailable right now: \(response.unavailable.map(\.title).sorted().joined(separator: ", ")).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchScreen(service: PreviewSearchService(), ui: .preview)
    }
}
