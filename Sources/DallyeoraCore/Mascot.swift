import CoreGraphics

public enum Tone: String, CaseIterable, Sendable {
    case standard
    case gyeongsang

    public var label: String {
        switch self {
        case .standard: "표준어"
        case .gyeongsang: "경상도"
        }
    }
}

public struct Tier: Sendable {
    public let minUsage: Double
    public let standard: String
    public let gyeongsang: String

    public init(_ minUsage: Double, _ standard: String, _ gyeongsang: String) {
        self.minUsage = minUsage
        self.standard = standard
        self.gyeongsang = gyeongsang
    }

    public func text(_ tone: Tone) -> String {
        tone == .standard ? standard : gyeongsang
    }
}

/// 메뉴 막대 캐릭터. 좌표계는 28×18, y축 아래 방향.
public protocol Mascot: Sendable {
    var id: String { get }
    var name: String { get }
    /// minUsage 오름차순, 첫 단계는 0.
    var tiers: [Tier] { get }
    func draw(in ctx: CGContext, phase: Double, usage: Double)
}

extension Mascot {
    public func tierIndex(for usage: Double) -> Int {
        let c = Usage.clamp(usage)
        return tiers.lastIndex { $0.minUsage <= c } ?? 0
    }

    public func phrase(usage: Double, tone: Tone) -> String {
        tiers[tierIndex(for: usage)].text(tone)
    }
}

public enum Mascots {
    public static let all: [any Mascot] = [Sunfish(), Worker(), Pork(), Rider()]
    public static let defaultID = "sunfish"
    public static var `default`: any Mascot { all[0] }

    public static func find(_ id: String) -> (any Mascot)? {
        all.first { $0.id == id }
    }
}
