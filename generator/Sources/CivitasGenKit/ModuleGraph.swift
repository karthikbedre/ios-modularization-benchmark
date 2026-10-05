public enum Topology: String, CaseIterable, Sendable {
    case tree
    case apiImpl = "api-impl"
}

public struct SourceDirectory: Equatable, Sendable {
    /// Path relative to the canonical `sources/` root.
    public var source: String
    /// Path relative to the module's generated `Sources/` folder.
    public var destination: String
}

public struct Module: Equatable, Sendable {
    public enum Kind: Sendable {
        case app, core, api, impl
    }

    public var name: String
    public var kind: Kind
    public var dependencies: [String]
    public var sourceDirectories: [SourceDirectory]
    /// The domain this module belongs to, if any.
    public var domain: String?

    public init(name: String, kind: Kind, dependencies: [String], sourceDirectories: [SourceDirectory], domain: String? = nil) {
        self.name = name
        self.kind = kind
        self.dependencies = dependencies
        self.sourceDirectories = sourceDirectories
        self.domain = domain
    }
}

public enum GraphError: Error, Equatable, CustomStringConvertible {
    case duplicateModule(String)
    case unknownDependency(module: String, dependency: String)
    case cycle([String])
    case ruleViolation(String)

    public var description: String {
        switch self {
        case .duplicateModule(let name): "duplicate module \(name)"
        case .unknownDependency(let module, let dependency): "\(module) depends on unknown module \(dependency)"
        case .cycle(let path): "dependency cycle: \(path.joined(separator: " -> "))"
        case .ruleViolation(let message): message
        }
    }
}

public struct ModuleGraph: Sendable {
    public var topology: Topology
    public var modules: [Module]

    public init(topology: Topology, modules: [Module]) {
        self.topology = topology
        self.modules = modules
    }

    public func module(named name: String) -> Module? {
        modules.first { $0.name == name }
    }

    public var edgeCount: Int {
        modules.reduce(0) { $0 + $1.dependencies.count }
    }
}

extension ModuleGraph {
    public static func make(spec: Spec, topology: Topology) throws -> ModuleGraph {
        try validate(spec)
        let domains = spec.domainNames
        var modules: [Module] = []

        let appDependencies: [String] = switch topology {
        case .tree: spec.appCore + domains
        case .apiImpl: spec.appCore + domains.flatMap { [apiName($0), $0] }
        }
        modules.append(Module(
            name: spec.app,
            kind: .app,
            dependencies: appDependencies,
            sourceDirectories: [SourceDirectory(source: "App", destination: "")]
        ))

        for core in spec.core {
            modules.append(Module(
                name: core.name,
                kind: .core,
                dependencies: core.dependsOn,
                sourceDirectories: [SourceDirectory(source: "Core/\(core.name)", destination: "")]
            ))
        }

        for domain in spec.domains {
            let api = SourceDirectory(source: "Domains/\(domain.name)/API", destination: "API")
            let impl = SourceDirectory(source: "Domains/\(domain.name)/Impl", destination: "Impl")
            switch topology {
            case .tree:
                modules.append(Module(
                    name: domain.name,
                    kind: .impl,
                    dependencies: spec.domainCore + domain.dependsOn,
                    sourceDirectories: [api, impl],
                    domain: domain.name
                ))
            case .apiImpl:
                modules.append(Module(
                    name: apiName(domain.name),
                    kind: .api,
                    dependencies: spec.apiCore,
                    sourceDirectories: [api],
                    domain: domain.name
                ))
                modules.append(Module(
                    name: domain.name,
                    kind: .impl,
                    dependencies: spec.domainCore + [apiName(domain.name)] + domain.dependsOn.map(apiName),
                    sourceDirectories: [impl],
                    domain: domain.name
                ))
            }
        }

        let graph = ModuleGraph(topology: topology, modules: modules)
        try graph.lint()
        return graph
    }

    public static func apiName(_ domain: String) -> String {
        domain + "API"
    }

    static func validate(_ spec: Spec) throws {
        let core = Set(spec.core.map(\.name))
        let domains = Set(spec.domainNames)
        for name in spec.appCore + spec.apiCore + spec.domainCore where !core.contains(name) {
            throw GraphError.unknownDependency(module: "appCore/apiCore/domainCore", dependency: name)
        }
        for module in spec.core {
            for dependency in module.dependsOn where !core.contains(dependency) {
                throw GraphError.ruleViolation("core module \(module.name) may only depend on core modules, found \(dependency)")
            }
        }
        for module in spec.domains {
            for dependency in module.dependsOn where !domains.contains(dependency) {
                throw GraphError.unknownDependency(module: module.name, dependency: dependency)
            }
        }
    }

    /// Checks names, edges, acyclicity and the topology's dependency rules.
    public func lint() throws {
        var byName: [String: Module] = [:]
        for module in modules {
            guard byName.updateValue(module, forKey: module.name) == nil else {
                throw GraphError.duplicateModule(module.name)
            }
        }

        for module in modules {
            for dependency in module.dependencies {
                guard let target = byName[dependency] else {
                    throw GraphError.unknownDependency(module: module.name, dependency: dependency)
                }
                if let violation = ruleViolation(from: module, to: target) {
                    throw GraphError.ruleViolation(violation)
                }
            }
        }

        if let cycle = findCycle(byName) {
            throw GraphError.cycle(cycle)
        }
    }

    private func ruleViolation(from module: Module, to target: Module) -> String? {
        let edge = "\(module.name) -> \(target.name)"
        switch (topology, module.kind, target.kind) {
        case (_, _, .app):
            return "nothing may depend on the app target: \(edge)"
        case (_, .app, _), (_, _, .core):
            return nil
        case (_, .core, _):
            return "core modules may only depend on core modules: \(edge)"
        case (.tree, .api, _), (.tree, _, .api):
            return "the tree topology has no API modules: \(edge)"
        case (.tree, .impl, .impl):
            return nil
        case (.apiImpl, .api, _):
            return "API modules may only depend on core modules: \(edge)"
        case (.apiImpl, .impl, .api):
            return nil
        case (.apiImpl, .impl, .impl):
            return "domain modules may not depend on other domain modules: \(edge)"
        }
    }

    private func findCycle(_ byName: [String: Module]) -> [String]? {
        enum Mark { case visiting, done }
        var marks: [String: Mark] = [:]
        var path: [String] = []

        func visit(_ name: String) -> [String]? {
            switch marks[name] {
            case .done: return nil
            case .visiting:
                let start = path.firstIndex(of: name)!
                return Array(path[start...]) + [name]
            case nil: break
            }
            marks[name] = .visiting
            path.append(name)
            for dependency in byName[name]!.dependencies {
                if let cycle = visit(dependency) { return cycle }
            }
            path.removeLast()
            marks[name] = .done
            return nil
        }

        for module in modules {
            if let cycle = visit(module.name) { return cycle }
        }
        return nil
    }
}
