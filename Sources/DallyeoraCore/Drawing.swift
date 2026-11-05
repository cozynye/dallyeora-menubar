import CoreGraphics
import Foundation

public enum MascotRenderer {
    public static let size = CGSize(width: 28, height: 18)

    /// 검은 단색으로 그린 이미지. 앱에서 template 이미지로 쓴다.
    public static func render(_ mascot: any Mascot, phase: Double, cpu: Double, scale: CGFloat = 2) -> CGImage? {
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scale, y: -scale)
        let black = CGColor(gray: 0, alpha: 1)
        ctx.setStrokeColor(black)
        ctx.setFillColor(black)
        ctx.setLineWidth(1.3)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        mascot.draw(in: ctx, phase: phase, cpu: CPUUsage.clamp(cpu))
        return ctx.makeImage()
    }
}

extension CGContext {
    func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        beginPath()
        move(to: CGPoint(x: x1, y: y1))
        addLine(to: CGPoint(x: x2, y: y2))
        strokePath()
    }

    func circle(_ x: Double, _ y: Double, _ r: Double, fill: Bool = false, alpha: Double = 1) {
        saveGState()
        setAlpha(alpha)
        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
        if fill { fillEllipse(in: rect) } else { strokeEllipse(in: rect) }
        restoreGState()
    }

    func triangle(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x3: Double, _ y3: Double) {
        beginPath()
        move(to: CGPoint(x: x1, y: y1))
        addLine(to: CGPoint(x: x2, y: y2))
        addLine(to: CGPoint(x: x3, y: y3))
        closePath()
        fillPath()
    }

    func wheel(_ x: Double, _ y: Double, _ angle: Double) {
        circle(x, y, 2.5)
        line(x, y, x + cos(angle) * 2.5, y + sin(angle) * 2.5)
    }
}

/// 0..<1 로 접기 (음수 없음 가정).
func frac(_ x: Double) -> Double { x - x.rounded(.down) }
