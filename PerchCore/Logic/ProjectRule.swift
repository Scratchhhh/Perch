import Foundation

/// Per-project notification delivery rule. `bannerEnabled` is the master switch: off silences the
/// project entirely. With banners on, `soundEnabled` and `volume` tune the audio. Persisted as JSON
/// in preferences, keyed by absolute project path.
public struct ProjectRule: Codable, Sendable, Equatable {
    public var bannerEnabled: Bool
    public var soundEnabled: Bool
    /// 0.0…1.0, applied to the played cue.
    public var volume: Double

    public static let `default` = ProjectRule(bannerEnabled: true, soundEnabled: true, volume: 1.0)

    public init(bannerEnabled: Bool = true, soundEnabled: Bool = true, volume: Double = 1.0) {
        self.bannerEnabled = bannerEnabled
        self.soundEnabled = soundEnabled
        self.volume = max(0, min(1, volume))
    }
}
