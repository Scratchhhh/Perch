import XCTest
@testable import PerchCore

final class AttentionPolicyTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 10_000)

    func testActiveWhenUnseenAndRecent() {
        XCTAssertTrue(AttentionPolicy.isActive(unseenCount: 1, lastAttentionAt: base, now: base.addingTimeInterval(5), ttl: 20))
    }

    func testInactiveWhenNoUnseen() {
        XCTAssertFalse(AttentionPolicy.isActive(unseenCount: 0, lastAttentionAt: base, now: base.addingTimeInterval(1), ttl: 20))
    }

    func testSettlesAfterTTL() {
        XCTAssertFalse(AttentionPolicy.isActive(unseenCount: 2, lastAttentionAt: base, now: base.addingTimeInterval(21), ttl: 20))
        XCTAssertTrue(AttentionPolicy.isActive(unseenCount: 2, lastAttentionAt: base, now: base.addingTimeInterval(19.5), ttl: 20))
    }

    func testInactiveWithoutAttentionTimestamp() {
        XCTAssertFalse(AttentionPolicy.isActive(unseenCount: 3, lastAttentionAt: nil, now: base, ttl: 20))
    }
}

final class ClaudeHookMappingTests: XCTestCase {
    func testPermissionRequestMapsToPermission() {
        XCTAssertEqual(EventKind.fromClaudeHookEvent("PermissionRequest"), .permission)
        XCTAssertTrue(EventKind.fromClaudeHookEvent("PermissionRequest").demandsAttention)
    }

    func testKnownEventsMap() {
        XCTAssertEqual(EventKind.fromClaudeHookEvent("Stop"), .finished)
        XCTAssertEqual(EventKind.fromClaudeHookEvent("SubagentStop"), .subagentDone)
        XCTAssertEqual(EventKind.fromClaudeHookEvent("Notification"), .needsInput)
        XCTAssertEqual(EventKind.fromClaudeHookEvent("Whatever"), .finished)
    }

    func testPermissionRequestIsInstalled() {
        XCTAssertTrue(ClaudeHookEvent.allCases.map(\.rawValue).contains("PermissionRequest"))
    }
}
