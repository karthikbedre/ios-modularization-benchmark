@testable import CivitasGenKit
import Foundation
import Testing

private func seedSpec(maxDependencies: Int = 3) throws -> Spec {
    try Spec.decode("""
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
      - name: Identity
        dependsOn: []
      - name: Wallet
        dependsOn: [Identity]
      - name: Home
        dependsOn: [Identity, Wallet]
    synthetic:
      seed: 7
      identityProbability: 0.7
      minDependencies: 1
      maxDependencies: \(maxDependencies)
      hubBias: 1.0
      excluded: [Home]
      prefixes: [Street, Park, Water, Energy]
      suffixes: [Permits, Grants, Alerts]
    """)
}

struct SyntheticPlannerTests {
    @Test func sameSeedGivesTheSameGraph() throws {
        let first = try SyntheticPlanner.plan(spec: seedSpec(), totalDomains: 12).synthetic
        let second = try SyntheticPlanner.plan(spec: seedSpec(), totalDomains: 12).synthetic

        #expect(first == second)
        #expect(first.count == 9)
    }

    @Test func grownGraphIsValidInBothTopologies() throws {
        let grown = try SyntheticPlanner.plan(spec: seedSpec(), totalDomains: 15).spec

        for topology in Topology.allCases {
            #expect(throws: Never.self) { try ModuleGraph.make(spec: grown, topology: topology) }
        }
    }

    @Test func dependenciesStayInRangeAvoidExclusionsAndPointBackwards() throws {
        let synthetic = try SyntheticPlanner.plan(spec: seedSpec(), totalDomains: 15).synthetic
        var earlier: Set<String> = ["Identity", "Wallet"]

        for domain in synthetic {
            #expect((1...3).contains(domain.dependsOn.count))
            #expect(!domain.dependsOn.contains("Home"))
            #expect(Set(domain.dependsOn).isSubset(of: earlier))
            #expect(Set(domain.dependsOn).count == domain.dependsOn.count)
            earlier.insert(domain.name)
        }
    }

    @Test func namesAndTitlesComeFromPrefixesAndSuffixes() throws {
        let synthetic = try SyntheticPlanner.plan(spec: seedSpec(), totalDomains: 5).synthetic

        for domain in synthetic {
            #expect(domain.title.split(separator: " ").joined() == domain.name)
        }
        #expect(synthetic.first.map { $0.valueName.first!.isLowercase } == true)
    }

    @Test func seedCountLeavesTheSpecAlone() throws {
        let (spec, synthetic) = try SyntheticPlanner.plan(spec: seedSpec(), totalDomains: 3)

        #expect(synthetic.isEmpty)
        #expect(spec.domainNames == ["Identity", "Wallet", "Home"])
    }

    @Test func impossibleSizesAreRejected() throws {
        #expect(throws: SyntheticPlanError.fewerThanSeeds(requested: 2, seeds: 3)) {
            try SyntheticPlanner.plan(spec: seedSpec(), totalDomains: 2)
        }
        #expect(throws: SyntheticPlanError.notEnoughNames(requested: 13, available: 12)) {
            try SyntheticPlanner.plan(spec: seedSpec(), totalDomains: 16)
        }
    }

    @Test func randomSourceIsReproducible() {
        var a = SplitMix64(seed: 42)
        var b = SplitMix64(seed: 42)

        #expect((0..<5).map { _ in a.next() } == (0..<5).map { _ in b.next() })
        #expect((0..<100).allSatisfy { _ in (0.0..<1.0).contains(a.double()) })
    }
}

struct TemplateRendererTests {
    private let renderer = TemplateRenderer(templateRoot: URL(filePath: "/unused"))

    @Test func dependencyLinesRepeatPerDependency() {
        let domain = SyntheticDomain(name: "StreetPermits", title: "Street Permits", dependsOn: ["Wallet", "Identity"])
        let template = """
        import __Domain__API
        import __Dep__API
        let title = "__TITLE__"
        var __dep__: any __Dep__Service
        """

        #expect(renderer.expand(template, for: domain) == """
        import IdentityAPI
        import StreetPermitsAPI
        import WalletAPI
        let title = "Street Permits"
        var wallet: any WalletService
        var identity: any IdentityService
        """)
    }

    @Test func noDependenciesDropsTheLines() {
        let domain = SyntheticDomain(name: "ParkGrants", title: "Park Grants", dependsOn: [])

        #expect(renderer.expand("struct D {\n    var __dep__: Int\n}", for: domain) == "struct D {\n}")
    }

    @Test func importSortingIgnoresTestableAndCase() {
        let lines = ["import b", "@testable import A", "import C", "", "import z", "import y"]

        #expect(TemplateRenderer.sortImportBlocks(lines) == ["@testable import A", "import b", "import C", "", "import y", "import z"])
    }

    @Test func appSourceListsEveryDomainOrNone() {
        let domains = [SyntheticDomain(name: "ParkGrants", title: "Park Grants", dependsOn: ["Identity"])]

        #expect(SyntheticAppSource.render(domains).contains("ParkGrantsFeature.register(in: container)"))
        #expect(SyntheticAppSource.render([]).contains("    static let entries: [Entry] = []\n"))
        #expect(SyntheticAppSource.render([]).contains("    static func register(in container: Container) {}\n"))
    }

    @Test func realTemplateRendersEveryRole() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../../sources/Templates/SyntheticDomain").standardized
        let rendered = try TemplateRenderer(templateRoot: root).render(SyntheticDomain(name: "ParkGrants", title: "Park Grants", dependsOn: ["Identity"]))

        #expect(Set(rendered.keys) == ["Domains/ParkGrants/API", "Domains/ParkGrants/Impl", "Domains/ParkGrants/Resources", "Domains/ParkGrants/Tests"])
        #expect(rendered["Domains/ParkGrants/Resources"]?["parkGrants.json"] != nil)
        let all = rendered.values.flatMap(\.values).map { String(decoding: $0, as: UTF8.self) }.joined()
        #expect(!all.contains("__"))
    }
}
