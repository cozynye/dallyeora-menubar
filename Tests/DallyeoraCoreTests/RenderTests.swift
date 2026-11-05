import CoreGraphics
import Testing
@testable import DallyeoraCore

struct RenderTests {
    @Test(arguments: [0.0, 30.0, 60.0, 95.0])
    func everyMascotDrawsVisiblePixels(usage: Double) throws {
        for m in Mascots.all {
            let image = try #require(MascotRenderer.render(m, phase: 1.0, usage: usage))
            #expect(image.width == 56)
            #expect(image.height == 36)
            #expect(alphaBytes(image).filter { $0 > 0 }.count > 20, "\(m.id) at \(usage)%")
        }
    }

    @Test func sunfishFlipsAtNinety() throws {
        let fish = try #require(Mascots.find("sunfish"))
        let alive = try #require(MascotRenderer.render(fish, phase: 0, usage: 89))
        let dead = try #require(MascotRenderer.render(fish, phase: 0, usage: 90))
        #expect(alphaBytes(alive) != alphaBytes(dead))
    }

    @Test(arguments: [Double.nan, -20.0, 400.0])
    func invalidUsageStillRenders(usage: Double) {
        for m in Mascots.all {
            #expect(MascotRenderer.render(m, phase: 0, usage: usage) != nil)
        }
    }
}

/// 이미지를 RGBA 버퍼로 다시 그려 알파 채널만 꺼낸다.
func alphaBytes(_ image: CGImage) -> [UInt8] {
    let w = image.width, h = image.height
    var buffer = [UInt8](repeating: 0, count: w * h * 4)
    buffer.withUnsafeMutableBytes { raw in
        let ctx = CGContext(
            data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return stride(from: 3, to: buffer.count, by: 4).map { buffer[$0] }
}
