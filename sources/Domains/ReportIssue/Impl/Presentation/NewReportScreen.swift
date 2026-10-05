import CoreModels
import DesignSystem
import MapKit
import ReportIssueAPI
import SwiftUI

struct NewReportScreen: View {
    let service: any ReportIssueService
    @State private var category: IssueCategory?
    @State private var details = ""
    @State private var addressHint = ""
    @State private var center = GeoPoint(latitude: 40.7149, longitude: -74.0055)
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7149, longitude: -74.0055), latitudinalMeters: 800, longitudinalMeters: 800
    ))
    @State private var duplicateID: String?
    @State private var errorMessage: String?
    @State private var submitted: IssueReport?
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let submitted {
                VStack(spacing: Spacing.large) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Palette.positive)
                    Text("Thanks for reporting").font(.title2.weight(.semibold))
                    Text("Reference \(submitted.id). We will update you as the city works on it.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Done") { dismiss() }
                        .buttonStyle(.primary)
                }
                .padding(Spacing.large)
            } else {
                form
            }
        }
        .navigationTitle("New report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if submitted == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .alert("Already reported?", isPresented: Binding { duplicateID != nil } set: { if !$0 { duplicateID = nil } }) {
            Button("Add my support") {
                if let duplicateID { Task { await support(duplicateID) } }
            }
            Button("Report anyway") {
                Task { await submit(confirmedNotDuplicate: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A similar issue is already open within a short walk. Supporting it helps the city prioritize.")
        }
    }

    private var form: some View {
        Form {
            Section("What is the problem?") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.small * 2)], spacing: Spacing.small * 2) {
                    ForEach(IssueCategory.allCases, id: \.self) { option in
                        Button {
                            category = option
                        } label: {
                            VStack(spacing: Spacing.small) {
                                Image(systemName: option.systemImage).font(.title3)
                                Text(option.title).font(.caption).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(category == option ? Palette.accent : Palette.cardBackground, in: RoundedRectangle(cornerRadius: Radius.button))
                            .foregroundStyle(category == option ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, Spacing.small)
            }
            Section {
                Map(position: $position) {}
                    .overlay {
                        Image(systemName: "mappin")
                            .font(.title)
                            .foregroundStyle(Palette.negative)
                            .offset(y: -12)
                    }
                    .onMapCameraChange(frequency: .onEnd) { context in
                        center = GeoPoint(latitude: context.region.center.latitude, longitude: context.region.center.longitude)
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                TextField("Nearest address or landmark", text: $addressHint)
            } header: {
                Text("Where is it?")
            } footer: {
                Text("Move the map so the pin sits on the problem.")
            }
            Section("Details") {
                TextField("What did you see?", text: $details, axis: .vertical)
                    .lineLimit(3...6)
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(Palette.negative)
                }
            }
            Section {
                Button("Send report") {
                    Task { await submit(confirmedNotDuplicate: false) }
                }
                .buttonStyle(.primary)
                .disabled(category == nil || isSending)
                .listRowInsets(EdgeInsets())
            }
        }
    }

    private func submit(confirmedNotDuplicate: Bool) async {
        guard let category else { return }
        isSending = true
        defer { isSending = false }
        do {
            submitted = try await service.submit(IssueDraft(category: category, details: details, location: center,
                                                            addressHint: addressHint, confirmedNotDuplicate: confirmedNotDuplicate))
            errorMessage = nil
        } catch ReportIssueError.possibleDuplicate(let reportID) {
            duplicateID = reportID
        } catch {
            errorMessage = ReportIssueMessages.message(for: error)
        }
    }

    private func support(_ reportID: String) async {
        do {
            submitted = try await service.support(reportID: reportID)
        } catch {
            errorMessage = ReportIssueMessages.message(for: error)
        }
    }
}

#Preview {
    NavigationStack {
        NewReportScreen(service: PreviewReportIssueService())
    }
}
