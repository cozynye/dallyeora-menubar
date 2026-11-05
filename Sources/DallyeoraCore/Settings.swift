import Foundation

/// 선택한 캐릭터, 말투, 지표. 알 수 없는 저장값은 기본값으로 돌아간다.
@MainActor
public final class Settings {
    public enum Key {
        public static let mascot = "mascotID"
        public static let tone = "tone"
        public static let metric = "metric"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var mascotID: String {
        get { defaults.string(forKey: Key.mascot).flatMap { Mascots.find($0)?.id } ?? Mascots.defaultID }
        set { defaults.set(newValue, forKey: Key.mascot) }
    }

    public var tone: Tone {
        get { defaults.string(forKey: Key.tone).flatMap(Tone.init(rawValue:)) ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: Key.tone) }
    }

    public var metric: Metric {
        get { defaults.string(forKey: Key.metric).flatMap(Metric.init(rawValue:)) ?? .cpu }
        set { defaults.set(newValue.rawValue, forKey: Key.metric) }
    }
}
