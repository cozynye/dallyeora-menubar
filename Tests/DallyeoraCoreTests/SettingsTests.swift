import Foundation
import Testing
@testable import DallyeoraCore

@MainActor
@Suite(.serialized)
struct SettingsTests {
    static let suite = "com.cozynye.dallyeora.tests"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: Self.suite)!
        defaults.removePersistentDomain(forName: Self.suite)
    }

    @Test func defaultsToSunfishAndStandard() {
        let s = Settings(defaults: defaults)
        #expect(s.mascotID == "sunfish")
        #expect(s.tone == .standard)
        #expect(s.metric == .cpu)
        #expect(s.showsPhrase == false, "메뉴 막대 자리를 아끼기 위해 대사는 기본으로 숨긴다")
    }

    @Test func persistsChoicesAcrossInstances() {
        let s = Settings(defaults: defaults)
        s.mascotID = "pork"
        s.tone = .gyeongsang
        s.metric = .memory
        s.showsPhrase = true
        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.mascotID == "pork")
        #expect(reloaded.tone == .gyeongsang)
        #expect(reloaded.metric == .memory)
        #expect(reloaded.showsPhrase == true)
    }

    @Test func unknownStoredValuesFallBack() {
        defaults.set("cat", forKey: Settings.Key.mascot)
        defaults.set("jeolla", forKey: Settings.Key.tone)
        defaults.set("gpu", forKey: Settings.Key.metric)
        let s = Settings(defaults: defaults)
        #expect(s.mascotID == "sunfish")
        #expect(s.tone == .standard)
        #expect(s.metric == .cpu)
    }

    @Test func metricLabels() {
        #expect(Metric.allCases.map(\.label) == ["CPU", "메모리"])
    }

    @Test func showsPercentDefaultsOffAndPersists() {
        let s = Settings(defaults: defaults)
        #expect(s.showsPercent == false)
        s.showsPercent = true
        #expect(Settings(defaults: defaults).showsPercent == true)
    }

    @Test func checksForUpdatesDefaultsOnAndPersists() {
        let s = Settings(defaults: defaults)
        #expect(s.checksForUpdates == true)
        s.checksForUpdates = false
        #expect(Settings(defaults: defaults).checksForUpdates == false)
    }

    @Test func notifiesOncePerRealChange() {
        let s = Settings(defaults: defaults)
        let count = Counter()
        let token = NotificationCenter.default.addObserver(forName: Settings.didChange, object: s, queue: nil) { _ in
            count.value += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }
        s.metric = .memory
        s.tone = .gyeongsang
        s.mascotID = "pork"
        s.showsPhrase = true
        s.showsPercent = true
        #expect(count.value == 5)
    }

    @Test func sameValueDoesNotNotify() {
        let s = Settings(defaults: defaults)
        s.metric = .memory
        let count = Counter()
        let token = NotificationCenter.default.addObserver(forName: Settings.didChange, object: s, queue: nil) { _ in
            count.value += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }
        s.metric = .memory
        s.showsPhrase = false
        #expect(count.value == 0, "같은 값을 다시 쓰면 창과 메뉴가 서로를 깨우지 않는다")
    }
}

private final class Counter: @unchecked Sendable { var value = 0 }
