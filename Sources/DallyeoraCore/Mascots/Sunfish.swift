import CoreGraphics
import Foundation

struct Sunfish: Mascot {
    let id = "sunfish"
    let name = "개복치"
    let tiers = [
        Tier(0, "평온하게 헤엄 중", "편하게 헤엄치는 중이다"),
        Tier(25, "햇빛에 깜짝 놀람", "깜짝 놀랐다 아이가"),
        Tier(50, "스트레스로 위독", "스트레스 받아 죽겠다"),
        Tier(90, "충격으로 사망… 앱 좀 꺼 주세요", "마 죽었다… 앱 좀 꺼라"),
    ]

    func draw(in ctx: CGContext, phase p: Double, usage: Double) {
        let dead = usage >= 90
        let jitter = (usage >= 50 && !dead) ? (usage - 40) / 60 * 1.1 : 0
        ctx.saveGState()
        ctx.translateBy(x: 14 + sin(p * 7.3) * jitter, y: 9 + sin(p * 0.6) * (dead ? 0.3 : 0.9))
        if dead { ctx.rotate(by: .pi) }
        ctx.strokeEllipse(in: CGRect(x: -6, y: -5.2, width: 12, height: 10.4))
        let fin = sin(p) * 1.4
        ctx.triangle(-1, -4.6, 2, -4.6, 0.4 + fin * 0.4, -8.6)   // 등지느러미
        ctx.triangle(-1, 4.6, 2, 4.6, 0.4 - fin * 0.4, 8.6)      // 배지느러미
        ctx.line(-6, -3.4, -7.6, 0)                              // 잘린 꼬리
        ctx.line(-7.6, 0, -6, 3.4)
        if dead {
            ctx.line(2.4, -2.4, 4, -0.8)
            ctx.line(4, -2.4, 2.4, -0.8)
        } else {
            ctx.circle(3.2, -1.4, 0.9, fill: true)
        }
        ctx.restoreGState()
        if usage >= 50 && !dead {
            ctx.circle(22.6, 3 + frac(p * 0.5) * 3, 0.8, fill: true)   // 땀방울
        }
        if usage < 25 {
            let t = frac(p * 0.12)
            ctx.circle(22, 12 - t * 10, 0.9, alpha: 1 - t)             // 물방울
        }
    }
}
