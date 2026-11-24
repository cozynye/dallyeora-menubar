import Foundation
import Testing
@testable import DallyeoraCore

struct AppVersionTests {
    @Test func parsesTagsAndPlainVersions() {
        #expect(AppVersion("0.6.0")?.description == "0.6.0")
        #expect(AppVersion("v0.6.0")?.description == "0.6.0")
        #expect(AppVersion(" 1.2\n")?.description == "1.2")
    }

    @Test func rejectsWhatIsNotAReleaseNumber() {
        for text in ["", "abc", "1.x", "0.6.0-beta", "1..2", "-1.0", "v", "1.2.3.4.5"] {
            #expect(AppVersion(text) == nil, "\(text)")
        }
    }

    @Test func comparesNumericallyNotAsText() {
        #expect(AppVersion("0.10.0")! > AppVersion("0.9.0")!)
        #expect(AppVersion("1.0.0")! > AppVersion("0.99.99")!)
        #expect(AppVersion("0.6.1")! > AppVersion("0.6")!)
        #expect(AppVersion("0.6")! == AppVersion("0.6.0")!, "빠진 자리는 0으로 본다")
        #expect((AppVersion("0.6.0")! > AppVersion("0.6.0")!) == false)
    }
}

struct UpdateCheckTests {
    @Test func readsTheTagOfTheLatestRelease() {
        let json = Data(#"{"tag_name":"v0.7.0","html_url":"https://example.com","prerelease":false}"#.utf8)
        #expect(UpdateCheck.latestVersion(inReleaseJSON: json) == AppVersion("0.7.0"))
    }

    @Test func ignoresResponsesWithoutAUsableTag() {
        let rateLimited = Data(#"{"message":"API rate limit exceeded"}"#.utf8)
        #expect(UpdateCheck.latestVersion(inReleaseJSON: rateLimited) == nil)
        #expect(UpdateCheck.latestVersion(inReleaseJSON: Data(#"{"tag_name":"nightly"}"#.utf8)) == nil)
        #expect(UpdateCheck.latestVersion(inReleaseJSON: Data(#"{"tag_name":7}"#.utf8)) == nil)
        #expect(UpdateCheck.latestVersion(inReleaseJSON: Data("<html>".utf8)) == nil)
        #expect(UpdateCheck.latestVersion(inReleaseJSON: Data()) == nil)
    }

    @Test func checksOnceADay() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(UpdateCheck.isDue(last: nil, now: now), "한 번도 확인하지 않았으면 바로 확인한다")
        #expect(UpdateCheck.isDue(last: now.addingTimeInterval(-3600), now: now) == false)
        #expect(UpdateCheck.isDue(last: now.addingTimeInterval(-UpdateCheck.interval), now: now))
        #expect(UpdateCheck.isDue(last: now.addingTimeInterval(3600), now: now), "시계가 뒤로 가서 기록이 미래면 다시 확인한다")
        #expect(UpdateCheck.interval == 86400)
    }

    @Test func offersOnlyAHigherVersion() {
        #expect(UpdateCheck.newer(latest: AppVersion("0.7.0"), than: AppVersion("0.6.0")) == AppVersion("0.7.0"))
        #expect(UpdateCheck.newer(latest: AppVersion("0.6.0"), than: AppVersion("0.6.0")) == nil)
        #expect(UpdateCheck.newer(latest: AppVersion("0.5.0"), than: AppVersion("0.6.0")) == nil, "직접 빌드한 더 높은 버전에는 알리지 않는다")
        #expect(UpdateCheck.newer(latest: nil, than: AppVersion("0.6.0")) == nil)
        #expect(UpdateCheck.newer(latest: AppVersion("0.7.0"), than: nil) == nil)
    }
}
