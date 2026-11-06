import Foundation
import Testing
@testable import DallyeoraCore

struct ProcessCatalogTests {
    func app(_ bundle: String) -> ProcessGroup {
        ProcessGroup(id: bundle, kind: .app(bundlePath: bundle, mainPID: 1), pids: [1], footprintBytes: 0, cpuTimeNanos: 0)
    }
    func bg(_ name: String) -> ProcessGroup {
        ProcessGroup(id: "name:" + name, kind: .background(name: name), pids: [1], footprintBytes: 0, cpuTimeNanos: 0)
    }

    @Test func knownAppByBundleID() {
        let d = ProcessCatalog.describe(app("/Applications/Google Chrome.app"), bundleID: "com.google.Chrome", localizedName: "Google Chrome")
        #expect(d.title == "Google Chrome")
        #expect(d.source == .catalog)
        #expect(d.summary.contains("탭"))
        #expect(!d.isProtected)
    }

    @Test func unknownAppUsesLocalizedNameAndGenericSummary() {
        let d = ProcessCatalog.describe(app("/Applications/Foo.app"), bundleID: "com.example.foo", localizedName: "푸")
        #expect(d.title == "푸")
        #expect(d.summary == "Dock이나 메뉴 막대에 보이는 앱. 안 쓰면 꺼도 된다.")
        #expect(d.source == .appName)
    }

    @Test func unknownAppWithoutLocalizedNameUsesFolderName() {
        let d = ProcessCatalog.describe(app("/Applications/Foo Bar.app"), bundleID: nil, localizedName: nil)
        #expect(d.title == "Foo Bar")
    }

    @Test func systemAppsAreProtectedByFolderName() {
        for folder in ["Finder", "Dock", "Spotlight", "ControlCenter", "NotificationCenter", "WindowManager", "SystemUIServer", "loginwindow"] {
            let d = ProcessCatalog.describe(app("/System/Library/CoreServices/\(folder).app"), bundleID: nil, localizedName: nil)
            #expect(d.source == .catalog, "\(folder)")
            #expect(d.isProtected, "\(folder)")
        }
    }

    @Test func knownBackgroundByExactName() {
        let d = ProcessCatalog.describe(bg("mdworker_shared"), bundleID: nil, localizedName: nil)
        #expect(d.source == .catalog)
        #expect(d.title.contains("Spotlight"))
    }

    @Test func knownBackgroundByPrefix() {
        let d = ProcessCatalog.describe(bg("python3.12"), bundleID: nil, localizedName: nil)
        #expect(d.source == .catalog)
        #expect(d.title.contains("파이썬"))
    }

    @Test func helperPatternFallback() {
        let d = ProcessCatalog.describe(bg("Foo Helper (GPU)"), bundleID: nil, localizedName: nil)
        #expect(d.source == .pattern)
        #expect(d.title == "Foo Helper (GPU)")
        #expect(d.summary == "어떤 앱의 보조 프로세스. 그 앱을 닫으면 함께 사라진다.")
    }

    @Test(arguments: ["fooagent", "barfood", "com.apple.something.xpc"])
    func daemonPatternFallback(name: String) {
        let d = ProcessCatalog.describe(bg(name), bundleID: nil, localizedName: nil)
        #expect(d.source == .pattern)
        #expect(d.summary == "macOS 백그라운드 서비스. 보통 잠시 뒤 저절로 내려간다.")
    }

    @Test func unknownIsLabeledUnknown() {
        let d = ProcessCatalog.describe(bg("xyzzy"), bundleID: nil, localizedName: nil)
        #expect(d.source == .unknown)
        #expect(d.title == "xyzzy")
        #expect(d.summary == "무엇인지 알 수 없는 프로세스.")
    }

    @Test func systemRowDescriptionCarriesTheCount() {
        let g = ProcessGroup(id: "system", kind: .system(count: 241), pids: [], footprintBytes: 0, cpuTimeNanos: 0)
        let d = ProcessCatalog.describe(g, bundleID: nil, localizedName: nil)
        #expect(d.title == "macOS 시스템")
        #expect(d.summary == "시스템 프로세스 241개 (WindowServer, kernel_task 등). 권한이 없어 세부는 볼 수 없고 끌 수도 없다. 메모리는 근사치다.")
        #expect(d.source == .system)
        #expect(d.isProtected)
    }

