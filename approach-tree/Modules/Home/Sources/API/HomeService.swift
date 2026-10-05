import CoreModels

public protocol HomeService: SummaryProviding {
    func dashboard() async -> Dashboard
}
