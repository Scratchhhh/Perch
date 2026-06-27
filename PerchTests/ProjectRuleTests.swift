import XCTest
@testable import PerchCore

final class ProjectRuleTests: XCTestCase {
    func testDefaultIsPermissive() {
        XCTAssertTrue(ProjectRule.default.bannerEnabled)
        XCTAssertTrue(ProjectRule.default.soundEnabled)
        XCTAssertEqual(ProjectRule.default.volume, 1.0)
    }

    func testVolumeClampsToUnitRange() {
        XCTAssertEqual(ProjectRule(volume: 2.5).volume, 1.0)
        XCTAssertEqual(ProjectRule(volume: -1).volume, 0.0)
    }

    func testCodableRoundTrip() throws {
        let rule = ProjectRule(bannerEnabled: false, soundEnabled: true, volume: 0.4)
        let data = try JSONEncoder().encode(["/a/b": rule])
        let decoded = try JSONDecoder().decode([String: ProjectRule].self, from: data)
        XCTAssertEqual(decoded["/a/b"], rule)
    }
}
