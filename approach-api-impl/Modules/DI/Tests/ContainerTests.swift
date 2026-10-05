import DI
import Testing

private protocol Greeter: Sendable {
    var name: String { get }
}

private struct NamedGreeter: Greeter {
    let name: String
}

private final class Counter: @unchecked Sendable {
    var value = 0
}

struct ContainerTests {
    @Test func registerCallsFactoryOnEveryResolve() {
        let container = Container()
        let counter = Counter()
        container.register((any Greeter).self) {
            counter.value += 1
            return NamedGreeter(name: "\(counter.value)")
        }

        _ = container.resolve((any Greeter).self)
        let second = container.resolve((any Greeter).self)

        #expect(second.name == "2")
    }

    @Test func sharedRegistrationCreatesOneInstanceLazily() {
        let container = Container()
        let counter = Counter()
        container.registerShared((any Greeter).self) {
            counter.value += 1
            return NamedGreeter(name: "shared")
        }
        #expect(counter.value == 0)

        _ = container.resolve((any Greeter).self)
        _ = container.resolve((any Greeter).self)

        #expect(counter.value == 1)
    }

    @Test func sharedFactoriesCanResolveDependenciesRegisteredLater() {
        let container = Container()
        container.registerShared(String.self) {
            "Hello, \(container.resolve((any Greeter).self).name)"
        }
        container.register((any Greeter).self) { NamedGreeter(name: "Civitas") }

        #expect(container.resolve(String.self) == "Hello, Civitas")
    }
}
