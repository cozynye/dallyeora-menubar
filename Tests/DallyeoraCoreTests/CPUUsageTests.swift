import Testing
@testable import DallyeoraCore

struct CPUUsageTests {
    @Test func computesBusyShareOfDelta() {
        let a = CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        let b = CPUTicks(user: 130, system: 60, idle: 850, nice: 60)
        // busy Δ = 30 + 10 + 10 = 50, total Δ = 50 + 50 = 100
        #expect(CPUUsage.percent(from: a, to: b) == 50)
    }

    @Test func allBusyIsHundred() {
        let a = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let b = CPUTicks(user: 50, system: 50, idle: 0, nice: 0)
        #expect(CPUUsage.percent(from: a, to: b) == 100)
    }

    @Test func noChangeIsZero() {
        let a = CPUTicks(user: 10, system: 10, idle: 10, nice: 10)
        #expect(CPUUsage.percent(from: a, to: a) == 0)
    }

    @Test func counterWrapIsZero() {
        let a = CPUTicks(user: 4_000_000_000, system: 0, idle: 0, nice: 0)
        let b = CPUTicks(user: 10, system: 0, idle: 20, nice: 0)
        #expect(CPUUsage.percent(from: a, to: b) == 0)
    }

    @Test(arguments: [(-5.0, 0.0), (150.0, 100.0), (.nan, 0.0), (.infinity, 0.0), (42.0, 42.0)])
    func clampKeepsRange(input: Double, expected: Double) {
        #expect(CPUUsage.clamp(input) == expected)
    }

    @Test func readsLiveTicks() {
        let ticks = CPUTicks.current()
        #expect(ticks != nil)
        #expect((ticks?.total ?? 0) > 0)
    }
}
