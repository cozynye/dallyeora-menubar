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
    }

    @Test func persistsChoicesAcrossInstances() {
        let s = Settings(defaults: defaults)
        s.mascotID = "pork"
        s.tone = .gyeongsang
        s.metric = .memory
        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.mascotID == "pork")
        #expect(reloaded.tone == .gyeongsang)
        #expect(reloaded.metric == .memory)
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
}
