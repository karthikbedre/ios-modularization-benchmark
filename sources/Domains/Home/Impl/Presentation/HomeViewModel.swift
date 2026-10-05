import CoreKit
import HomeAPI
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var state: LoadState<Dashboard> = .idle
    private let service: any HomeService

    init(service: any HomeService) {
        self.service = service
    }

    /// Keeps showing the previous dashboard while a refresh is in flight.
    func load() async {
        if state.value == nil { state = .loading }
        state = .loaded(await service.dashboard())
    }
}
