import CoreGraphics
import Testing
@testable import DallyeoraCore

struct AppIconTests {
    @Test(arguments: [64, 1024])
    func iconIsSquareWithTransparentCornersAndVisibleFish(size: Int) throws {
        let image = try #require(AppIconRenderer.render(size: size))
        #expect(image.width == size)
        #expect(image.height == size)
        let px = rgbaBytes(image)
        func pixel(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
            let i = (y * size + x) * 4
            return (px[i], px[i + 1], px[i + 2], px[i + 3])
        }
        // 둥근 사각형 바깥인 모서리는 투명.
        #expect(pixel(0, 0).a == 0)
        #expect(pixel(size - 1, size - 1).a == 0)
        // 가운데 줄에는 배경이 있고, 그 위에 흰 선으로 그린 개복치가 있다.
        var opaque = 0, white = 0
        for y in 0..<size {
            for x in 0..<size {
                let p = pixel(x, y)
                if p.a > 0 { opaque += 1 }
                if p.a > 200 && p.r > 230 && p.g > 230 && p.b > 230 { white += 1 }
            }
        }
        #expect(Double(opaque) > Double(size * size) * 0.5)
        #expect(white > size * size / 200)
        #expect(white < opaque / 2)
    }
}

/// 이미지를 RGBA 버퍼로 다시 그린다. 알파는 사전 곱(premultiplied).
func rgbaBytes(_ image: CGImage) -> [UInt8] {
    let w = image.width, h = image.height
    var buffer = [UInt8](repeating: 0, count: w * h * 4)
    buffer.withUnsafeMutableBytes { raw in
        let ctx = CGContext(
            data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return buffer
}
