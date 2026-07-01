import XCTest
@testable import FitRock

final class HealthKitServiceTests: XCTestCase {
    func testMockProviderCanReturnPartialSnapshot() {
        let provider = MockHealthMetricsProvider(snapshot: HealthMetricsSnapshot(
            bodyMassKg: 70,
            averageHeartRate: nil,
            restingHeartRate: 58,
            activeEnergyKcal30d: nil,
            capturedAt: Date()
        ))
        let expectation = expectation(description: "snapshot")

        provider.fetchSnapshot { snapshot in
            XCTAssertEqual(snapshot.bodyMassKg, 70)
            XCTAssertNil(snapshot.averageHeartRate)
            XCTAssertEqual(snapshot.restingHeartRate, 58)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}

private final class MockHealthMetricsProvider: HealthMetricsProviding {
    let snapshot: HealthMetricsSnapshot

    init(snapshot: HealthMetricsSnapshot) {
        self.snapshot = snapshot
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func fetchSnapshot(completion: @escaping (HealthMetricsSnapshot) -> Void) {
        completion(snapshot)
    }
}
