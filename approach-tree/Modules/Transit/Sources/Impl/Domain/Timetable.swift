import Foundation

/// Departures derived from a line's first and last service, headway and stop spacing.
/// Every line runs in both directions on the same schedule.
enum Timetable {
    struct Run: Hashable {
        var time: Date
        var towardIndex: Int
    }

    /// Next runs leaving the stop at `index`, in both directions, strictly after `after`.
    static func runs(of line: TransitLine, fromIndex index: Int, after: Date, limit: Int, calendar: Calendar = .current) -> [Run] {
        let last = line.stopIDs.count - 1
        var runs: [Run] = []
        if index < last {
            runs += times(line, offsetStops: index, after: after, calendar: calendar).map { Run(time: $0, towardIndex: last) }
        }
        if index > 0 {
            runs += times(line, offsetStops: last - index, after: after, calendar: calendar).map { Run(time: $0, towardIndex: 0) }
        }
        return Array(runs.sorted { $0.time < $1.time }.prefix(limit))
    }

    /// The first run from `fromIndex` heading toward `toIndex`, strictly after `after`.
    static func next(on line: TransitLine, from fromIndex: Int, to toIndex: Int, after: Date, calendar: Calendar = .current) -> (departure: Date, arrival: Date)? {
        guard fromIndex != toIndex else { return nil }
        let forward = toIndex > fromIndex
        let offset = forward ? fromIndex : line.stopIDs.count - 1 - fromIndex
        guard let departure = times(line, offsetStops: offset, after: after, calendar: calendar).first else { return nil }
        let travel = TimeInterval(abs(toIndex - fromIndex) * line.minutesBetweenStops * 60)
        return (departure, departure.addingTimeInterval(travel))
    }

    /// Times at a stop `offsetStops` from the starting terminus, today and tomorrow, strictly after `after`.
    private static func times(_ line: TransitLine, offsetStops: Int, after: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: after)
        let offset = offsetStops * line.minutesBetweenStops
        var result: [Date] = []
        for day in 0...1 {
            guard let dayStart = calendar.date(byAdding: .day, value: day, to: today) else { continue }
            for base in stride(from: line.firstDeparture, through: line.lastDeparture, by: line.headwayMinutes) {
                let time = dayStart.addingTimeInterval(TimeInterval((base + offset) * 60))
                if time > after { result.append(time) }
            }
        }
        return result
    }
}

enum TripPlanner {
    static let transferBuffer: TimeInterval = 2 * 60

    static func plan(from origin: TransitStop, to destination: TransitStop, lines: [TransitLine], stops: [String: TransitStop], after: Date, calendar: Calendar = .current) -> Trip? {
        var candidates: [Trip] = []

        for line in lines {
            guard let i = line.stopIDs.firstIndex(of: origin.id), let j = line.stopIDs.firstIndex(of: destination.id),
                  let run = Timetable.next(on: line, from: i, to: j, after: after, calendar: calendar) else { continue }
            candidates.append(Trip(legs: [TripLeg(line: line, from: origin, to: destination, departure: run.departure, arrival: run.arrival, stopCount: abs(j - i))]))
        }

        for first in lines where first.stopIDs.contains(origin.id) {
            for second in lines where second.id != first.id && second.stopIDs.contains(destination.id) {
                for transferID in first.stopIDs where transferID != origin.id && transferID != destination.id && second.stopIDs.contains(transferID) {
                    guard let transfer = stops[transferID],
                          let i = first.stopIDs.firstIndex(of: origin.id), let t1 = first.stopIDs.firstIndex(of: transferID),
                          let t2 = second.stopIDs.firstIndex(of: transferID), let j = second.stopIDs.firstIndex(of: destination.id),
                          let leg1 = Timetable.next(on: first, from: i, to: t1, after: after, calendar: calendar),
                          let leg2 = Timetable.next(on: second, from: t2, to: j, after: leg1.arrival.addingTimeInterval(transferBuffer - 1), calendar: calendar)
                    else { continue }
                    candidates.append(Trip(legs: [
                        TripLeg(line: first, from: origin, to: transfer, departure: leg1.departure, arrival: leg1.arrival, stopCount: abs(t1 - i)),
                        TripLeg(line: second, from: transfer, to: destination, departure: leg2.departure, arrival: leg2.arrival, stopCount: abs(j - t2)),
                    ]))
                }
            }
        }

        return candidates.min { lhs, rhs in
            lhs.arrival! != rhs.arrival! ? lhs.arrival! < rhs.arrival! : lhs.transfers < rhs.transfers
        }
    }
}
