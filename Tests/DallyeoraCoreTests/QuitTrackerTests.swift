import Testing
@testable import DallyeoraCore

struct QuitTrackerTests {
    @Test func unknownRowIsIdle() {
        #expect(QuitTracker().state(of: "slack") == .idle)
    }

    @Test func sentRequestWaitsAndReportsWhenTheRowDisappears() {
        var quits = QuitTracker()
        let (ticket, notice) = quits.request(id: "slack", name: "Slack", sent: true)
        #expect(ticket != nil)
        #expect(notice == nil)
        #expect(quits.state(of: "slack") == .requested)
        #expect(quits.rowsDidChange(present: ["slack", "chrome"]) == [], "줄이 남아 있으면 아직 꺼지지 않았다")
        #expect(quits.rowsDidChange(present: ["chrome"]) == [.quit(app: "Slack")])
        #expect(quits.state(of: "slack") == .idle)
        #expect(quits.rowsDidChange(present: ["chrome"]) == [], "한 번만 알린다")
    }

    @Test func unsentRequestOffersForceQuitRightAway() {
        var quits = QuitTracker()
        let (ticket, notice) = quits.request(id: "slack", name: "Slack", sent: false)
        #expect(ticket == nil)
        #expect(notice == .quitNotSent(app: "Slack"))
        #expect(quits.state(of: "slack") == .force)
    }

    @Test func deadlineTurnsARunningAppIntoForceQuit() {
        var quits = QuitTracker()
        let ticket = quits.request(id: "slack", name: "Slack", sent: true).ticket!
        #expect(quits.deadlinePassed(ticket, isRunning: true) == .unresponsive(app: "Slack"))
        #expect(quits.state(of: "slack") == .force)
    }

    @Test func deadlineReportsAnAppThatAlreadyEnded() {
        var quits = QuitTracker()
        let ticket = quits.request(id: "slack", name: "Slack", sent: true).ticket!
        #expect(quits.deadlinePassed(ticket, isRunning: false) == .quit(app: "Slack"))
        #expect(quits.state(of: "slack") == .idle)
    }

    @Test func deadlineIsIgnoredOnceTheRowIsGone() {
        var quits = QuitTracker()
        let ticket = quits.request(id: "slack", name: "Slack", sent: true).ticket!
        _ = quits.rowsDidChange(present: [])
        #expect(quits.deadlinePassed(ticket, isRunning: false) == nil, "사라질 때 이미 알렸다")
    }

    @Test func staleDeadlineDoesNotTouchANewerRequest() {
        var quits = QuitTracker()
        let first = quits.request(id: "slack", name: "Slack", sent: true).ticket!
        _ = quits.rowsDidChange(present: [])
        // 앱을 다시 켜서 같은 줄에 또 종료를 요청했다.
        let second = quits.request(id: "slack", name: "Slack", sent: true).ticket!
        #expect(quits.deadlinePassed(first, isRunning: false) == nil, "옛 요청의 타이머는 새 요청을 건드리지 않는다")
        #expect(quits.state(of: "slack") == .requested)
        #expect(quits.deadlinePassed(second, isRunning: true) == .unresponsive(app: "Slack"))
    }

    @Test func forceQuitClearsTheRowWhateverTheOutcome() {
        var quits = QuitTracker()
        _ = quits.request(id: "slack", name: "Slack", sent: false)
        #expect(quits.forceQuit(id: "slack", name: "Slack", done: true) == .forceQuit(app: "Slack"))
        #expect(quits.state(of: "slack") == .idle)
        _ = quits.request(id: "slack", name: "Slack", sent: false)
        #expect(quits.forceQuit(id: "slack", name: "Slack", done: false) == .forceQuitFailed(app: "Slack"))
        #expect(quits.state(of: "slack") == .idle)
        #expect(quits.rowsDidChange(present: []) == [], "강제 종료한 줄이 사라져도 다시 알리지 않는다")
    }

    @Test func resetForgetsPendingRequests() {
        var quits = QuitTracker()
        let ticket = quits.request(id: "slack", name: "Slack", sent: true).ticket!
        quits.reset()
        #expect(quits.state(of: "slack") == .idle)
        #expect(quits.rowsDidChange(present: []) == [], "창을 닫은 뒤에는 뒤늦게 알리지 않는다")
        #expect(quits.deadlinePassed(ticket, isRunning: true) == nil)
    }

    @Test func severalVanishedRowsAreReportedInNameOrder() {
        var quits = QuitTracker()
        _ = quits.request(id: "b", name: "Slack", sent: true)
        _ = quits.request(id: "a", name: "Chrome", sent: true)
        #expect(quits.rowsDidChange(present: []) == [.quit(app: "Chrome"), .quit(app: "Slack")])
    }
}

struct CleanupRunStateTests {
    @Test func startsStopped() {
        #expect(CleanupRunState().shouldRun == false)
    }

    @Test func runsWhileTheWindowIsOpen() {
        var state = CleanupRunState()
        #expect(state.handle(.windowOpened) == true)
        #expect(state.shouldRun)
        #expect(state.handle(.windowOpened) == false, "이미 열린 창을 다시 불러도 다시 시작하지 않는다")
        #expect(state.handle(.windowClosed) == true)
        #expect(state.shouldRun == false)
    }

    @Test func miniaturizingPauses() {
        var state = CleanupRunState()
        _ = state.handle(.windowOpened)
        #expect(state.handle(.windowMiniaturized) == true)
        #expect(state.shouldRun == false)
        #expect(state.handle(.windowDeminiaturized) == true)
        #expect(state.shouldRun)
    }

    @Test func screenSleepPausesEvenWhenMiniaturized() {
        var state = CleanupRunState()
        _ = state.handle(.windowOpened)
        _ = state.handle(.windowMiniaturized)
        #expect(state.handle(.screenBecameInactive) == false)
        #expect(state.handle(.windowDeminiaturized) == false, "화면이 꺼져 있으면 복원해도 멈춰 있다")
        #expect(state.handle(.screenBecameActive) == true)
        #expect(state.shouldRun)
    }

    @Test func screenEventsDoNothingWhileClosed() {
        var state = CleanupRunState()
        #expect(state.handle(.screenBecameInactive) == false)
        #expect(state.handle(.screenBecameActive) == false)
        #expect(state.shouldRun == false)
    }

    @Test func reopeningShowsTheWindowAgain() {
        var state = CleanupRunState()
        _ = state.handle(.windowOpened)
        _ = state.handle(.windowMiniaturized)
        // 최소화한 창을 메뉴나 단축키로 다시 부르면 꺼내서 보여 준다.
        #expect(state.handle(.windowOpened) == true)
        #expect(state.shouldRun)
    }

    @Test func closingForgetsMiniaturization() {
        var state = CleanupRunState()
        _ = state.handle(.windowOpened)
        _ = state.handle(.windowMiniaturized)
        _ = state.handle(.windowClosed)
        #expect(state.handle(.windowOpened) == true)
    }
}
