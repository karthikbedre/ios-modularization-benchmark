import CivitasGenKit
import Foundation

// Usage: civitas-gen [--repo <path>] [--domains <N>] [--output <path>]
// Reads spec/domains.yaml and sources/, and writes approach-<topology> for every topology into the
// output folder (the repo by default). With --domains N above the seed count, the graph grows to N
// domains with domains expanded from sources/Templates/SyntheticDomain.

let arguments = Array(CommandLine.arguments.dropFirst())
func value(of flag: String) -> String? {
    arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
}
let repo = URL(filePath: value(of: "--repo") ?? FileManager.default.currentDirectoryPath)
let output = value(of: "--output").map { URL(filePath: $0) } ?? repo

do {
    let seedSpec = try Spec.load(from: repo.appending(path: "spec/domains.yaml"))
    let total = Int(value(of: "--domains") ?? "") ?? seedSpec.domains.count
    let (spec, synthetic) = try SyntheticPlanner.plan(spec: seedSpec, totalDomains: total)

    let renderer = TemplateRenderer(templateRoot: repo.appending(path: "sources/Templates/SyntheticDomain"))
    var virtualSources: [String: [String: Data]] = ["App": ["Generated/SyntheticFeatures.swift": Data(SyntheticAppSource.render(synthetic).utf8)]]
    for domain in synthetic {
        virtualSources.merge(try renderer.render(domain)) { $1 }
    }

    let emitter = Emitter(spec: spec, sourcesRoot: repo.appending(path: "sources"), virtualSources: virtualSources)
    for topology in Topology.allCases {
        let graph = try ModuleGraph.make(spec: spec, topology: topology)
        let outputPath = "approach-\(topology.rawValue)"
        let report = try emitter.emit(graph, to: output.appending(path: outputPath))
        print("\(topology.rawValue): \(spec.domains.count) domains, \(graph.modules.count) targets, \(graph.edgeCount) edges -> \(output.appending(path: outputPath).path) (\(report.written.count) written, \(report.removed.count) removed, \(report.unchanged) unchanged)")
    }
} catch {
    FileHandle.standardError.write(Data("civitas-gen: \(error)\n".utf8))
    exit(1)
}
