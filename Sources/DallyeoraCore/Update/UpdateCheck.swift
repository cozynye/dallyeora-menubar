import Foundation

/// 새 버전 확인에 필요한 판단. 네트워크는 앱 쪽 `UpdateChecker`가 맡는다.
public enum UpdateCheck {
    /// 확인 간격(초). 하루에 한 번.
    public static let interval: TimeInterval = 86400

    /// GitHub `releases/latest` 응답에서 태그를 읽는다. 사용량 제한 응답처럼 태그가 없거나 번호가 아니면 nil.
    public static func latestVersion(inReleaseJSON data: Data) -> AppVersion? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String else { return nil }
        return AppVersion(tag)
    }

    /// 마지막 확인에서 `interval`이 지났거나, 기록이 없거나, 기록이 미래면 다시 확인한다.
    public static func isDue(last: Date?, now: Date) -> Bool {
        guard let last else { return true }
        let elapsed = now.timeIntervalSince(last)
        return elapsed < 0 || elapsed >= interval
    }

    /// 설치된 것보다 높을 때만 그 버전을 돌려준다.
    public static func newer(latest: AppVersion?, than current: AppVersion?) -> AppVersion? {
        guard let latest, let current, latest > current else { return nil }
        return latest
    }
}
