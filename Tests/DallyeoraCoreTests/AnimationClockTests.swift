import Testing
@testable import DallyeoraCore

struct AnimationClockTests {
    @Test(arguments: [(0.0, 0.2), (100.0, 0.03), (50.0, 0.115), (-10.0, 0.2), (150.0, 0.03), (.nan, 0.2)])
    func frameIntervalShrinksWithUsage(usage: Double, expected: Double) {
        #expect(abs(AnimationClock.frameInterval(usage: usage) - expected) < 1e-9)
    }
}
