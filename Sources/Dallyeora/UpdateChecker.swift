import AppKit
import DallyeoraCore

/// 하루에 한 번 GitHub의 최신 릴리스 번호를 읽어, 설치된 것보다 높으면 메뉴에 알린다. 내려받기와 설치는 하지 않는다.
@MainActor
final class UpdateChecker {
    /// 알림을 누르면 여는 곳. 응답에 든 주소를 그대로 열지 않고 고정된 주소만 쓴다.
    static let releasesPage = URL(string: "https://github.com/cozynye/dallyeora-menubar/releases/latest")!
    private static let endpoint = URL(string: "https://api.github.com/repos/cozynye/dallyeora-menubar/releases/latest")!

    private enum Key {
        static let lastCheck = "lastUpdateCheck"
        static let latestVersion = "latestKnownVersion"
    }

    /// 알고 있는 최신 버전이 바뀌었을 때.
    var onChange: (() -> Void)?

    private let settings: Settings
    private let defaults: UserDefaults
    /// `swift run`처럼 번들 밖에서 뜨면 비교할 버전이 없어 확인하지 않는다.
    private let current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init)
    private var settingsObserver: NSObjectProtocol?
    private var timer: Timer?
    private var isChecking = false

    init(settings: Settings, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
    }

    var isAvailable: Bool { current != nil }

    /// 설치된 것보다 높은 버전을 알고 있으면 그 버전. 확인을 꺼 두면 알리지 않는다.
    var newerVersion: AppVersion? {
        guard settings.checksForUpdates else { return nil }
        return UpdateCheck.newer(latest: defaults.string(forKey: Key.latestVersion).flatMap(AppVersion.init), than: current)
    }

    /// 지금 한 번 보고, 그 뒤로는 한 시간마다 하루가 지났는지 본다. 실패한 확인은 다음 시간에 다시 한다.
    func start() {
        checkIfDue()
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        timer.tolerance = 600
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        // 꺼 두었다가 다시 켜면 바로 확인한다.
        settingsObserver = NotificationCenter.default.addObserver(
            forName: Settings.didChange, object: settings, queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
    }

    private func checkIfDue() {
        guard isAvailable, settings.checksForUpdates, !isChecking,
              UpdateCheck.isDue(last: defaults.object(forKey: Key.lastCheck) as? Date, now: Date()) else { return }
        isChecking = true
        Task {
            var request = URLRequest(url: Self.endpoint, timeoutInterval: 15)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let data = try? await URLSession(configuration: .ephemeral).data(for: request).0
            isChecking = false
            guard let data, let latest = UpdateCheck.latestVersion(inReleaseJSON: data) else { return }
            defaults.set(Date(), forKey: Key.lastCheck)
            defaults.set(latest.description, forKey: Key.latestVersion)
            onChange?()
        }
    }
}
