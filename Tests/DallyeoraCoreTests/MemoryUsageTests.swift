import Testing
@testable import DallyeoraCore

struct MemoryUsageTests {
    @Test func usedIsAppPlusWiredPlusCompressed() {
        // 앱 메모리 = internal - purgeable = 300, 사용 = 300 + 100 + 100 = 500
        let p = MemoryPages(total: 1000, internal: 350, purgeable: 50, wired: 100, compressed: 100)
        #expect(MemoryUsage.percent(p) == 50)
    }

    @Test func zeroTotalIsZero() {
        let p = MemoryPages(total: 0, internal: 10, purgeable: 0, wired: 0, compressed: 0)
        #expect(MemoryUsage.percent(p) == 0)
    }

    @Test func purgeableLargerThanInternalDoesNotUnderflow() {
        let p = MemoryPages(total: 1000, internal: 10, purgeable: 50, wired: 200, compressed: 0)
        #expect(MemoryUsage.percent(p) == 20)
    }

    @Test func overTotalIsClamped() {
        let p = MemoryPages(total: 100, internal: 100, purgeable: 0, wired: 100, compressed: 0)
        #expect(MemoryUsage.percent(p) == 100)
    }

    @Test func readsLivePages() {
        let p = MemoryPages.current()
        #expect(p != nil)
        let percent = p.map(MemoryUsage.percent) ?? 0
        #expect(percent > 0 && percent <= 100)
    }
}
