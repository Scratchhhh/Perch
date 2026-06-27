import XCTest
@testable import PerchCore

final class TurnEstimatorTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func times(_ offsets: [TimeInterval]) -> [Date] {
        offsets.map { t0.addingTimeInterval($0) }
    }

    func testMedianOddCount() {
        XCTAssertEqual(TurnEstimator.median([30, 10, 20]), 20)
    }

    func testMedianEvenCountAverages() {
        XCTAssertEqual(TurnEstimator.median([10, 20, 30, 40]), 25)
    }

    func testPercentile() {
        let values: [TimeInterval] = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
        XCTAssertEqual(TurnEstimator.percentile(0.95, values), 100)
        XCTAssertEqual(TurnEstimator.percentile(0.5, values), 50)
    }

    func testPositiveGapsDropsDuplicatesAndSorts() {
        // Out-of-order with a duplicate timestamp.
        let gaps = TurnEstimator.positiveGaps(times([0, 100, 100, 250]))
        XCTAssertEqual(gaps, [100, 150])
    }

    func testTurnStatsNeedsEnoughSamples() {
        // Only 2 gaps from 3 events — below the default minimum of 3.
        XCTAssertNil(TurnEstimator.turnStats(eventTimes: times([0, 60, 120])))
    }

    func testTurnStatsComputesMedianAndP95() {
        // Gaps: 60, 60, 60, 600 → median 60, p95 600.
        let stats = TurnEstimator.turnStats(eventTimes: times([0, 60, 120, 180, 780]))
        XCTAssertEqual(stats?.sampleCount, 4)
        XCTAssertEqual(stats?.median, 60)
        XCTAssertEqual(stats?.p95, 600)
    }
}

final class StuckPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    func testThresholdUsesFloorWithoutStats() {
        XCTAssertEqual(StuckPolicy.threshold(turnStats: nil), StuckPolicy.floorThreshold)
    }

    func testThresholdScalesWithP95() {
        let stats = TurnStats(sampleCount: 5, median: 60, p95: 600)
        // 600 * 1.5 = 900, above the 300s floor.
        XCTAssertEqual(StuckPolicy.threshold(turnStats: stats), 900)
    }

    func testThresholdNeverBelowFloor() {
        let quick = TurnStats(sampleCount: 5, median: 5, p95: 20)
        XCTAssertEqual(StuckPolicy.threshold(turnStats: quick), StuckPolicy.floorThreshold)
    }

    func testIsStuck() {
        let threshold: TimeInterval = 300
        XCTAssertTrue(StuckPolicy.isStuck(workingSince: now.addingTimeInterval(-400), now: now, threshold: threshold))
        XCTAssertFalse(StuckPolicy.isStuck(workingSince: now.addingTimeInterval(-100), now: now, threshold: threshold))
    }
}
