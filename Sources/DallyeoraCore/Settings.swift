import Foundation

/// 선택한 캐릭터, 말투, 지표. 알 수 없는 저장값은 기본값으로 돌아간다.
@MainActor
public final class Settings {
    public enum Key {
        public static let mascot = "mascotID"
        public static let tone = "tone"
        public static let metric = "metric"
        public static let showsPhrase = "showsPhrase"
        public static let showsPercent = "showsPercent"
        public static let checksForUpdates = "checksForUpdates"
    }

    /// 값이 실제로 바뀌었을 때 보낸다. object는 이 Settings.
    public static let didChange = Notification.Name("com.cozynye.dallyeora.settingsDidChange")

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var mascotID: String {
        get { defaults.string(forKey: Key.mascot).flatMap { Mascots.find($0)?.id } ?? Mascots.defaultID }
        set {
            guard newValue != mascotID else { return }
            defaults.set(newValue, forKey: Key.mascot)
            changed()
        }
    }

    public var tone: Tone {
        get { defaults.string(forKey: Key.tone).flatMap(Tone.init(rawValue:)) ?? .standard }
        set {
            guard newValue != tone else { return }
            defaults.set(newValue.rawValue, forKey: Key.tone)
            changed()
        }
    }

    public var metric: Metric {
        get { defaults.string(forKey: Key.metric).flatMap(Metric.init(rawValue:)) ?? .cpu }
        set {
            guard newValue != metric else { return }
            defaults.set(newValue.rawValue, forKey: Key.metric)
            changed()
        }
    }

    /// 메뉴 막대에 아이콘 옆 대사를 붙일지. 자리를 많이 차지해 기본은 끔.
    public var showsPhrase: Bool {
        get { defaults.bool(forKey: Key.showsPhrase) }
        set {
            guard newValue != showsPhrase else { return }
            defaults.set(newValue, forKey: Key.showsPhrase)
            changed()
        }
    }

    /// 메뉴 막대에 아이콘 옆 사용률 숫자를 붙일지. 기본은 끔.
    public var showsPercent: Bool {
        get { defaults.bool(forKey: Key.showsPercent) }
        set {
            guard newValue != showsPercent else { return }
            defaults.set(newValue, forKey: Key.showsPercent)
            changed()
        }
    }

    /// 하루에 한 번 GitHub에서 새 버전을 확인할지. 저장값이 없으면 켬.
    public var checksForUpdates: Bool {
        get { defaults.object(forKey: Key.checksForUpdates) as? Bool ?? true }
        set {
            guard newValue != checksForUpdates else { return }
            defaults.set(newValue, forKey: Key.checksForUpdates)
            changed()
        }
    }

    private func changed() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
