/// Verifies that source files only import project modules their target declares as dependencies.
/// The spec-level lint proves the graph follows the topology rules. This proves the code does too.
struct ImportChecker {
    let projectModules: Set<String>

    init(graph: ModuleGraph) {
        projectModules = Set(graph.modules.map(\.name))
    }

    /// Returns one message per undeclared import of a project module.
    func violations(in source: String, file: String, target: String, allowed: Set<String>) -> [String] {
        source.split(separator: "\n").compactMap { line in
            guard let match = line.wholeMatch(of: /\s*(?:@testable\s+)?(?:@_exported\s+)?import\s+(\w+)\s*/) else { return nil }
            let module = String(match.output.1)
            guard projectModules.contains(module), !allowed.contains(module) else { return nil }
            return "\(file): \(target) imports \(module), which it does not depend on"
        }
    }
}
