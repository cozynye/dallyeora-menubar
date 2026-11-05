import AppKit
import DallyeoraCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings: Settings
    private let headerItem = NSMenuItem()
    private let phraseItem = NSMenuItem()
    private let mascotMenu = NSMenu()
    private let toneMenu = NSMenu()
    private var cpu: Double = 0
    private var phase: Double = 0
    private var lastTicks: CPUTicks?
    private var cpuTimer: Timer?
    private var frameTimer: Timer?

    private var mascot: any Mascot { Mascots.find(settings.mascotID) ?? Mascots.default }

    init(settings: Settings) {
        self.settings = settings
        super.init()
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.cell?.lineBreakMode = .byTruncatingTail
        buildMenu()
        updateLength()
        sampleCPU()
        startCPUTimer()
        render()
        scheduleNextFrame()
    }

    // MARK: 타이머 — 메뉴가 열려 있어도 돌도록 .common 모드에 등록

    private func startCPUTimer() {
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleCPU() }
        }
        RunLoop.main.add(timer, forMode: .common)
        cpuTimer = timer
    }

    private func scheduleNextFrame() {
        let timer = Timer(timeInterval: AnimationClock.frameInterval(cpu: cpu), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private func tick() {
        phase += AnimationClock.phaseStep
        render()
        scheduleNextFrame()
    }

    private func sampleCPU() {
        guard let now = CPUTicks.current() else { return }
        if let last = lastTicks {
            cpu = CPUUsage.percent(from: last, to: now)
        }
        lastTicks = now
    }

    // MARK: 그리기

    private func render() {
        guard let button = statusItem.button else { return }
        let m = mascot
        if let cg = MascotRenderer.render(m, phase: phase, cpu: cpu) {
            let image = NSImage(cgImage: cg, size: MascotRenderer.size)
            image.isTemplate = true
            button.image = image
        }
        let text = m.phrase(cpu: cpu, tone: settings.tone)
        let title = " " + text
        if button.title != title { button.title = title }
        headerItem.title = "\(m.name)    CPU \(Int(cpu.rounded()))%"
        phraseItem.title = text
    }

    /// 현재 캐릭터·말투의 문구 중 가장 긴 것에 폭을 고정한다.
    private func updateLength() {
        let font = statusItem.button?.font ?? NSFont.menuBarFont(ofSize: 0)
        let widths = mascot.tiers.map {
            NSAttributedString(string: " " + $0.text(settings.tone), attributes: [.font: font]).size().width
        }
        statusItem.length = StatusLayout.length(iconWidth: MascotRenderer.size.width, phraseWidths: widths)
    }

    // MARK: 메뉴

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        headerItem.isEnabled = false
        phraseItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(phraseItem)
        menu.addItem(.separator())

        for m in Mascots.all {
            let item = NSMenuItem(title: m.name, action: #selector(selectMascot(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = m.id
            mascotMenu.addItem(item)
        }
        let mascotItem = NSMenuItem(title: "캐릭터", action: nil, keyEquivalent: "")
        mascotItem.submenu = mascotMenu
        menu.addItem(mascotItem)

        for tone in Tone.allCases {
            let item = NSMenuItem(title: tone.label, action: #selector(selectTone(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tone.rawValue
            toneMenu.addItem(item)
        }
        let toneItem = NSMenuItem(title: "말투", action: nil, keyEquivalent: "")
        toneItem.submenu = toneMenu
        menu.addItem(toneItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
        updateChecks()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateChecks()
        render()
    }

    private func updateChecks() {
        for item in mascotMenu.items {
            item.state = (item.representedObject as? String) == settings.mascotID ? .on : .off
        }
        for item in toneMenu.items {
            item.state = (item.representedObject as? String) == settings.tone.rawValue ? .on : .off
        }
    }

    @objc private func selectMascot(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        settings.mascotID = id
        updateChecks()
        updateLength()
        render()
    }

    @objc private func selectTone(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let tone = Tone(rawValue: raw) else { return }
        settings.tone = tone
        updateChecks()
        updateLength()
        render()
    }
}
