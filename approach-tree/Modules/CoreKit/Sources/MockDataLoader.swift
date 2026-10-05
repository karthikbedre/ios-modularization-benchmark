import Foundation

public enum MockDataError: Error, Equatable {
    case missingResource(String)
}

/// Loads bundled JSON fixtures the way a network client would return responses.
public struct MockDataLoader: Sendable {
    public var latency: Latency

    public init(latency: Latency = .standard) {
        self.latency = latency
    }

    public func load<Value: Decodable>(_ type: Value.Type, resource: String, in bundle: Bundle) async throws -> Value {
        await latency.wait()
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw MockDataError.missingResource(resource)
        }
        return try JSONDecoder.civitas.decode(Value.self, from: Data(contentsOf: url))
    }
}

extension JSONDecoder {
    public static var civitas: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
