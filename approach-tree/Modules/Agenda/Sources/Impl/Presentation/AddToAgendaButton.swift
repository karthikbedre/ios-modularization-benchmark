import SwiftUI

struct AddToAgendaButton: View {
    let draft: CalendarDraft
    let service: any AgendaService
    @State private var isAdded = false
    @State private var isWorking = false

    var body: some View {
        Button {
            Task { await add() }
        } label: {
            Label(isAdded ? "On your agenda" : "Add to agenda", systemImage: isAdded ? "calendar.badge.checkmark" : "calendar.badge.plus")
        }
        .disabled(isAdded || isWorking)
        .task(id: draft.sourceItemID) {
            guard let itemID = draft.sourceItemID else { return }
            isAdded = (try? await service.entry(sourceDomain: draft.sourceDomain, sourceItemID: itemID)) != nil
        }
    }

    private func add() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.add(draft)
            isAdded = true
        } catch AgendaError.alreadyAdded {
            isAdded = true
        } catch {}
    }
}

#Preview {
    AddToAgendaButton(
        draft: CalendarDraft(title: "Jazz", start: .now.addingTimeInterval(3600), end: .now.addingTimeInterval(7200), sourceDomain: "Events", sourceItemID: "e1"),
        service: PreviewAgendaService()
    )
}
