import Foundation

/// Amounts are stored in minor units (cents) so fixtures and arithmetic stay exact.
public struct Money: Hashable, Sendable, Codable, Comparable {
    public var minorUnits: Int
    public var currencyCode: String

    public init(minorUnits: Int, currencyCode: String = "USD") {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    public static func usd(_ dollars: Decimal) -> Money {
        Money(minorUnits: NSDecimalNumber(decimal: dollars * 100).intValue)
    }

    public static let zero = Money(minorUnits: 0)

    public var amount: Decimal {
        Decimal(minorUnits) / 100
    }

    public var formatted: String {
        amount.formatted(.currency(code: currencyCode))
    }

    public var isPositive: Bool { minorUnits > 0 }

    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currencyCode == rhs.currencyCode, "Currency mismatch")
        return Money(minorUnits: lhs.minorUnits + rhs.minorUnits, currencyCode: lhs.currencyCode)
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currencyCode == rhs.currencyCode, "Currency mismatch")
        return Money(minorUnits: lhs.minorUnits - rhs.minorUnits, currencyCode: lhs.currencyCode)
    }

    public static func * (lhs: Money, rhs: Int) -> Money {
        Money(minorUnits: lhs.minorUnits * rhs, currencyCode: lhs.currencyCode)
    }

    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currencyCode == rhs.currencyCode, "Currency mismatch")
        return lhs.minorUnits < rhs.minorUnits
    }
}
