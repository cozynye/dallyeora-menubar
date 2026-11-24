import Testing
@testable import DallyeoraCore

struct StatusTitleTests {
    @Test func fourCombinations() {
        #expect(StatusTitle.text(percent: nil, phrase: nil) == "")
        #expect(StatusTitle.text(percent: 42.4, phrase: nil) == " 42%")
        #expect(StatusTitle.text(percent: nil, phrase: "스트레스로 위독") == " 스트레스로 위독")
        #expect(StatusTitle.text(percent: 42.4, phrase: "스트레스로 위독") == " 42% 스트레스로 위독")
    }

    @Test func clampsOddPercents() {
        #expect(StatusTitle.text(percent: .nan, phrase: nil) == " 0%")
        #expect(StatusTitle.text(percent: -5, phrase: nil) == " 0%")
        #expect(StatusTitle.text(percent: 250, phrase: nil) == " 100%")
    }

    @Test func widestPercentIsTheHundred() {
        #expect(StatusTitle.widestPercent == StatusTitle.text(percent: 100, phrase: nil))
    }
}
