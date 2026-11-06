import Darwin
import Testing
@testable import DallyeoraCore

struct ProcessReaderTests {
    @Test func readsOwnProcessesWithNumbersAndOthersWithout() {
        let snap = ProcessReader.snapshot()
        let me = getuid()
        let mine = snap.samples.filter { $0.uid == me }
        let others = snap.samples.filter { $0.uid != me }
        #expect(snap.uptime > 0)
        #expect(mine.contains { $0.pid == getpid() && $0.footprintBytes > 0 && $0.cpuTimeNanos > 0 })
        #expect(!others.isEmpty)
        #expect(others.allSatisfy { $0.footprintBytes == 0 && $0.cpuTimeNanos == 0 })
        #expect(snap.samples.allSatisfy { !$0.name.isEmpty && $0.pid > 0 })
        #expect(snap.samples.contains { $0.pid == 1 && $0.name == "launchd" && $0.path == "/sbin/launchd" })
    }

    @Test func namesComeFromTheLastPathComponent() {
        let snap = ProcessReader.snapshot()
        for s in snap.samples where !s.path.isEmpty {
            #expect(s.path.hasSuffix("/" + s.name), "\(s.pid) \(s.path) \(s.name)")
        }
    }

    @Test func nanosIsMonotonicAndZeroAtZero() {
        #expect(ProcessReader.nanos(0) == 0)
        #expect(ProcessReader.nanos(1_000) <= ProcessReader.nanos(2_000))
        #expect(ProcessReader.nanos(1_000_000) > 0)
    }
}
