import CoreKit
import DesignSystem
import Places
import SwiftUI

struct ReportsScreen: View {
    let service: any ReportIssueService
    let places: PlacesEntryPoints
    @State private var reports: LoadState<[IssueReport]> = .idle
    @State private var reporting = false

    var body: some View {
        AsyncContentView(state: reports, retry: load) { reports in
            List {
                Section {
                    Button("Report an issue", systemImage: "plus.circle.fill") { reporting = true }
                        .font(.headline)
                }
                if reports.isEmpty {
                    EmptyStateView("No reports yet", systemImage: "wrench.and.screwdriver", message: "Potholes, broken lights, graffiti. Tell the city and track the fix.")
                }
                let open = reports.filter(\.isOpen)
                if !open.isEmpty {
                    Section("Open") {
                        ForEach(open) { report in
                            NavigationLink(value: report) { ReportRow(report: report) }
                        }
                    }
                }
                let resolved = reports.filter { !$0.isOpen }
                if !resolved.isEmpty {
                    Section("Resolved") {
                        ForEach(resolved) { report in
                            NavigationLink(value: report) { ReportRow(report: report) }
                        }
                    }
                }
            }
            .refreshable { await load() }
        }
        .navigationTitle("Report an issue")
        .navigationDestination(for: IssueReport.self) { report in
            ReportDetailScreen(report: report, places: places)
        }
        .sheet(isPresented: $reporting, onDismiss: { Task { await load() } }) {
            NavigationStack {
                NewReportScreen(service: service)
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            reports = .loaded(try await service.myReports())
        } catch {
            reports = .failed("Your reports could not be loaded.")
        }
    }
}

struct ReportRow: View {
    let report: IssueReport

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: report.category.systemImage)
                .foregroundStyle(report.status.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(report.category.title)
                Text(report.addressHint.isEmpty ? report.createdAt.formatted(date: .abbreviated, time: .omitted) : report.addressHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(report.status.title, color: report.status.tint)
        }
    }
}

struct ReportDetailScreen: View {
    let report: IssueReport
    let places: PlacesEntryPoints

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Label(report.category.title, systemImage: report.category.systemImage)
                        .font(.headline)
                    Text(report.details)
                    if !report.supporterIDs.isEmpty {
                        Text("\(report.supporterIDs.count) neighbors also reported this")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    places.location(report.category.title, report.location)
                } label: {
                    KeyValueRow("Where", value: report.addressHint.isEmpty ? "Pinned location" : report.addressHint)
                }
                KeyValueRow("Reference", value: report.id)
            }
            Section("Progress") {
                ForEach(Array(report.updates.enumerated()), id: \.offset) { index, update in
                    HStack(alignment: .top, spacing: Spacing.medium) {
                        Circle()
                            .fill(update.status.tint)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(update.status.title).font(.subheadline.weight(index == report.updates.count - 1 ? .semibold : .regular))
                            Text(update.note).font(.caption)
                            Text(update.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(report.category.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ReportsScreen(service: PreviewReportIssueService(), places: PlacesEntryPoints(place: { _ in AnyView(EmptyView()) }, location: { _, _ in AnyView(Text("Map")) }))
    }
}
