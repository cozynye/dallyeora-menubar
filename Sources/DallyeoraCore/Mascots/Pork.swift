import CoreGraphics
import Foundation

struct Pork: Mascot {
    let id = "pork"
    let name = "삼겹살 불판"
    let tiers = [
        Tier(0, "불판 달구는 중", "아직 불도 안 올랐다"),
        Tier(25, "지글지글", "지글지글하네"),
        Tier(50, "지금 뒤집어!", "퍼뜩 뒤집으라"),
        Tier(75, "탄다 탄다! 노트북 뜨거움", "다 탔다 아이가"),
    ]

    func draw(in ctx: CGContext, phase p: Double, cpu: Double) {
        ctx.line(3, 16, 25, 16)                                      // 불판
        for x in stride(from: 5.0, through: 23, by: 3) { ctx.line(x, 16, x, 17.4) }
        let flip = cpu >= 75 ? cos(p * 0.7) : 1
        let h = 3.2 * abs(flip), y0 = 14.6 - h
        ctx.fill(CGRect(x: 7, y: y0, width: 14, height: h))          // 고기
        if h > 1.4 {
            ctx.setBlendMode(.clear)                                 // 비계 줄
            ctx.fill(CGRect(x: 7, y: y0 + h * 0.42, width: 14, height: 0.7))
            ctx.setBlendMode(.normal)
        }
        let puffs = 1 + Int(cpu / 25)
        for i in 0..<puffs {
            let fi = Double(i)
            let t = frac(p * 0.18 + fi / Double(puffs))
            let x = 9 + fi * 3.4 + sin(t * 6 + fi) * 1.2
            ctx.circle(x, 10 - t * 9, 0.7 + t * 1.3, alpha: 1 - t)   // 연기
        }
    }
}
