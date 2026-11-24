import Testing
@testable import DallyeoraCore

struct ActivityStateTests {
    @Test func startsActive() {
        #expect(ActivityState().isActive)
    }

    @Test func sleepPausesAndWakeResumes() {
        var state = ActivityState()
        #expect(state.handle(.screensDidSleep) == true)
        #expect(state.isActive == false)
        #expect(state.handle(.screensDidSleep) == false, "같은 알림이 두 번 와도 한 번만 바뀐다")
        #expect(state.handle(.screensDidWake) == true)
        #expect(state.isActive)
    }

    @Test func staysPausedUntilBothClear() {
        var state = ActivityState()
        _ = state.handle(.sessionDidResignActive)
        #expect(state.handle(.screensDidSleep) == false)
        #expect(state.handle(.screensDidWake) == false, "세션이 아직 비활성이면 깨어나도 멈춰 있다")
        #expect(state.isActive == false)
        #expect(state.handle(.sessionDidBecomeActive) == true)
        #expect(state.isActive)
    }
}
