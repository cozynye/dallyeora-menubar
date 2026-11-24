import Foundation

/// 메뉴 막대 대사를 숨겨 둘 때, 단계가 바뀌는 순간에만 잠깐 보여 주기 위한 판단.
/// 켜자마자나 캐릭터를 바꾼 직후는 비교할 직전 단계가 없어 보여 주지 않는다.
public struct PhraseFlash: Sendable {
    /// 대사가 붙어 있는 시간(초).
    public static let duration: TimeInterval = 3

    private var lastTier: Int?
    /// 단계가 바뀌어 대사를 잠깐 보여 주는 중. `expire`나 `reset`으로 끝난다.
    public private(set) var isFlashing = false

    public init() {}

    /// 단계를 기록하고, 직전 단계와 달라 대사를 띄워야 하면 true. 이때부터 `isFlashing`이다.
    /// 대사를 늘 켜 둔 동안(`pinned`)에는 띄울 것이 없어 기록만 한다.
    public mutating func shouldFlash(tier: Int, pinned: Bool = false) -> Bool {
        defer { lastTier = tier }
        guard let last = lastTier, tier != last, !pinned else { return false }
        isFlashing = true
        return true
    }

    /// `duration`이 지났을 때.
    public mutating func expire() {
        isFlashing = false
    }

    public mutating func reset() {
        lastTier = nil
        isFlashing = false
    }
}
