import Foundation

final class ConnectorClient {
    func fetchSnapshot(for scenario: DemoScenario) async throws -> AppSnapshot {
        try await Task.sleep(for: .milliseconds(650))

        switch scenario {
        case .normal:
            return MockData.normalSnapshot
        case .empty:
            return MockData.emptySnapshot
        case .error:
            throw URLError(.cannotConnectToHost)
        }
    }
}
