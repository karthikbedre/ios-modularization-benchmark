import Foundation

// Mutable state is only touched while holding `lock`. The lock is recursive because a shared
// factory resolves its own dependencies while the lock is held.
public final class Container: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var factories: [ObjectIdentifier: @Sendable () -> Any] = [:]
    private var sharedInstances: [ObjectIdentifier: Any] = [:]

    public init() {}

    /// Calls `factory` on every resolve.
    public func register<Service>(_ type: Service.Type, factory: @escaping @Sendable () -> Service) {
        lock.withLock { factories[ObjectIdentifier(type)] = factory }
    }

    /// Calls `factory` once, on first resolve, and returns that instance afterwards.
    /// Registration order does not matter, since dependencies are only resolved when first needed.
    public func registerShared<Service>(_ type: Service.Type, factory: @escaping @Sendable () -> Service) {
        let key = ObjectIdentifier(type)
        register(type) { [unowned self] in
            lock.withLock {
                if let instance = sharedInstances[key] as? Service { return instance }
                let instance = factory()
                sharedInstances[key] = instance
                return instance
            }
        }
    }

    public func resolve<Service>(_ type: Service.Type = Service.self) -> Service {
        let factory = lock.withLock { factories[ObjectIdentifier(type)] }
        guard let service = factory?() as? Service else {
            preconditionFailure("No registration for \(type)")
        }
        return service
    }
}
