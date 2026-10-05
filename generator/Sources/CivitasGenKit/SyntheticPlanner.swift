import Foundation

public struct SyntheticConfig: Decodable, Sendable {
    public var seed: UInt64
    /// Chance that a synthetic domain depends on Identity, since most city services are per resident.
    public var identityProbability: Double
    public var minDependencies: Int
    public var maxDependencies: Int
    /// Preferential attachment strength. Dependency choices are weighted by (1 + dependents) ^ hubBias.
    public var hubBias: Double
    /// Domains synthetic ones never depend on, such as aggregators.
    public var excluded: [String]
    public var prefixes: [String]
    public var suffixes: [String]
}

public struct SyntheticDomain: Equatable, Sendable {
    public var name: String
    public var title: String
    public var dependsOn: [String]

    public var valueName: String {
        name.prefix(1).lowercased() + name.dropFirst()
    }
}

public enum SyntheticPlanError: Error, Equatable, CustomStringConvertible {
    case fewerThanSeeds(requested: Int, seeds: Int)
    case notEnoughNames(requested: Int, available: Int)
    case missingConfig

    public var description: String {
        switch self {
        case .fewerThanSeeds(let requested, let seeds): "requested \(requested) domains but the spec already has \(seeds) seeds"
        case .notEnoughNames(let requested, let available): "need \(requested) synthetic names, only \(available) prefix and suffix combinations"
        case .missingConfig: "spec has no synthetic section"
        }
    }
}

/// Grows the seed graph to `totalDomains` with template-based domains. Same spec and seed, same graph.
public enum SyntheticPlanner {
    public static func plan(spec: Spec, totalDomains: Int) throws -> (spec: Spec, synthetic: [SyntheticDomain]) {
        let seeds = spec.domains.count
        guard totalDomains >= seeds else { throw SyntheticPlanError.fewerThanSeeds(requested: totalDomains, seeds: seeds) }
        guard totalDomains > seeds else { return (spec, []) }
        guard let config = spec.synthetic else { throw SyntheticPlanError.missingConfig }

        var rng = SplitMix64(seed: config.seed)
        let count = totalDomains - seeds
        let taken = Set(spec.domainNames)
        var names = config.prefixes.flatMap { prefix in config.suffixes.map { (prefix + $0, "\(prefix) \(splitWords($0))") } }
            .filter { !taken.contains($0.0) }
        guard names.count >= count else { throw SyntheticPlanError.notEnoughNames(requested: count, available: names.count) }
        rng.shuffle(&names)

        var pool = spec.domainNames.filter { !config.excluded.contains($0) }
        var dependents = Dictionary(uniqueKeysWithValues: pool.map { ($0, 0) })
        for domain in spec.domains {
            for dependency in domain.dependsOn where dependents[dependency] != nil {
                dependents[dependency, default: 0] += 1
            }
        }

        var synthetic: [SyntheticDomain] = []
        for (name, title) in names.prefix(count) {
            let target = rng.int(in: config.minDependencies...config.maxDependencies)
            var chosen: [String] = []
            if pool.contains("Identity"), rng.double() < config.identityProbability {
                chosen.append("Identity")
            }
            while chosen.count < target {
                let candidates = pool.filter { !chosen.contains($0) }
                guard !candidates.isEmpty else { break }
                let weights = candidates.map { pow(1 + Double(dependents[$0] ?? 0), config.hubBias) }
                chosen.append(candidates[rng.weightedIndex(weights)])
            }
            for dependency in chosen {
                dependents[dependency, default: 0] += 1
            }
            synthetic.append(SyntheticDomain(name: name, title: title, dependsOn: chosen))
            pool.append(name)
            dependents[name] = 0
        }

        var grown = spec
        grown.domains += synthetic.map { Spec.Module(name: $0.name, dependsOn: $0.dependsOn) }
        return (grown, synthetic)
    }

    private static func splitWords(_ name: String) -> String {
        name.reduce(into: "") { result, character in
            if character.isUppercase, !result.isEmpty { result.append(" ") }
            result.append(character)
        }
    }
}

/// Small, fast, deterministic generator, so a plan never depends on the platform's random source.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func double() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    mutating func weightedIndex(_ weights: [Double]) -> Int {
        var remaining = double() * weights.reduce(0, +)
        for (index, weight) in weights.enumerated() {
            remaining -= weight
            if remaining < 0 { return index }
        }
        return weights.count - 1
    }

    mutating func shuffle<T>(_ array: inout [T]) {
        guard array.count > 1 else { return }
        for index in stride(from: array.count - 1, to: 0, by: -1) {
            array.swapAt(index, Int(next() % UInt64(index + 1)))
        }
    }
}
