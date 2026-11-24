/// 메뉴 막대 아이콘 옆 글자. 사용률과 대사를 각각 붙이거나 뺀다.
public enum StatusTitle {
    /// 폭을 고정할 때 기준으로 삼는 가장 긴 숫자.
    public static let widestPercent = " 100%"

    public static func text(percent: Double?, phrase: String?) -> String {
        var text = ""
        if let percent { text += " " + UsageFormat.percent(percent) }
        if let phrase { text += " " + phrase }
        return text
    }
}
