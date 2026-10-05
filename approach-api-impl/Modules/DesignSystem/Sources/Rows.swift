import CoreModels
import SwiftUI

public struct KeyValueRow: View {
    private let key: String
    private let value: String

    public init(_ key: String, value: String) {
        self.key = key
        self.value = value
    }

    public var body: some View {
        LabeledContent(key, value: value)
    }
}

public struct AmountText: View {
    private let money: Money
    private let showsSign: Bool

    public init(_ money: Money, showsSign: Bool = false) {
        self.money = money
        self.showsSign = showsSign
    }

    public var body: some View {
        Text(showsSign && money.isPositive ? "+\(money.formatted)" : money.formatted)
            .monospacedDigit()
            .foregroundStyle(showsSign ? (money.isPositive ? Palette.positive : Color.primary) : Color.primary)
    }
}

public struct StatusBadge: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = Palette.accent) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Spacing.small * 2)
            .padding(.vertical, Spacing.small)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

#Preview {
    List {
        KeyValueRow("Balance", value: Money.usd(42.5).formatted)
        AmountText(.usd(12), showsSign: true)
        StatusBadge("Active")
    }
}
