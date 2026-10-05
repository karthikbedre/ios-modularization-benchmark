import CivitasGenKit
import Foundation
import Testing

struct EmitterTests {
    private let root: URL
    private let sources: URL
    private let output: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "civitas-gen-tests-\(UUID().uuidString)")
        sources = root.appending(path: "sources")
        output = root.appending(path: "out")
        try write("App/App.swift", "import Wallet\nimport WalletAPI")
        try write("Core/CoreKit/Sources/CoreKit.swift", "public enum CoreKit {}")
        try write("Domains/Wallet/API/WalletService.swift", "public protocol WalletService {}")
        try write("Domains/Wallet/Impl/LiveWalletService.swift", "import WalletAPI\nstruct LiveWalletService: WalletService {}")
        try write("Domains/Wallet/Resources/wallet.json", "{}")
        try write("Domains/Wallet/Tests/WalletTests.swift", "@testable import Wallet\nimport WalletAPI")
    }

    private func write(_ path: String, _ text: String) throws {
        let url = sources.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: output.appending(path: path), encoding: .utf8)
    }

    private func emit(_ topology: Topology) throws -> EmitReport {
        let spec = try Spec.decode("""
        app: App
        bundleIdPrefix: test
        deploymentTarget: "17.0"
        swiftVersion: "6.0"
        core:
          - name: CoreKit
            dependsOn: []
        appCore: [CoreKit]
        apiCore: [CoreKit]
        domainCore: [CoreKit]
        domains:
          - name: Wallet
            dependsOn: []
        """)
        let graph = try ModuleGraph.make(spec: spec, topology: topology)
        return try Emitter(spec: spec, sourcesRoot: sources).emit(graph, to: output)
    }

    @Test func treeRewritesImportsAndKeepsTestImportsOfTheDomain() throws {
        try emit(.tree)

        #expect(try read("Modules/Wallet/Sources/Impl/LiveWalletService.swift") == "struct LiveWalletService: WalletService {}")
        #expect(try read("Modules/Wallet/Tests/WalletTests.swift") == "@testable import Wallet\nimport Wallet")
        #expect(try read("App/Sources/App.swift") == "import Wallet")
        #expect(try read("Project.swift").contains(#"targets += module("Wallet", dependencies: ["CoreKit"], resources: true, tests: true)"#))
    }

    @Test func apiImplCopiesSourcesUnchanged() throws {
        try emit(.apiImpl)

        #expect(try read("Modules/Wallet/Sources/Impl/LiveWalletService.swift") == "import WalletAPI\nstruct LiveWalletService: WalletService {}")
        #expect(try read("Modules/WalletAPI/Sources/API/WalletService.swift") == "public protocol WalletService {}")
        #expect(try read("Modules/Wallet/Resources/wallet.json") == "{}")
    }

    @Test func secondEmitLeavesUnchangedFilesUntouched() throws {
        let first = try emit(.apiImpl)
        let file = output.appending(path: "Modules/Wallet/Sources/Impl/LiveWalletService.swift")
        let before = try #require(try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date)

        let second = try emit(.apiImpl)

        let after = try #require(try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date)
        #expect(!first.written.isEmpty)
        #expect(second.written.isEmpty)
        #expect(second.unchanged == first.written.count)
        #expect(before == after)
    }

    @Test func onlyChangedFilesAreRewrittenAndStaleFilesRemoved() throws {
        try emit(.apiImpl)
        try write("Domains/Wallet/Impl/LiveWalletService.swift", "import WalletAPI\nstruct LiveWalletService: WalletService { let x = 1 }")
        try FileManager.default.removeItem(at: sources.appending(path: "Domains/Wallet/Resources"))
        let untouched = output.appending(path: "Civitas.xcodeproj/project.pbxproj")
        try FileManager.default.createDirectory(at: untouched.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "keep".write(to: untouched, atomically: true, encoding: .utf8)

        let report = try emit(.apiImpl)

        #expect(report.written == ["Modules/Wallet/Sources/Impl/LiveWalletService.swift", "Project.swift"])
        #expect(report.removed == ["Modules/Wallet/Resources/wallet.json"])
        #expect(!FileManager.default.fileExists(atPath: output.appending(path: "Modules/Wallet/Resources").path))
        #expect(FileManager.default.fileExists(atPath: untouched.path))
    }

    @Test func undeclaredProjectImportsFailGeneration() throws {
        try write("Domains/Wallet/API/WalletService.swift", "import Wallet\nimport SwiftUI\npublic protocol WalletService {}")

        #expect {
            try emit(.apiImpl)
        } throws: { error in
            guard case EmitterError.importViolations(let violations) = error else { return false }
            return violations == ["Domains/Wallet/API/WalletService.swift: WalletAPI imports Wallet, which it does not depend on"]
        }
    }
}
