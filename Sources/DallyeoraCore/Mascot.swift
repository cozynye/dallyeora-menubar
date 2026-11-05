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
    public let minCPU: Double
    public let standard: String
    public let gyeongsang: String

    public init(_ minCPU: Double, _ standard: String, _ gyeongsang: String) {
        self.minCPU = minCPU
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
    /// minCPU 오름차순, 첫 단계는 0.
    var tiers: [Tier] { get }
    func draw(in ctx: CGContext, phase: Double, cpu: Double)
}

extension Mascot {
    public func tierIndex(for cpu: Double) -> Int {
        let c = CPUUsage.clamp(cpu)
        return tiers.lastIndex { $0.minCPU <= c } ?? 0
    }

    public func phrase(cpu: Double, tone: Tone) -> String {
        tiers[tierIndex(for: cpu)].text(tone)
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
