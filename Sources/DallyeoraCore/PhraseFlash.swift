import Foundation

/// 메뉴 막대 대사를 숨겨 둘 때, 단계가 바뀌는 순간에만 잠깐 보여 주기 위한 판단.
/// 켜자마자나 캐릭터를 바꾼 직후는 비교할 직전 단계가 없어 보여 주지 않는다.
public struct PhraseFlash: Sendable {
    /// 대사가 붙어 있는 시간(초).
    public static let duration: TimeInterval = 3

    private var lastTier: Int?

    public init() {}

    /// 단계를 기록하고, 직전 단계와 다르면 true.
    public mutating func shouldFlash(tier: Int) -> Bool {
        defer { lastTier = tier }
        guard let last = lastTier else { return false }
        return tier != last
    }

    public mutating func reset() {
        lastTier = nil
    }
}
