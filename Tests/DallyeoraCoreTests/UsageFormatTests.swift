import Testing
@testable import DallyeoraCore

struct UsageFormatTests {
    @Test(arguments: [
        (UInt64(0), "0 B"), (UInt64(1023), "1023 B"), (UInt64(1024), "1 KB"),
        (UInt64(1_048_576), "1 MB"), (UInt64(429_916_160), "410 MB"),
        (UInt64(1_610_612_736), "1.5 GB"), (UInt64(17_179_869_184), "16.0 GB"),
    ])
    func formatsBytesInBinaryUnits(value: UInt64, expected: String) {
        #expect(UsageFormat.bytes(value) == expected)
    }

    @Test(arguments: [(36.6, "37%"), (0.4, "0%"), (250.0, "100%"), (Double.nan, "0%")])
    func formatsPercentRounded(value: Double, expected: String) {
        #expect(UsageFormat.percent(value) == expected)
    }
}
