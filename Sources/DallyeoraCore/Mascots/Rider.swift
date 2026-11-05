import CoreGraphics
import Foundation

struct Rider: Mascot {
    let id = "rider"
    let name = "배달 라이더"
    let tiers = [
        Tier(0, "조리 중…", "아직 음식 만드는 중이다"),
        Tier(25, "픽업 완료", "음식 받았다"),
        Tier(50, "배달 중", "간다 안 카나"),
        Tier(75, "곧 도착합니다!", "다 왔다, 문 열어라"),
    ]

    func draw(in ctx: CGContext, phase p: Double, cpu: Double) {
        let moving = cpu >= 25
        let bump = moving ? abs(sin(p * 1.3)) * (cpu / 100) * 1.1 : 0
        if cpu >= 75 {
            for i in 0..<3 {
                let fi = Double(i)
                ctx.line(0.5, 9 + fi * 2.6, 3 + (p + fi).truncatingRemainder(dividingBy: 2), 9 + fi * 2.6)
            }
        }
        ctx.saveGState()
        ctx.translateBy(x: 0, y: -bump)
        let spin = moving ? p : 0
        ctx.wheel(8, 14.6, spin)
        ctx.wheel(21.5, 14.6, spin)
        ctx.line(8, 14.6, 12, 11.6)                                  // 차체
        ctx.line(12, 11.6, 19, 11.6)
        ctx.line(19, 11.6, 21.5, 14.6)
        ctx.line(19.6, 11.6, 21.6, 5.8)                              // 핸들
        ctx.line(21.6, 5.8, 23.4, 5.8)
        ctx.stroke(CGRect(x: 4.2, y: 5.2, width: 6.4, height: 5.4))  // 배달통
        ctx.circle(15.6, 3.2, 2.1)                                   // 라이더
        ctx.line(15.2, 5.3, 14, 10.6)
        ctx.line(15.4, 6.6, 21, 6.4)
        if !moving {
            let t = frac(p * 0.15), t2 = frac(p * 0.15 + 0.5)        // 김
            ctx.line(6.4, 4 - t * 3.6, 7.4, 3 - t * 3.6)
            ctx.line(8.6, 4 - t2 * 3.6, 9.4, 3 - t2 * 3.6)
        }
        ctx.restoreGState()
    }
}
