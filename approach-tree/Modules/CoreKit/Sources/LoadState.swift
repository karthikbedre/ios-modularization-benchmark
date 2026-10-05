public enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    public var value: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }

    public var isLoading: Bool {
        if case .loading = self { true } else { false }
    }
}

extension LoadState: Sendable where Value: Sendable {}
extension LoadState: Equatable where Value: Equatable {}
