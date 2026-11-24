import CoreGraphics

/// 메뉴 막대 항목 폭. 단계가 바뀌어도 폭이 흔들리지 않게 가장 긴 문구에 맞추되,
/// 노치가 있는 MacBook에서 항목이 숨지 않도록 문구 폭에 상한을 둔다. 사용률 숫자 폭은 상한 밖에서 더한다.
public enum StatusLayout {
    public static let maxPhraseWidth: CGFloat = 150
    public static let padding: CGFloat = 12

    public static func length(iconWidth: CGFloat, percentWidth: CGFloat = 0, phraseWidths: [CGFloat]) -> CGFloat {
        iconWidth + percentWidth + min(phraseWidths.max() ?? 0, maxPhraseWidth) + padding
    }
}
