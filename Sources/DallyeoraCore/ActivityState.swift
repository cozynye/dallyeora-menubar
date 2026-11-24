/// 화면이 잠들었거나 다른 사용자로 전환된 동안에는 그릴 필요가 없다. 두 조건이 모두 풀려야 다시 돈다.
public struct ActivityState: Equatable, Sendable {
    public enum Event: Sendable {
        case screensDidSleep, screensDidWake, sessionDidResignActive, sessionDidBecomeActive
    }

    private var screensAsleep = false
    private var sessionInactive = false

    public init() {}

    public var isActive: Bool { !screensAsleep && !sessionInactive }

    /// 알림을 반영하고, 돌아야 하는지가 바뀌었으면 true.
    public mutating func handle(_ event: Event) -> Bool {
        let before = isActive
        switch event {
        case .screensDidSleep: screensAsleep = true
        case .screensDidWake: screensAsleep = false
        case .sessionDidResignActive: sessionInactive = true
        case .sessionDidBecomeActive: sessionInactive = false
        }
        return isActive != before
    }
}
