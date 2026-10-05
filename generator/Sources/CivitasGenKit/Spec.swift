import Foundation
import Yams

public struct Spec: Decodable, Sendable {
    public struct Module: Decodable, Sendable {
        public var name: String
        public var dependsOn: [String]

        public init(name: String, dependsOn: [String]) {
            self.name = name
            self.dependsOn = dependsOn
        }
    }

    public var app: String
    public var bundleIdPrefix: String
    public var deploymentTarget: String
    public var swiftVersion: String
    public var core: [Module]
    public var appCore: [String]
    public var apiCore: [String]
    public var domainCore: [String]
    public var domains: [Module]
    public var synthetic: SyntheticConfig?

    public var domainNames: [String] { domains.map(\.name) }

    public static func decode(_ yaml: String) throws -> Spec {
        try YAMLDecoder().decode(Spec.self, from: yaml)
    }

    public static func load(from url: URL) throws -> Spec {
        try decode(String(contentsOf: url, encoding: .utf8))
    }
}
