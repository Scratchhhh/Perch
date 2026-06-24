import XCTest
@testable import PerchCore

/// Exercises the exact filesystem dance the integrations perform: back up, install, then
/// uninstall, against a real (temporary) settings.json.
final class ConfigRoundTripTests: XCTestCase {
    private var directory = URL(fileURLWithPath: "/tmp")
    private let events = ClaudeHookEvent.allCases.map(\.rawValue)
    private let command = "\"/Applications/Perch.app/Contents/Helpers/perch-helper\" hook"

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("perch-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testInstallBacksUpAndUninstallRestores() throws {
        let settings = directory.appendingPathComponent("settings.json")
        let original = Data(#"{"theme":"dark","includeCoAuthoredBy":false}"#.utf8)
        try original.write(to: settings)

        // Install: back up, transform, write.
        let installBackup = try XCTUnwrap(try ConfigBackup.backup(settings))
        let installed = try ClaudeSettingsEditor.install(into: try Data(contentsOf: settings), command: command, events: events)
        try installed.write(to: settings)

        XCTAssertEqual(try Data(contentsOf: installBackup), original, "backup must hold the pre-edit bytes")
        XCTAssertEqual(ClaudeSettingsEditor.status(of: try Data(contentsOf: settings), events: events), .installed)

        let installedRoot = try JSONSerialization.jsonObject(with: try Data(contentsOf: settings)) as? [String: Any]
        XCTAssertEqual(installedRoot?["theme"] as? String, "dark")

        // Uninstall: back up again, strip, write.
        _ = try ConfigBackup.backup(settings)
        let removed = try ClaudeSettingsEditor.remove(from: try Data(contentsOf: settings))
        try removed.write(to: settings)

        let finalRoot = try XCTUnwrap(try JSONSerialization.jsonObject(with: try Data(contentsOf: settings)) as? [String: Any])
        XCTAssertNil(finalRoot["hooks"], "no Perch hooks should remain")
        XCTAssertEqual(finalRoot["theme"] as? String, "dark")
        XCTAssertEqual(finalRoot["includeCoAuthoredBy"] as? Bool, false)
    }

    func testBackupReturnsNilWhenMissing() throws {
        let missing = directory.appendingPathComponent("does-not-exist.json")
        XCTAssertNil(try ConfigBackup.backup(missing))
    }
}