    /// /System/Library 아래 .app은 사전에 없어도, 사전에서 protected가 아니어도 시스템 구성 요소다.
    @Test func systemLibraryBundlesAreProtected() {
        let wifi = ProcessCatalog.describe(app("/System/Library/CoreServices/WiFiAgent.app"),
                                           bundleID: "com.apple.wifi.WiFiAgent", localizedName: "WiFiAgent")
        #expect(wifi.isProtected)
        #expect(wifi.title == "WiFiAgent")
        #expect(wifi.summary == "macOS 구성 요소. 끄면 바로 다시 켜지거나 그 기능이 멈춘다.")
        #expect(wifi.source == .appName)

        let wallpaper = ProcessCatalog.describe(app("/System/Library/CoreServices/WallpaperAgent.app"), bundleID: nil, localizedName: nil)
        #expect(wallpaper.isProtected)
        #expect(wallpaper.source == .catalog)

        let calculator = ProcessCatalog.describe(app("/System/Applications/Calculator.app"),
                                                 bundleID: "com.apple.calculator", localizedName: "계산기")
        #expect(!calculator.isProtected)
    }

    @Test func catalogCoversTheRequiredNames() {
        #expect(ProcessCatalog.entries.count >= 100)
        let names = [
            "Finder", "Dock", "Spotlight", "ControlCenter", "NotificationCenter", "WindowManager", "SystemUIServer", "loginwindow",
            "mdworker_shared", "corespotlightd", "photoanalysisd", "photolibraryd", "mediaanalysisd", "bird", "cloudd", "cloudphotod",
            "nsurlsessiond", "com.apple.WebKit.WebContent", "com.apple.WebKit.Networking", "com.apple.WebKit.GPU", "QuickLookUIService",
            "suggestd", "knowledgeconstructiond", "siriknowledged", "assistantd", "accountsd", "identityservicesd", "imagent", "sharingd",
            "rapportd", "secd", "trustd", "cfprefsd", "distnoted", "UserEventAgent", "lsd", "tccd",
            "kernel_task", "WindowServer", "launchd", "mds", "mds_stores", "backupd", "softwareupdated", "syspolicyd", "XprotectService",
            "coreaudiod", "opendirectoryd", "runningboardd",
            "node", "python3", "Python", "java", "ruby", "swift-frontend", "clang", "SourceKitService", "com.docker.backend",
            "com.docker.virtualization", "qemu-system-aarch64", "ollama", "gradle", "rustc", "cargo",
        ]
        for name in names {
            #expect(ProcessCatalog.entry(name: name) != nil, "\(name)")
        }
        let bundles = [
            "com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac", "com.brave.Browser", "com.naver.Whale",
            "company.thebrowser.Browser", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.apple.dt.Xcode",
            "com.apple.iphonesimulator", "com.apple.Terminal", "com.googlecode.iterm2", "com.docker.docker", "com.tinyspeck.slackmacgap",
            "com.hnc.Discord", "notion.id", "com.kakao.KakaoTalkMac", "us.zoom.xos", "com.microsoft.teams2", "com.spotify.client",
            "com.apple.Music", "com.figma.Desktop", "com.postmanlabs.mac", "com.jetbrains.intellij", "com.microsoft.Word", "com.microsoft.Excel",
            "com.microsoft.Powerpoint", "com.adobe.Photoshop", "com.openai.chat", "com.anthropic.claudefordesktop", "com.1password.1password",
            "com.getdropbox.dropbox", "com.google.drivefs", "com.apple.Photos", "com.apple.mail", "com.apple.Notes", "com.apple.iCal",
            "com.apple.Preview", "com.apple.ActivityMonitor",
        ]
        for id in bundles {
            #expect(ProcessCatalog.entry(bundleID: id) != nil, "\(id)")
        }
    }

    @Test func readsBundleInfoFromDisk() {
        let preview = "/System/Applications/Preview.app"
        #expect(AppBundleInfo.bundleID(at: preview) == "com.apple.Preview")
        let name = AppBundleInfo.displayName(at: preview)
        #expect(!name.isEmpty)
        #expect(!name.hasSuffix(".app"))
        #expect(AppBundleInfo.bundleID(at: "/nonexistent/Nope.app") == nil)
    }
}
