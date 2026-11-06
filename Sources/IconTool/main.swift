import DallyeoraCore
import Foundation
import ImageIO

// 개복치 아이콘을 iconutil이 요구하는 크기로 그려 .icns 하나로 묶는다.
// 사용: IconTool <출력.icns>

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 else { fail("사용: IconTool <출력.icns>") }
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("Dallyeora-\(ProcessInfo.processInfo.processIdentifier).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// iconutil이 받는 파일 이름과 픽셀 크기.
let sizes: [(name: String, pixels: Int)] = [
    ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
    ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
    ("512x512", 512), ("512x512@2x", 1024),
]
for entry in sizes {
    guard let image = AppIconRenderer.render(size: entry.pixels) else { fail("\(entry.pixels)px 그리기 실패") }
    let url = iconset.appendingPathComponent("icon_\(entry.name).png")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fail("\(url.path) 만들기 실패")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("\(url.path) 쓰기 실패") }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fail("iconutil 실패 (\(iconutil.terminationStatus))") }
print(output.path)
