import Foundation

// Mutable state is only touched while holding `lock`.
public final class Container: @unchecked Sendable {
    private let lock = NSLock()
    private var factories: [ObjectIdentifier: @Sendable () -> Any] = [:]

    public init() {}

    public func register<Service>(_ type: Service.Type, factory: @escaping @Sendable () -> Service) {
        lock.withLock { factories[ObjectIdentifier(type)] = factory }
    }

    public func resolve<Service>(_ type: Service.Type = Service.self) -> Service {
        let factory = lock.withLock { factories[ObjectIdentifier(type)] }
        guard let service = factory?() as? Service else {
            preconditionFailure("No registration for \(type)")
        }
        return service
    }
}
