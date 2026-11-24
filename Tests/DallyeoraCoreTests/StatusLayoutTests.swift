import CoreGraphics
import Testing
@testable import DallyeoraCore

struct StatusLayoutTests {
    @Test func fitsWidestPhrase() {
        #expect(StatusLayout.length(iconWidth: 28, phraseWidths: [80, 120]) == 28 + 120 + StatusLayout.padding)
    }

    @Test func capsLongPhrases() {
        #expect(StatusLayout.length(iconWidth: 28, phraseWidths: [80, 300]) == 28 + StatusLayout.maxPhraseWidth + StatusLayout.padding)
    }

    @Test func iconOnlyWhenNoPhrases() {
        #expect(StatusLayout.length(iconWidth: 28, phraseWidths: []) == 28 + StatusLayout.padding)
    }

    @Test func addsPercentWidthOutsideThePhraseCap() {
        #expect(StatusLayout.length(iconWidth: 28, percentWidth: 34, phraseWidths: [300])
            == 28 + 34 + StatusLayout.maxPhraseWidth + StatusLayout.padding)
        #expect(StatusLayout.length(iconWidth: 28, percentWidth: 34, phraseWidths: []) == 28 + 34 + StatusLayout.padding)
    }
}
