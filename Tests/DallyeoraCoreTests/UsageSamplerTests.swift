import Testing
@testable import DallyeoraCore

struct UsageSamplerTests {
    @Test func cpuNeedsTwoReadings() {
        var ticks = [
            CPUTicks(user: 0, system: 0, idle: 0, nice: 0),
            CPUTicks(user: 30, system: 0, idle: 70, nice: 0),
        ]
        var sampler = UsageSampler(readCPU: { ticks.removeFirst() }, readMemory: { nil })
        sampler.sample()
        #expect(sampler.value(for: .cpu) == 0)
        sampler.sample()
        #expect(sampler.value(for: .cpu) == 30)
    }

    @Test func memoryIsReadEverySample() {
        let pages = MemoryPages(total: 100, internal: 40, purgeable: 0, wired: 0, compressed: 0)
        var sampler = UsageSampler(readCPU: { nil }, readMemory: { pages })
        sampler.sample()
        #expect(sampler.value(for: .memory) == 40)
    }

    @Test func failedReadKeepsPreviousValue() {
        var pages: MemoryPages? = MemoryPages(total: 100, internal: 40, purgeable: 0, wired: 0, compressed: 0)
        var sampler = UsageSampler(readCPU: { nil }, readMemory: { pages })
        sampler.sample()
        pages = nil
        sampler.sample()
        #expect(sampler.value(for: .memory) == 40)
    }
}
