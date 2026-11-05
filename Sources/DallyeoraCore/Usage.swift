/// CPU·메모리 공통 사용률(0–100) 처리.
public enum Usage {
    /// NaN·무한대는 0, 나머지는 0–100으로 제한.
    public static func clamp(_ value: Double) -> Double {
        value.isFinite ? min(100, max(0, value)) : 0
    }
}
