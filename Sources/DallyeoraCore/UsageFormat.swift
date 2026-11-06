import Foundation

public enum UsageFormat {
    /// 1024 기준. GB는 소수 한 자리, MB와 KB는 정수, 1 KB 미만은 B.
    public static func bytes(_ value: UInt64) -> String {
        let kb = 1024.0, mb = kb * 1024, gb = mb * 1024
        let v = Double(value)
        if v >= gb { return String(format: "%.1f GB", v / gb) }
        if v >= mb { return String(format: "%.0f MB", v / mb) }
        if v >= kb { return String(format: "%.0f KB", v / kb) }
        return "\(value) B"
    }

    public static func percent(_ value: Double) -> String {
        "\(Int(Usage.clamp(value).rounded()))%"
    }
}
