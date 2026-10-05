import AgendaAPI
import DesignSystem
import SwiftUI

struct NewAgendaEntryScreen: View {
    let service: any AgendaService
    @State private var title = ""
    @State private var location = ""
    @State private var start = Date.now.addingTimeInterval(3600)
    @State private var durationMinutes = 60
    @State private var reminder = ReminderOffset.oneHour
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                TextField("Location", text: $location)
            }
            Section {
                DatePicker("Starts", selection: $start)
                Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 15...480, step: 15)
                Picker("Reminder", selection: $reminder) {
                    ForEach(ReminderOffset.allCases, id: \.self) { offset in
                        Text(offset.title).tag(offset)
                    }
                }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(Palette.negative)
                }
            }
        }
        .navigationTitle("New entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { Task { await save() } }
            }
        }
    }

    private func save() async {
        let draft = CalendarDraft(
            title: title,
            start: start,
            end: start.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            location: location.isEmpty ? nil : location,
            sourceDomain: "Agenda",
            reminder: reminder
        )
        do {
            try await service.add(draft)
            dismiss()
        } catch let error as AgendaError {
            errorMessage = error.message
        } catch {
            errorMessage = "The entry could not be added."
        }
    }
}

extension AgendaError {
    var message: String {
        switch self {
        case .emptyTitle: "Give the entry a title."
        case .endsBeforeStart: "The entry has to end after it starts."
        case .alreadyAdded: "This is already on your agenda."
        case .notFound: "This entry no longer exists."
        }
    }
}

#Preview {
    NavigationStack {
        NewAgendaEntryScreen(service: PreviewAgendaService())
    }
}
