import Testing
@testable import DallyeoraCore

struct MascotTests {
    @Test func orderAndDefault() {
        #expect(Mascots.all.map(\.id) == ["sunfish", "worker", "pork", "rider"])
        #expect(Mascots.defaultID == "sunfish")
        #expect(Mascots.default.id == "sunfish")
        #expect(Mascots.find("pork")?.name == "삼겹살 불판")
        #expect(Mascots.find("cat") == nil)
    }

    @Test func everyMascotHasFourAscendingTiersFromZero() {
        for m in Mascots.all {
            #expect(m.tiers.count == 4)
            #expect(m.tiers.first?.minCPU == 0)
            #expect(zip(m.tiers, m.tiers.dropFirst()).allSatisfy { $0.minCPU < $1.minCPU })
        }
    }

    @Test(arguments: [(24.9, 0), (25.0, 1), (49.9, 1), (50.0, 2), (89.9, 2), (90.0, 3), (100.0, 3)])
    func sunfishTierBoundaries(cpu: Double, index: Int) {
        #expect(Mascots.find("sunfish")!.tierIndex(for: cpu) == index)
    }

    @Test(arguments: [(74.9, 2), (75.0, 3)])
    func workerTopTierStartsAt75(cpu: Double, index: Int) {
        #expect(Mascots.find("worker")!.tierIndex(for: cpu) == index)
    }

    @Test(arguments: [-5.0, Double.nan, Double.infinity])
    func invalidCPUUsesFirstTier(cpu: Double) {
        for m in Mascots.all {
            #expect(m.tierIndex(for: cpu) == 0)
        }
    }

    @Test func phraseFollowsTone() {
        let fish = Mascots.find("sunfish")!
        #expect(fish.phrase(cpu: 95, tone: .standard) == "충격으로 사망… 앱 좀 꺼 주세요")
        #expect(fish.phrase(cpu: 95, tone: .gyeongsang) == "마 죽었다… 앱 좀 꺼라")
        #expect(Mascots.find("rider")!.phrase(cpu: 60, tone: .gyeongsang) == "간다 안 카나")
        #expect(Tone.gyeongsang.label == "경상도")
    }
}
