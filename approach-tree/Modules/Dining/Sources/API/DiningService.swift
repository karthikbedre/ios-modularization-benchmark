import CoreModels
import SwiftUI

public protocol DiningService: SummaryProviding {
    func restaurants(matching filter: DiningFilter) async throws -> [Restaurant]
    func restaurant(id: String) async throws -> Restaurant
    func menu(restaurantID: String) async throws -> [MenuSection]
    func search(_ text: String) async throws -> [Restaurant]
}

public struct DiningEntryPoints: Sendable {
    public var detail: @MainActor @Sendable (_ restaurantID: String) -> AnyView

    public init(detail: @escaping @MainActor @Sendable (_ restaurantID: String) -> AnyView) {
        self.detail = detail
    }
}
