import Foundation
import Testing
@testable import DallyeoraCore

struct ProcessGrouperTests {
    static let chrome = "/Applications/Google Chrome.app"
    static let chromeHelper = chrome + "/Contents/Frameworks/Google Chrome Framework.framework/Versions/1/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"
    static let cursor = "/Applications/Cursor.app"
    static let terminal = "/System/Applications/Utilities/Terminal.app"

    func s(_ pid: pid_t, _ ppid: pid_t, _ path: String, uid: uid_t = 501, mem: UInt64 = 0, cpu: UInt64 = 0) -> ProcessSample {
        ProcessSample(pid: pid, ppid: ppid, uid: uid, name: (path as NSString).lastPathComponent, path: path,
                      footprintBytes: mem, cpuTimeNanos: cpu)
    }

    func group(_ samples: [ProcessSample], selfPID: pid_t = 999) -> [ProcessGroup] {
        ProcessGrouper.group(ProcessSnapshot(uptime: 1, samples: samples), currentUID: 501, selfPID: selfPID)
    }

    @Test func findsOutermostAppBundle() {
        #expect(ProcessGrouper.appBundlePath(of: Self.chromeHelper) == Self.chrome)
        #expect(ProcessGrouper.appBundlePath(of: "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder") == "/System/Library/CoreServices/Finder.app")
        #expect(ProcessGrouper.appBundlePath(of: "/opt/homebrew/bin/node") == nil)
        #expect(ProcessGrouper.appBundlePath(of: "") == nil)
    }

    @Test func helpersGroupUnderTheirApp() {
        let groups = group([
            s(10, 1, Self.chrome + "/Contents/MacOS/Google Chrome", mem: 100, cpu: 5),
            s(11, 10, Self.chromeHelper, mem: 50, cpu: 1),
            s(12, 10, Self.chromeHelper, mem: 50, cpu: 1),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].id == Self.chrome)
        #expect(groups[0].kind == .app(bundlePath: Self.chrome, mainPID: 10))
        #expect(groups[0].pids == [10, 11, 12])
        #expect(groups[0].footprintBytes == 200)
        #expect(groups[0].cpuTimeNanos == 7)
    }

    @Test func orphanPathFollowsParentChainToApp() {
        let groups = group([
            s(20, 1, Self.cursor + "/Contents/MacOS/Cursor"),
            s(21, 20, Self.cursor + "/Contents/Frameworks/Cursor Helper (Plugin).app/Contents/MacOS/Cursor Helper (Plugin)"),
            s(22, 21, "/opt/homebrew/bin/node", mem: 300),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].pids == [20, 21, 22])
        #expect(groups[0].footprintBytes == 300)
    }

    @Test func chainPassesThroughRootOwnedAncestor() {
        // 터미널 → login(root) → zsh → python
        let groups = group([
            s(30, 1, Self.terminal + "/Contents/MacOS/Terminal"),
            s(31, 30, "/usr/bin/login", uid: 0),
            s(32, 31, "/bin/zsh"),
            s(33, 32, "/usr/bin/python3", mem: 10),
        ])
        let terminal = groups.first { $0.id == Self.terminal }
        #expect(terminal?.pids == [30, 32, 33])
        #expect(groups.last?.kind == .system(count: 1))
    }

    @Test func processesWithoutAppGroupByName() {
        let groups = group([
            s(40, 1, "/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores", mem: 1),
            s(41, 1, "/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores", mem: 2),
            s(42, 1, "/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores", mem: 3),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].id == "name:mds_stores")
        #expect(groups[0].kind == .background(name: "mds_stores"))
        #expect(groups[0].footprintBytes == 6)
    }

    @Test func otherUsersCollapseIntoOneSystemGroupAtTheEnd() {
        let groups = group([
            s(50, 1, "/usr/libexec/opendirectoryd", uid: 0, mem: 999),
            s(51, 1, "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer", uid: 88),
            s(52, 1, "/usr/bin/foo"),
        ])
        #expect(groups.count == 2)
        #expect(groups.last?.id == ProcessGrouper.systemID)
        #expect(groups.last?.kind == .system(count: 2))
        #expect(groups.last?.pids.isEmpty == true)
        #expect(groups.last?.footprintBytes == 0)
    }

    @Test func selfIsExcluded() {
        let groups = group([s(60, 1, "/usr/bin/foo"), s(61, 1, "/usr/bin/bar")], selfPID: 60)
        #expect(groups.map(\.id) == ["name:bar"])
    }

    @Test func parentCycleStops() {
        let groups = group([s(70, 71, "/usr/bin/a"), s(71, 70, "/usr/bin/b")])
        #expect(groups.map(\.id) == ["name:a", "name:b"])
    }

    @Test func mainPIDFallsBackToSmallestPID() {
        let groups = group([s(81, 1, Self.chromeHelper), s(80, 1, Self.chromeHelper)])
        #expect(groups[0].kind == .app(bundlePath: Self.chrome, mainPID: 80))
    }
}
