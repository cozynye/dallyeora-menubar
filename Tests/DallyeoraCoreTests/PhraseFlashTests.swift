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

    @Test func staysFlashingUntilItExpires() {
        var flash = PhraseFlash()
        #expect(flash.isFlashing == false)
        _ = flash.shouldFlash(tier: 0)
        _ = flash.shouldFlash(tier: 1)
        #expect(flash.isFlashing)
        #expect(flash.shouldFlash(tier: 1) == false)
        #expect(flash.isFlashing, "같은 단계가 이어져도 시간이 끝날 때까지 보인다")
        flash.expire()
        #expect(flash.isFlashing == false)
    }

    @Test func resetAlsoEndsTheFlash() {
        var flash = PhraseFlash()
        _ = flash.shouldFlash(tier: 0)
        _ = flash.shouldFlash(tier: 1)
        flash.reset()
        #expect(flash.isFlashing == false, "캐릭터를 바꾸면 띄워 둔 대사도 내린다")
    }

    @Test func pinnedPhraseRecordsTheTierWithoutFlashing() {
        var flash = PhraseFlash()
        _ = flash.shouldFlash(tier: 0, pinned: true)
        #expect(flash.shouldFlash(tier: 1, pinned: true) == false, "대사를 늘 켜 두면 따로 띄울 것이 없다")
        #expect(flash.isFlashing == false)
        #expect(flash.shouldFlash(tier: 1) == false, "켜 둔 동안 바뀐 단계는 이미 기록돼 있다")
    }
}
