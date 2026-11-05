import Foundation

public enum AnimationClock {
    /// 프레임마다 더하는 phase(rad).
    public static let phaseStep = 0.6

    /// CPU 0% → 0.2초, 100% → 0.03초.
    public static func frameInterval(cpu: Double) -> TimeInterval {
        0.2 - CPUUsage.clamp(cpu) / 100 * 0.17
    }
}
