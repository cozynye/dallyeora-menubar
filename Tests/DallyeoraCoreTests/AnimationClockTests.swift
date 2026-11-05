import Testing
@testable import DallyeoraCore

struct AnimationClockTests {
    @Test(arguments: [(0.0, 0.2), (100.0, 0.03), (50.0, 0.115), (-10.0, 0.2), (150.0, 0.03), (.nan, 0.2)])
    func frameIntervalShrinksWithCPU(cpu: Double, expected: Double) {
        #expect(abs(AnimationClock.frameInterval(cpu: cpu) - expected) < 1e-9)
    }
}
