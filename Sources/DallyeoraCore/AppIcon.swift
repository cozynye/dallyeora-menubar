import CoreGraphics
import Foundation

/// 앱 아이콘. macOS 아이콘 틀(1024 중 824 크기의 둥근 사각형) 위에 개복치를 흰 선으로 그린다.
/// 메뉴 막대 그림과 같은 코드를 쓰므로 이미지 파일이 따로 없다.
public enum AppIconRenderer {
    /// 바탕색(바다).
    public static let background = CGColor(red: 0.16, green: 0.47, blue: 0.78, alpha: 1)
    static let plateRatio: CGFloat = 824 / 1024
    static let cornerRatio: CGFloat = 0.2237
    /// 둥근 사각형 폭 대비 캐릭터 그림 폭.
    static let mascotRatio: CGFloat = 0.72

    public static func render(size: Int, mascot: any Mascot = Mascots.default) -> CGImage? {
        guard size > 0, let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let s = CGFloat(size)
        let plate = s * plateRatio
        let inset = (s - plate) / 2
        let radius = plate * cornerRatio
        ctx.addPath(CGPath(roundedRect: CGRect(x: inset, y: inset, width: plate, height: plate),
                           cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setFillColor(background)
        ctx.fillPath()

        // 마스코트 좌표계(28×18, y축 아래)를 가운데에 맞춘다. 선 굵기는 좌표계와 함께 커진다.
        let scale = plate * mascotRatio / MascotRenderer.size.width
        let drawW = MascotRenderer.size.width * scale
        let drawH = MascotRenderer.size.height * scale
        ctx.saveGState()
        ctx.translateBy(x: (s - drawW) / 2, y: (s + drawH) / 2)
        ctx.scaleBy(x: scale, y: -scale)
        let white = CGColor(gray: 1, alpha: 1)
        ctx.setStrokeColor(white)
        ctx.setFillColor(white)
        ctx.setLineWidth(1.3)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        mascot.draw(in: ctx, phase: 0, usage: 0)
        ctx.restoreGState()
        return ctx.makeImage()
    }
}
