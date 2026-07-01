import XCTest
@testable import FitRock

final class StatsEmptyPreviewTests: XCTestCase {
    func testSamplePreviewAvailableWhenNoRealStats() {
        let summary = StatsCalculator().calculate(from: [], period: .week)

        XCTAssertEqual(summary.workoutCount, 0)
        XCTAssertFalse(SamplePreviewData.muscleHeatmapSummary.intensities.isEmpty)
        XCTAssertFalse(SamplePreviewData.exerciseHistory.relatedMuscles.isEmpty)
        XCTAssertEqual(SamplePreviewData.trainingPlan.weeks.count, 4)
    }

    func testRealWorkoutStatsAreNonEmptySoPreviewCanHide() {
        let summary = StatsCalculator().calculate(from: [SamplePreviewData.workout], period: .all)

        XCTAssertGreaterThan(summary.workoutCount, 0)
    }
}
