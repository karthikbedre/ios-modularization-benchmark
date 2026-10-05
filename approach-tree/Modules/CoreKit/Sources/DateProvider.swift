import Foundation

public struct DateProvider: Sendable {
    private let makeNow: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date) {
        makeNow = now
    }

    public var now: Date { makeNow() }

    public static let live = DateProvider { Date() }

    public static func fixed(_ date: Date) -> DateProvider {
        DateProvider { date }
    }
}
