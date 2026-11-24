/// 마우스가 목록 위에 있는 동안 줄이 움직이지 않게 순서를 붙잡는다.
public enum StableOrder {
    /// `frozen`에 있던 것은 그 순서대로 두고, 새로 생긴 것은 `ranked` 순서로 뒤에 붙인다. 사라진 것은 뺀다.
    public static func arrange<ID: Hashable>(_ ranked: [ID], keeping frozen: [ID]?) -> [ID] {
        guard let frozen else { return ranked }
        let live = Set(ranked)
        let kept = frozen.filter(live.contains)
        let keptSet = Set(kept)
        return kept + ranked.filter { !keptSet.contains($0) }
    }
}
