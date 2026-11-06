import Foundation

/// 화면에 보일 한국어 이름과 설명.
public struct ProcessDescription: Equatable, Sendable {
    public enum Source: Equatable, Sendable { case catalog, appName, pattern, unknown, system }

    public var title: String
    public var summary: String
    public var source: Source
    /// macOS 구성 요소. 끌 수 있어 보여도 버튼을 붙이지 않는다.
    public var isProtected: Bool
}

public struct CatalogEntry: Sendable {
    public enum Match: Equatable, Sendable {
        case bundleID(String)
        case name(String)
        case namePrefix(String)
    }

    public var match: Match
    public var title: String
    public var summary: String
    public var isProtected: Bool

    public init(_ match: Match, _ title: String, _ summary: String, protected: Bool = false) {
        self.match = match
        self.title = title
        self.summary = summary
        self.isProtected = protected
    }
}

/// 스펙 3.6의 사전과 폴백.
public enum ProcessCatalog {
    public static let entries: [CatalogEntry] = CatalogEntries.all
    static let systemLibraryPrefix = "/System/Library/"

    public static func describe(_ group: ProcessGroup, bundleID: String?, localizedName: String?) -> ProcessDescription {
        switch group.kind {
        case .system(let count):
            return ProcessDescription(
                title: "macOS 시스템",
                summary: "시스템 프로세스 \(count)개 (WindowServer, kernel_task 등). 권한이 없어 세부는 볼 수 없고 끌 수도 없다. 메모리는 근사치다.",
                source: .system, isProtected: true)

        case .app(let bundlePath, _):
            let folder = ((bundlePath as NSString).lastPathComponent as NSString).deletingPathExtension
            // /System/Library 아래 .app(WiFiAgent, WallpaperAgent 등 수십 개)은 이름 목록으로 다 못 담아 경로로 막는다.
            // /System/Applications(계산기, Safari)는 일반 앱이다.
            let isSystemComponent = bundlePath.hasPrefix(systemLibraryPrefix)
            if let e = bundleID.flatMap(entry(bundleID:)) ?? entry(name: folder) {
                return ProcessDescription(title: e.title, summary: e.summary, source: .catalog,
                                          isProtected: e.isProtected || isSystemComponent)
            }
            if isSystemComponent {
                return ProcessDescription(title: localizedName ?? folder, summary: "macOS 구성 요소. 끄면 바로 다시 켜지거나 그 기능이 멈춘다.",
                                          source: .appName, isProtected: true)
            }
            return ProcessDescription(title: localizedName ?? folder, summary: "Dock이나 메뉴 막대에 보이는 앱. 안 쓰면 꺼도 된다.",
                                      source: .appName, isProtected: false)

        case .background(let name):
            if let e = entry(name: name) {
                return ProcessDescription(title: e.title, summary: e.summary, source: .catalog, isProtected: e.isProtected)
            }
            if let summary = patternSummary(name) {
                return ProcessDescription(title: name, summary: summary, source: .pattern, isProtected: false)
            }
            return ProcessDescription(title: name, summary: "무엇인지 알 수 없는 프로세스.", source: .unknown, isProtected: false)
        }
    }

    static func entry(bundleID id: String) -> CatalogEntry? {
        entries.first { $0.match == .bundleID(id) }
    }

    /// 정확히 같은 이름을 먼저, 그다음 접두사.
    static func entry(name: String) -> CatalogEntry? {
        if let exact = entries.first(where: { $0.match == .name(name) }) { return exact }
        return entries.first { entry in
            if case .namePrefix(let prefix) = entry.match { return name.hasPrefix(prefix) }
            return false
        }
    }

    static func patternSummary(_ name: String) -> String? {
        let lower = name.lowercased()
        if ["helper", "renderer", "plugin"].contains(where: { lower.contains($0) }) {
            return "어떤 앱의 보조 프로세스. 그 앱을 닫으면 함께 사라진다."
        }
        if lower.hasPrefix("com.apple.") || lower.hasSuffix("d") || lower.hasSuffix("agent") {
            return "macOS 백그라운드 서비스. 보통 잠시 뒤 저절로 내려간다."
        }
        return nil
    }
}
