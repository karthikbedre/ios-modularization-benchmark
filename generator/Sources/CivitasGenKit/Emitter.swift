import Foundation

public enum EmitterError: Error, CustomStringConvertible {
    case missingSources(String)
    case unsupportedFile(String)
    case importViolations([String])

    public var description: String {
        switch self {
        case .missingSources(let path): "missing source directory \(path)"
        case .unsupportedFile(let path): "unsupported file in sources: \(path)"
        case .importViolations(let violations): "undeclared imports:\n" + violations.joined(separator: "\n")
        }
    }
}

/// Which optional folders a generated module ended up with.
struct ModuleContents {
    var hasResources = false
    var hasTests = false
}

/// Materializes one topology as a standalone Tuist project: manifests plus a copy of the canonical sources.
///
/// Files whose content is unchanged are left untouched, so their modification dates stay put and
/// incremental builds only recompile what actually changed. That matters for the benchmarks.
public struct Emitter {
    public var spec: Spec
    public var sourcesRoot: URL
    /// Files that exist only in memory, merged over `sourcesRoot`. Keyed by source folder, then relative path.
    public var virtualSources: [String: [String: Data]]

    public init(spec: Spec, sourcesRoot: URL, virtualSources: [String: [String: Data]] = [:]) {
        self.spec = spec
        self.sourcesRoot = sourcesRoot
        self.virtualSources = virtualSources
    }

    /// Generated paths relative to the output folder. Anything else there, like the Xcode project, is left alone.
    static let generatedRoots = ["App", "Modules"]
    static let generatedFiles = ["Project.swift", "Tuist.swift"]

    @discardableResult
    public func emit(_ graph: ModuleGraph, to output: URL) throws -> EmitReport {
        let rewriter = ImportRewriter(domains: Set(spec.domainNames))
        let checker = ImportChecker(graph: graph)
        var violations: [String] = []
        var planned: [String: Data] = [:]
        var contents: [String: ModuleContents] = [:]

        for module in graph.modules {
            let moduleRoot = module.kind == .app ? "App" : "Modules/\(module.name)"
            var moduleContents = ModuleContents()
            for directory in module.sourceDirectories {
                let source = sourcesRoot.appending(path: directory.source)
                let virtual = virtualSources[directory.source] ?? [:]
                guard directoryExists(source) || !virtual.isEmpty else {
                    if directory.isOptional { continue }
                    throw EmitterError.missingSources(source.path)
                }
                let onDisk = directoryExists(source) ? try files(in: source) : []
                let destination = [moduleRoot, directory.role.rawValue, directory.destination]
                    .filter { !$0.isEmpty }
                    .joined(separator: "/")
                // A test target is its own module, so it keeps importing the domain it tests.
                let owningDomain = directory.role == .tests ? nil : module.domain
                for relativePath in Set(onDisk).union(virtual.keys).sorted() {
                    let file = source.appending(path: relativePath)
                    let raw = try virtual[relativePath] ?? Data(contentsOf: file)
                    let data: Data
                    switch directory.role {
                    case .sources, .tests:
                        guard file.pathExtension == "swift" else { throw EmitterError.unsupportedFile(file.path) }
                        let text = String(decoding: raw, as: UTF8.self)
                        let output = graph.topology == .tree ? rewriter.rewriteForTree(text, owningDomain: owningDomain) : text
                        let isTest = directory.role == .tests
                        violations += checker.violations(
                            in: output,
                            file: "\(directory.source)/\(relativePath)",
                            target: isTest ? "\(module.name)Tests" : module.name,
                            allowed: Set(module.dependencies + (isTest ? [module.name] : []))
                        )
                        data = Data(output.utf8)
                    case .resources:
                        data = raw
                    }
                    planned["\(destination)/\(relativePath)"] = data
                }
                moduleContents.hasResources = moduleContents.hasResources || directory.role == .resources
                moduleContents.hasTests = moduleContents.hasTests || directory.role == .tests
            }
            contents[module.name] = moduleContents
        }

        guard violations.isEmpty else { throw EmitterError.importViolations(violations) }

        planned["Project.swift"] = Data(ProjectManifest.render(spec: spec, graph: graph, contents: contents).utf8)
        planned["Tuist.swift"] = Data(ProjectManifest.renderTuistConfig().utf8)

        return try sync(planned, into: output)
    }

    /// Writes changed files, deletes stale ones, and prunes folders left empty.
    private func sync(_ planned: [String: Data], into output: URL) throws -> EmitReport {
        let fileManager = FileManager.default
        var report = EmitReport()

        var existing: Set<String> = []
        for root in Self.generatedRoots where directoryExists(output.appending(path: root)) {
            existing.formUnion(try files(in: output.appending(path: root)).map { "\(root)/\($0)" })
        }
        existing.formUnion(Self.generatedFiles.filter { fileManager.fileExists(atPath: output.appending(path: $0).path) })

        for (path, data) in planned.sorted(by: { $0.key < $1.key }) {
            let url = output.appending(path: path)
            if existing.contains(path), (try? Data(contentsOf: url)) == data {
                report.unchanged += 1
                continue
            }
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            report.written.append(path)
        }

        for path in existing.subtracting(planned.keys).sorted() {
            try fileManager.removeItem(at: output.appending(path: path))
            report.removed.append(path)
        }
        for root in Self.generatedRoots {
            try pruneEmptyDirectories(in: output.appending(path: root))
        }
        return report
    }

    private func pruneEmptyDirectories(in directory: URL) throws {
        guard directoryExists(directory) else { return }
        let fileManager = FileManager.default
        let subdirectories = try fileManager.subpathsOfDirectory(atPath: directory.path)
            .filter { directoryExists(directory.appending(path: $0)) }
            .sorted { $0.count > $1.count }
        for subdirectory in subdirectories {
            let url = directory.appending(path: subdirectory)
            if try fileManager.contentsOfDirectory(atPath: url.path).allSatisfy({ $0 == ".DS_Store" }) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func files(in directory: URL) throws -> [String] {
        try FileManager.default.subpathsOfDirectory(atPath: directory.path).sorted().filter { relativePath in
            let file = directory.appending(path: relativePath)
            return !directoryExists(file) && file.lastPathComponent != ".DS_Store"
        }
    }
}

public struct EmitReport: Equatable, Sendable {
    public var written: [String] = []
    public var removed: [String] = []
    public var unchanged = 0
}
