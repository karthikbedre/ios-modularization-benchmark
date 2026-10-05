import CivitasGenKit
import Testing

private func spec(domains: String) throws -> Spec {
    try Spec.decode("""
    app: App
    bundleIdPrefix: test
    deploymentTarget: "17.0"
    swiftVersion: "6.0"
    core:
      - name: CoreKit
        dependsOn: []
      - name: DI
        dependsOn: []
    appCore: [DI]
    apiCore: [CoreKit]
    domainCore: [CoreKit, DI]
    domains:
    \(domains)
    """)
}

private let walletAndTickets = """
  - name: Wallet
    dependsOn: []
  - name: Tickets
    dependsOn: [Wallet]
"""

struct ModuleGraphTests {
    @Test func treeHasOneModulePerDomainWithDirectImplEdges() throws {
        let graph = try ModuleGraph.make(spec: spec(domains: walletAndTickets), topology: .tree)

        #expect(graph.modules.map(\.name) == ["App", "CoreKit", "DI", "Wallet", "Tickets"])
        #expect(graph.module(named: "Tickets")?.dependencies == ["CoreKit", "DI", "Wallet"])
        #expect(graph.module(named: "Tickets")?.sourceDirectories.map(\.source) == ["Domains/Tickets/API", "Domains/Tickets/Impl"])
    }

    @Test func apiImplSplitsDomainsAndOnlyDependsOnAPIs() throws {
        let graph = try ModuleGraph.make(spec: spec(domains: walletAndTickets), topology: .apiImpl)

        #expect(graph.modules.map(\.name) == ["App", "CoreKit", "DI", "WalletAPI", "Wallet", "TicketsAPI", "Tickets"])
        #expect(graph.module(named: "Tickets")?.dependencies == ["CoreKit", "DI", "TicketsAPI", "WalletAPI"])
        #expect(graph.module(named: "TicketsAPI")?.dependencies == ["CoreKit"])
        #expect(graph.module(named: "App")?.dependencies == ["DI", "WalletAPI", "Wallet", "TicketsAPI", "Tickets"])
    }

    @Test func rejectsDomainCycles() throws {
        let cyclic = """
          - name: Wallet
            dependsOn: [Tickets]
          - name: Tickets
            dependsOn: [Wallet]
        """
        #expect(throws: GraphError.cycle(["Wallet", "Tickets", "Wallet"])) {
            try ModuleGraph.make(spec: spec(domains: cyclic), topology: .tree)
        }
    }

    @Test func rejectsUnknownDomainDependency() throws {
        let unknown = """
          - name: Wallet
            dependsOn: [Bank]
        """
        #expect(throws: GraphError.unknownDependency(module: "Wallet", dependency: "Bank")) {
            try ModuleGraph.make(spec: spec(domains: unknown), topology: .apiImpl)
        }
    }

    @Test(arguments: [
        ("WalletAPI", Module.Kind.api, "TicketsAPI", Module.Kind.api),
        ("Wallet", Module.Kind.impl, "Tickets", Module.Kind.impl),
        ("CoreKit", Module.Kind.core, "TicketsAPI", Module.Kind.api),
    ])
    func apiImplRejectsForbiddenEdges(from: String, fromKind: Module.Kind, to: String, toKind: Module.Kind) {
        let graph = ModuleGraph(topology: .apiImpl, modules: [
            Module(name: from, kind: fromKind, dependencies: [to], sourceDirectories: []),
            Module(name: to, kind: toKind, dependencies: [], sourceDirectories: []),
        ])

        #expect(throws: GraphError.self) { try graph.lint() }
    }
}

struct ImportRewriterTests {
    private let rewriter = ImportRewriter(domains: ["Wallet", "Tickets"])

    @Test func pointsAPIImportsAtDomainModulesAndDropsOwnAPI() {
        let source = """
        import CoreKit
        import TicketsAPI
        @testable import WalletAPI
        import SwiftUI
        """

        let rewritten = rewriter.rewriteForTree(source, owningDomain: "Tickets")

        #expect(rewritten == """
        import CoreKit
        @testable import Wallet
        import SwiftUI
        """)
    }

    @Test func dedupesImportsThatCollapseIntoOneModule() {
        let source = """
        import Wallet
        import WalletAPI
        let x = 1
        """

        #expect(rewriter.rewriteForTree(source, owningDomain: nil) == "import Wallet\nlet x = 1")
    }

    @Test func leavesNonDomainAPIModulesAlone() {
        #expect(rewriter.rewriteForTree("import MapKitAPI", owningDomain: nil) == "import MapKitAPI")
    }
}
