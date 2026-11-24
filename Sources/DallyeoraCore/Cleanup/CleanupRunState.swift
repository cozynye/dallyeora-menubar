/// 정리하기 창이 프로세스를 읽어야 하는지. 창이 열려 있고, 최소화되지 않았고, 화면이 켜져 있을 때만 돈다.
public struct CleanupRunState: Equatable, Sendable {
    public enum Event: Sendable {
        /// 메뉴나 단축키로 창을 불렀다. 최소화돼 있었으면 꺼낸다.
        case windowOpened
        case windowClosed, windowMiniaturized, windowDeminiaturized
        case screenBecameActive, screenBecameInactive
    }

    private var isOpen = false
    private var isMiniaturized = false
    private var screenActive = true

    public init() {}

    public var shouldRun: Bool { isOpen && !isMiniaturized && screenActive }

    /// 알림을 반영하고, 돌아야 하는지가 바뀌었으면 true.
    public mutating func handle(_ event: Event) -> Bool {
        let before = shouldRun
        switch event {
        case .windowOpened:
            isOpen = true
            isMiniaturized = false
        case .windowClosed:
            isOpen = false
            isMiniaturized = false
        case .windowMiniaturized: isMiniaturized = true
        case .windowDeminiaturized: isMiniaturized = false
        case .screenBecameActive: screenActive = true
        case .screenBecameInactive: screenActive = false
        }
        return shouldRun != before
    }
}
