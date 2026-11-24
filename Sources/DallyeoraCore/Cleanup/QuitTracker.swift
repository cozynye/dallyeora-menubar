/// 정리하기 창에서 앱 줄마다 따라가는 종료 흐름.
/// 종료를 요청하면 `requested`로 기다리고, 줄이 사라지면 꺼진 것으로 본다.
/// 요청을 보내지 못했거나 기한이 지나도 살아 있으면 `force`(강제 종료 버튼)가 된다.
public struct QuitTracker: Sendable {
    public enum State: Equatable, Sendable { case idle, requested, force }

    /// 기한 타이머가 들고 있다가 `deadlinePassed`에 돌려주는 표.
    /// 그사이 줄이 정리됐거나 같은 줄에 새 요청이 생겼으면 옛 표는 무시된다.
    public struct Ticket: Equatable, Sendable {
        let id: String
        let generation: Int
    }

    private struct Entry: Sendable {
        var state: State
        /// 줄이 사라진 뒤 상태 줄에 쓰려고 적어 둔다.
        var name: String
        var generation: Int
    }

    private var entries: [String: Entry] = [:]
    private var generation = 0

    public init() {}

    public func state(of id: String) -> State {
        entries[id]?.state ?? .idle
    }

    /// 종료 요청의 결과를 기록한다. 보냈으면 기한 타이머에 넘길 표를, 못 보냈으면 알릴 문구를 돌려준다.
    public mutating func request(id: String, name: String, sent: Bool) -> (ticket: Ticket?, notice: CleanupNotice?) {
        generation += 1
        entries[id] = Entry(state: sent ? .requested : .force, name: name, generation: generation)
        return sent ? (Ticket(id: id, generation: generation), nil) : (nil, .quitNotSent(app: name))
    }

    /// 목록을 새로 읽었을 때. 종료를 요청해 둔 줄이 사라졌으면 꺼진 것이다. 여러 개면 이름순.
    public mutating func rowsDidChange(present: Set<String>) -> [CleanupNotice] {
        let gone = entries.filter { !present.contains($0.key) }
        for id in gone.keys { entries[id] = nil }
        return gone.values.map(\.name).sorted().map { .quit(app: $0) }
    }

    /// 요청한 지 기한이 지났을 때. 아직 살아 있으면 강제 종료 버튼으로 바꾼다.
    public mutating func deadlinePassed(_ ticket: Ticket, isRunning: Bool) -> CleanupNotice? {
        guard let entry = entries[ticket.id], entry.generation == ticket.generation, entry.state == .requested else {
            return nil
        }
        if isRunning {
            entries[ticket.id]?.state = .force
            return .unresponsive(app: entry.name)
        }
        entries[ticket.id] = nil
        return .quit(app: entry.name)
    }

    /// 강제 종료를 시도한 뒤. 성공하든 실패하든 줄은 처음 상태로 돌아간다.
    public mutating func forceQuit(id: String, name: String, done: Bool) -> CleanupNotice {
        entries[id] = nil
        return done ? .forceQuit(app: name) : .forceQuitFailed(app: name)
    }

    /// 창을 닫을 때. 기다리던 요청을 잊어서 다시 열었을 때 뒤늦게 알리지 않는다.
    public mutating func reset() {
        entries = [:]
    }
}
