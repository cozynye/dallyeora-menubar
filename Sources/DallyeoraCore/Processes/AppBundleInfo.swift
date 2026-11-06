import Foundation

public enum AppBundleInfo {
    public static func bundleID(at path: String) -> String? {
        Bundle(path: path)?.bundleIdentifier
    }

    /// Finder가 보여 주는 이름(예: 미리보기). 확장자가 붙어 오면 뗀다.
    public static func displayName(at path: String) -> String {
        let name = FileManager.default.displayName(atPath: path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
