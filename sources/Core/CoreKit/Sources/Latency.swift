/// Simulated backend latency for mock repositories. Tests use `.none`.
public struct Latency: Sendable {
    public var duration: Duration

    public init(duration: Duration) {
        self.duration = duration
    }

    public static let none = Latency(duration: .zero)
    public static let standard = Latency(duration: .milliseconds(150))

    public func wait() async {
        guard duration > .zero else { return }
        try? await Task.sleep(for: duration)
    }
}
