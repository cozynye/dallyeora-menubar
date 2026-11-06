import Testing
@testable import DallyeoraCore

struct PhraseFlashTests {
    @Test func flashesOnlyWhenTheTierChanges() {
        var flash = PhraseFlash()
        #expect(flash.shouldFlash(tier: 0) == false, "켜자마자 대사가 튀어나오지 않는다")
        #expect(flash.shouldFlash(tier: 0) == false)
        #expect(flash.shouldFlash(tier: 2) == true)
        #expect(flash.shouldFlash(tier: 2) == false)
        #expect(flash.shouldFlash(tier: 1) == true)
    }

    @Test func resetForgetsTheLastTier() {
        var flash = PhraseFlash()
        _ = flash.shouldFlash(tier: 3)
        flash.reset()
        #expect(flash.shouldFlash(tier: 0) == false, "캐릭터를 바꾼 직후에는 단계 비교를 다시 시작한다")
    }

    @Test func durationIsThreeSeconds() {
        #expect(PhraseFlash.duration == 3)
    }
}
