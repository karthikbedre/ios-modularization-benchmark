import AgendaAPI
import DesignSystem
import SwiftUI

struct AgendaEntryDetailScreen: View {
    let entry: CalendarEntry

    var body: some View {
        List {
            Section {
                Text(entry.title)
                    .font(.title3.weight(.semibold))
                KeyValueRow("Starts", value: entry.start.formatted(date: .complete, time: .shortened))
                KeyValueRow("Ends", value: entry.end.formatted(date: .omitted, time: .shortened))
                if let location = entry.location {
                    KeyValueRow("Where", value: location)
                }
            }
            Section {
                KeyValueRow("Reminder", value: entry.reminder.title)
                KeyValueRow("Added from", value: entry.sourceDomain)
            }
        }
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}
