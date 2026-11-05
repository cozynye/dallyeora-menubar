import Foundation

/// 선택한 캐릭터와 말투. 알 수 없는 저장값은 기본값으로 돌아간다.
@MainActor
public final class Settings {
    public enum Key {
        public static let mascot = "mascotID"
        public static let tone = "tone"
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
}
