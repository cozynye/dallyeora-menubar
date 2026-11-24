import Darwin
import Testing
@testable import DallyeoraCore

struct RowFilterTests {
    @Test func emptyQueryMatchesEverything() {
        #expect(RowFilter.matches(query: "", in: ["Slack"]))
        #expect(RowFilter.matches(query: "   ", in: []))
    }

    @Test func ignoresCaseAndSurroundingSpace() {
        #expect(RowFilter.matches(query: "  chro ", in: ["Google Chrome", "웹 브라우저"]))
        #expect(RowFilter.matches(query: "브라우저", in: ["Google Chrome", "웹 브라우저"]))
        #expect(RowFilter.matches(query: "slack", in: ["Google Chrome", "웹 브라우저"]) == false)
    }

    @Test func matchesMemberNames() {
        #expect(RowFilter.matches(query: "renderer", in: ["Google Chrome", "웹 브라우저", "Google Chrome Helper (Renderer)"]))
    }

    @Test func matchesDecomposedHangul() {
        let decomposed = "카카오".decomposedStringWithCanonicalMapping
        #expect(decomposed.unicodeScalars.count > 3)
        #expect(RowFilter.matches(query: decomposed, in: ["카카오톡"]))
    }
}

struct StableOrderTests {
    @Test func noFrozenOrderMeansRankedOrder() {
        #expect(StableOrder.arrange(["b", "a", "c"], keeping: nil) == ["b", "a", "c"])
    }

    @Test func keepsFrozenOrderAndAppendsNew() {
        let frozen = ["a", "b", "c"]
        #expect(StableOrder.arrange(["c", "b", "a"], keeping: frozen) == ["a", "b", "c"])
        #expect(StableOrder.arrange(["x", "c", "a", "y"], keeping: frozen) == ["a", "c", "x", "y"],
                "사라진 b는 빠지고 새 줄은 사용량 순으로 아래에 붙는다")
    }

    @Test func worksForPIDs() {
        #expect(StableOrder.arrange([Int32(30), 10, 20], keeping: [10, 20]) == [10, 20, 30])
    }
}

struct CleanupNoticeTests {
    @Test func appTexts() {
        #expect(CleanupNotice.quit(app: "Slack").text == "종료했습니다: Slack")
        #expect(CleanupNotice.quitNotSent(app: "Slack").text == "종료 요청을 보내지 못했습니다: Slack")
        #expect(CleanupNotice.unresponsive(app: "Slack").text == "응답이 없어 강제 종료 버튼으로 바꿨습니다: Slack")
        #expect(CleanupNotice.forceQuit(app: "Slack").text == "강제 종료했습니다: Slack")
        #expect(CleanupNotice.forceQuitFailed(app: "Slack").text == "강제 종료하지 못했습니다: Slack")
    }

    @Test func processTexts() {
        #expect(CleanupNotice.processEnded(name: "node", pid: 12).text == "종료했습니다: node (pid 12)")
        #expect(CleanupNotice.processStillRunning(name: "node", pid: 12).text == "종료를 요청했지만 아직 실행 중입니다: node (pid 12)")
        #expect(CleanupNotice.processNotPermitted(name: "node", pid: 12).text == "권한이 없어 끌 수 없습니다: node (pid 12)")
        #expect(CleanupNotice.processAlreadyGone(name: "node", pid: 12).text == "이미 끝난 프로세스입니다: node (pid 12)")
        #expect(CleanupNotice.processFailed(name: "node", pid: 12).text == "끌 수 없습니다: node (pid 12)")
    }

    @Test func staysForFiveSeconds() {
        #expect(CleanupNotice.duration == 5)
    }
}

struct SignalResultTests {
    @Test func mapsKillResults() {
        #expect(SignalResult(killResult: 0, errno: 0) == .sent)
        #expect(SignalResult(killResult: -1, errno: EPERM) == .notPermitted)
        #expect(SignalResult(killResult: -1, errno: ESRCH) == .noSuchProcess)
        #expect(SignalResult(killResult: -1, errno: EINVAL) == .failed)
    }
}
