import CoreKit
import Foundation
import Observation

@MainActor
@Observable
final class AgendaViewModel {
    private(set) var state: LoadState<[AgendaDay]> = .idle
    private(set) var weekStart: Date

    let service: any AgendaService
    private let calendar: Calendar

    init(service: any AgendaService, dates: DateProvider = .live, calendar: Calendar = .current) {
        self.service = service
        self.calendar = calendar
        weekStart = calendar.startOfDay(for: dates.now)
    }

    var title: String {
        weekStart.formatted(.dateTime.month(.wide).year())
    }

    func load() async {
        if state.value == nil { state = .loading }
        guard let end = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }
        do {
            let entries = try await service.entries(in: DateInterval(start: weekStart, end: end))
            state = .loaded(AgendaDay.week(starting: weekStart, entries: entries, calendar: calendar))
        } catch {
            state = .failed("Your agenda could not be loaded.")
        }
    }

    func moveWeek(by weeks: Int) async {
        guard let moved = calendar.date(byAdding: .day, value: 7 * weeks, to: weekStart) else { return }
        weekStart = moved
        await load()
    }

    func remove(_ entry: CalendarEntry) async {
        try? await service.remove(id: entry.id)
        await load()
    }
}
