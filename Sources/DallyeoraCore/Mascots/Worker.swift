import CoreGraphics
import Foundation

struct Worker: Mascot {
    let id = "worker"
    let name = "퇴근하는 김대리"
    let tiers = [
        Tier(0, "월급루팡 중", "월급 받고 노는 중이데이"),
        Tier(25, "일하는 척하는 중", "일하는 척 하고 있다 아이가"),
        Tier(50, "오늘 야근 각", "오늘 야근이다, 마"),
        Tier(75, "칼퇴 질주!", "퇴근한다, 비키라!"),
    ]

    func draw(in ctx: CGContext, phase p: Double, cpu: Double) {
        let lean = cpu / 100 * 2.6
        let amp = 0.35 + cpu / 100 * 0.85
        let hx = 13 + lean
        if cpu >= 75 {
            for i in 0..<3 {
                let fi = Double(i)
                let o = (p * 3 + fi * 2).truncatingRemainder(dividingBy: 3)
                ctx.line(1 + o, 7 + fi * 3, 5 + o, 7 + fi * 3)       // 속도선
            }
        }
        ctx.circle(hx + 1.4, 3.6, 2.4)                               // 머리
        ctx.line(hx + 0.8, 6.1, 13, 11.4)                            // 몸통
        ctx.line(hx + 0.9, 6.9, hx + 1.9, 8.5)                       // 넥타이
        let s = sin(p), c = sin(p + .pi)
        ctx.line(13, 11.4, 13 + s * 3.6 * amp, 16.6)                 // 다리
        ctx.line(13, 11.4, 13 + c * 3.6 * amp, 16.6)
        let ax = hx + 0.6 + c * 3.2 * amp, ay = 10.6
        ctx.line(hx + 0.6, 7.4, ax, ay)                              // 가방 든 팔
        ctx.line(hx + 0.6, 7.4, hx + 0.6 + s * 3 * amp, 10.2)
        ctx.fill(CGRect(x: ax - 1.8, y: ay, width: 3.6, height: 2.6)) // 서류가방
    }
}
