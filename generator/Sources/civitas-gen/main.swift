import CivitasGenKit
import Foundation

// Usage: civitas-gen [--repo <path>]
// Reads spec/domains.yaml and sources/, writes approach-<topology> for every topology.

let arguments = Array(CommandLine.arguments.dropFirst())
let repoPath = arguments.firstIndex(of: "--repo").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
let repo = URL(filePath: repoPath ?? FileManager.default.currentDirectoryPath)

do {
    let spec = try Spec.load(from: repo.appending(path: "spec/domains.yaml"))
    let emitter = Emitter(spec: spec, sourcesRoot: repo.appending(path: "sources"))
    for topology in Topology.allCases {
        let graph = try ModuleGraph.make(spec: spec, topology: topology)
        let outputPath = "approach-\(topology.rawValue)"
        let report = try emitter.emit(graph, to: repo.appending(path: outputPath))
        print("\(topology.rawValue): \(graph.modules.count) targets, \(graph.edgeCount) edges -> \(outputPath) (\(report.written.count) written, \(report.removed.count) removed, \(report.unchanged) unchanged)")
    }
} catch {
    FileHandle.standardError.write(Data("civitas-gen: \(error)\n".utf8))
    exit(1)
}
