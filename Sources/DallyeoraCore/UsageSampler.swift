/// CPU와 메모리를 함께 잰다. 지표를 바꿔도 바로 값이 있도록 둘 다 유지한다.
public struct UsageSampler {
    private let readCPU: () -> CPUTicks?
    private let readMemory: () -> MemoryPages?
    private var lastTicks: CPUTicks?
    private var cpu: Double = 0
    private var memory: Double = 0
    private var cpuMeasured = false
    private var memoryMeasured = false

    public init(
        readCPU: @escaping () -> CPUTicks? = CPUTicks.current,
        readMemory: @escaping () -> MemoryPages? = MemoryPages.current
    ) {
        self.readCPU = readCPU
        self.readMemory = readMemory
    }

    /// CPU는 직전 측정과의 차이로 계산하므로 첫 호출 뒤에는 0이다. 읽기에 실패하면 이전 값을 유지한다.
    public mutating func sample() {
        if let now = readCPU() {
            if let last = lastTicks {
                cpu = CPUUsage.percent(from: last, to: now)
                cpuMeasured = true
            }
            lastTicks = now
        }
        if let pages = readMemory() {
            memory = MemoryUsage.percent(pages)
            memoryMeasured = true
        }
    }

    /// 한 번이라도 실제로 잰 값인지. CPU는 두 번째 측정부터다. 그 전의 0은 값이 아니다.
    public func isMeasured(_ metric: Metric) -> Bool {
        switch metric {
        case .cpu: cpuMeasured
        case .memory: memoryMeasured
        }
    }

    public func value(for metric: Metric) -> Double {
        switch metric {
        case .cpu: cpu
        case .memory: memory
        }
    }
}
