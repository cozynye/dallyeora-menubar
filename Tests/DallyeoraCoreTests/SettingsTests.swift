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
    }

    @Test func persistsChoicesAcrossInstances() {
        let s = Settings(defaults: defaults)
        s.mascotID = "pork"
        s.tone = .gyeongsang
        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.mascotID == "pork")
        #expect(reloaded.tone == .gyeongsang)
    }

    @Test func unknownStoredValuesFallBack() {
        defaults.set("cat", forKey: Settings.Key.mascot)
        defaults.set("jeolla", forKey: Settings.Key.tone)
        let s = Settings(defaults: defaults)
        #expect(s.mascotID == "sunfish")
        #expect(s.tone == .standard)
    }
}
