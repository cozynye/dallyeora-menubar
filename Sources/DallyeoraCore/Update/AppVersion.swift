/// `0.6.0`이나 `v0.6.0` 같은 릴리스 번호. 숫자와 점으로만 된 것만 받고 `-beta` 같은 꼬리가 붙으면 버전으로 보지 않는다.
public struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    private let parts: [Int]

    public init?(_ text: String) {
        var body = Substring(text.trimmingCharacters(in: .whitespacesAndNewlines))
        if body.first == "v" || body.first == "V" { body = body.dropFirst() }
        let pieces = body.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(pieces.count) else { return nil }
        var parts: [Int] = []
        for piece in pieces {
            guard !piece.isEmpty, piece.allSatisfy(\.isASCII), piece.allSatisfy(\.isNumber), let number = Int(piece) else {
                return nil
            }
            parts.append(number)
        }
        self.parts = parts
    }

    public var description: String {
        parts.map(String.init).joined(separator: ".")
    }

    /// 빠진 자리는 0으로 보고 앞자리부터 숫자로 비교한다.
    private func part(_ index: Int) -> Int {
        index < parts.count ? parts[index] : 0
    }

    public static func == (a: AppVersion, b: AppVersion) -> Bool {
        (0..<max(a.parts.count, b.parts.count)).allSatisfy { a.part($0) == b.part($0) }
    }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        for index in 0..<max(a.parts.count, b.parts.count) where a.part(index) != b.part(index) {
            return a.part(index) < b.part(index)
        }
        return false
    }
}
