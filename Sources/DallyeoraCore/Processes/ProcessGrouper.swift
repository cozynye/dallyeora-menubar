import Foundation

/// 스펙 3.4의 묶기 규칙.
public enum ProcessGrouper {
    public static let systemID = "system"
    static let maxParentDepth = 10

    /// 경로에서 가장 바깥의 `.app`까지. 없으면 nil.
    public static func appBundlePath(of path: String) -> String? {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard let i = parts.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return parts[...i].joined(separator: "/")
    }

    public static func group(_ snapshot: ProcessSnapshot, currentUID: uid_t, selfPID: pid_t) -> [ProcessGroup] {
        let samples = snapshot.samples.filter { $0.pid != selfPID }.sorted { $0.pid < $1.pid }
        let byPID = Dictionary(samples.map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })
        var groups: [String: ProcessGroup] = [:]
        var order: [String] = []
        var systemCount = 0

        for s in samples {
            if s.uid != currentUID {
                systemCount += 1
                continue
            }
            let id: String
            let kind: ProcessGroup.Kind
            if let bundle = owningBundle(of: s, byPID: byPID) {
                id = bundle
                kind = .app(bundlePath: bundle, mainPID: 0) // 대표 pid는 아래서 정한다
            } else {
                id = "name:" + s.name
                kind = .background(name: s.name)
            }
            if groups[id] == nil {
                groups[id] = ProcessGroup(id: id, kind: kind, pids: [], footprintBytes: 0, cpuTimeNanos: 0)
                order.append(id)
            }
            groups[id]?.pids.append(s.pid)
            groups[id]?.footprintBytes += s.footprintBytes
            groups[id]?.cpuTimeNanos += s.cpuTimeNanos
        }

        var result = order.compactMap { groups[$0] }
        for i in result.indices {
            if case .app(let bundle, _) = result[i].kind {
                result[i].kind = .app(bundlePath: bundle, mainPID: mainPID(of: result[i], bundle: bundle, byPID: byPID))
            }
        }
        if systemCount > 0 {
            result.append(ProcessGroup(id: systemID, kind: .system(count: systemCount), pids: [], footprintBytes: 0, cpuTimeNanos: 0))
        }
        return result
    }

    /// 경로의 .app, 없으면 부모를 따라 올라가 찾은 .app. 순환이나 10단계를 넘으면 포기한다.
    static func owningBundle(of sample: ProcessSample, byPID: [pid_t: ProcessSample]) -> String? {
        if let bundle = appBundlePath(of: sample.path) { return bundle }
        var seen: Set<pid_t> = [sample.pid]
        var pid = sample.ppid
        var depth = 0
        while pid > 1, depth < maxParentDepth, !seen.contains(pid), let parent = byPID[pid] {
            if let bundle = appBundlePath(of: parent.path) { return bundle }
            seen.insert(pid)
            pid = parent.ppid
            depth += 1
        }
        return nil
    }

    /// `<번들>/Contents/MacOS/<이름>` 바로 아래 프로세스. 없으면 가장 작은 pid.
    static func mainPID(of group: ProcessGroup, bundle: String, byPID: [pid_t: ProcessSample]) -> pid_t {
        let prefix = bundle + "/Contents/MacOS/"
        let direct = group.pids.filter { pid in
            guard let path = byPID[pid]?.path, path.hasPrefix(prefix) else { return false }
            return !path.dropFirst(prefix.count).contains("/")
        }
        return direct.min() ?? group.pids.min() ?? 0
    }
}
