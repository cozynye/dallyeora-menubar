/// 캐릭터가 반응할 지표.
public enum Metric: String, CaseIterable, Sendable {
    case cpu
    case memory

    public var label: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "메모리"
        }
    }
}
