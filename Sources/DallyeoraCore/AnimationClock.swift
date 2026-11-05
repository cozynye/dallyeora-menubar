import Foundation

public enum AnimationClock {
    /// 프레임마다 더하는 phase(rad).
    public static let phaseStep = 0.6

    /// 사용률 0% → 0.2초, 100% → 0.03초.
    public static func frameInterval(usage: Double) -> TimeInterval {
        0.2 - Usage.clamp(usage) / 100 * 0.17
    }
}
