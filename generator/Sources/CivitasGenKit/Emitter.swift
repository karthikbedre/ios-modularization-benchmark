import Foundation

public enum EmitterError: Error, CustomStringConvertible {
    case missingSources(String)
    case unsupportedFile(String)

    public var description: String {
        switch self {
        case .missingSources(let path): "missing source directory \(path)"
        case .unsupportedFile(let path): "unsupported file in sources: \(path)"
        }
    }
}

/// Materializes one topology as a standalone Tuist project: manifests plus a copy of the canonical sources.
public struct Emitter {
    public var spec: Spec
    public var sourcesRoot: URL

    public init(spec: Spec, sourcesRoot: URL) {
        self.spec = spec
        self.sourcesRoot = sourcesRoot
    }

    public func emit(_ graph: ModuleGraph, to output: URL) throws {
        let fileManager = FileManager.default
        for generated in ["App", "Modules", "Project.swift", "Tuist.swift"] {
            let url = output.appending(path: generated)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
        try fileManager.createDirectory(at: output, withIntermediateDirectories: true)

        let rewriter = ImportRewriter(domains: Set(spec.domainNames))
        for module in graph.modules {
            let moduleSources = module.kind == .app
                ? output.appending(path: "App/Sources")
                : output.appending(path: "Modules/\(module.name)/Sources")
            for directory in module.sourceDirectories {
                let destination = directory.destination.isEmpty
                    ? moduleSources
                    : moduleSources.appending(path: directory.destination)
                try copySwiftFiles(from: sourcesRoot.appending(path: directory.source), to: destination) { text in
                    graph.topology == .tree ? rewriter.rewriteForTree(text, owningDomain: module.domain) : text
                }
            }
        }

        try ProjectManifest.render(spec: spec, graph: graph)
            .write(to: output.appending(path: "Project.swift"), atomically: true, encoding: .utf8)
        try ProjectManifest.renderTuistConfig()
            .write(to: output.appending(path: "Tuist.swift"), atomically: true, encoding: .utf8)
    }

    private func copySwiftFiles(from source: URL, to destination: URL, transform: (String) -> String) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw EmitterError.missingSources(source.path)
        }
        let relativePaths = try fileManager.subpathsOfDirectory(atPath: source.path).sorted()
        for relativePath in relativePaths {
            let file = source.appending(path: relativePath)
            var fileIsDirectory: ObjCBool = false
            fileManager.fileExists(atPath: file.path, isDirectory: &fileIsDirectory)
            if fileIsDirectory.boolValue || file.lastPathComponent == ".DS_Store" { continue }
            guard file.pathExtension == "swift" else {
                throw EmitterError.unsupportedFile(file.path)
            }
            let target = destination.appending(path: relativePath)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try transform(String(contentsOf: file, encoding: .utf8)).write(to: target, atomically: true, encoding: .utf8)
        }
    }
}
