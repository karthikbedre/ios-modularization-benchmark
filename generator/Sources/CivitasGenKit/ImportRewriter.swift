/// Canonical sources are written for the api-impl topology and import `<Domain>API` modules.
/// In the tree topology a domain's API and implementation share one module, so those imports
/// point at the domain module instead, and a domain's import of its own API disappears.
public struct ImportRewriter: Sendable {
    public var domains: Set<String>

    public init(domains: Set<String>) {
        self.domains = domains
    }

    public func rewriteForTree(_ source: String, owningDomain: String?) -> String {
        var seenImports: Set<String> = []
        var lines: [String] = []
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let match = line.wholeMatch(of: /(\s*(?:@testable\s+)?)import\s+(\w+)\s*/) else {
                lines.append(String(line))
                continue
            }
            var module = String(match.output.2)
            if module.hasSuffix("API"), domains.contains(String(module.dropLast(3))) {
                module = String(module.dropLast(3))
                if module == owningDomain { continue }
            }
            let rewritten = "\(match.output.1)import \(module)"
            if seenImports.insert(rewritten).inserted {
                lines.append(rewritten)
            }
        }
        return lines.joined(separator: "\n")
    }
}
