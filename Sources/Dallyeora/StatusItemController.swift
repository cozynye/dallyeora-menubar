import AppKit
import DallyeoraCore

/// 메뉴 막대 아이콘. 사용률을 재고 캐릭터를 그린다. 메뉴는 `StatusMenu`가 맡는다.
@MainActor
final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings: Settings
    private let menu: StatusMenu
    private let updater: UpdateChecker
    private let cleanup: CleanupWindowController
    private var activity: ActivityMonitor?
    private var hotKey: GlobalHotKey?
    private var settingsObserver: NSObjectProtocol?
    private var sampler = UsageSampler()
    private var phase: Double = 0
    private var sampleTimer: Timer?
    private var frameTimer: Timer?
    private var flash = PhraseFlash()
    private var flashTimer: Timer?
    private var lastMascotID: String
    /// 대사를 항상 켰거나, 단계가 바뀌어 잠깐 보여 주는 중.
    private var phraseVisible: Bool { settings.showsPhrase || flash.isFlashing }

    private var mascot: any Mascot { Mascots.find(settings.mascotID) ?? Mascots.default }
    /// 캐릭터가 반응하는 값. 설정에서 고른 지표를 따른다.
    private var usage: Double { sampler.value(for: settings.metric) }

    init(settings: Settings) {
        self.settings = settings
        updater = UpdateChecker(settings: settings)
        menu = StatusMenu(settings: settings, updater: updater)
        cleanup = CleanupWindowController(settings: settings)
        lastMascotID = settings.mascotID
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.cell?.lineBreakMode = .byTruncatingTail
        // 숫자가 바뀌어도 글자 폭이 흔들리지 않게 고정폭 숫자를 쓴다.
        statusItem.button?.font = .monospacedDigitSystemFont(
            ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        statusItem.menu = menu.menu
        menu.onOpen = { [weak self] in self?.render() }
        menu.onCleanup = { [weak self] in self?.openCleanup() }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: Settings.didChange, object: settings, queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.apply() }
        }
        activity = ActivityMonitor { [weak self] active in self?.setActive(active) }
        let hotKey = GlobalHotKey { [weak self] in self?.openCleanup() }
        menu.setCleanupShortcutVisible(hotKey.register())
        self.hotKey = hotKey

        updater.onChange = { [weak self] in self?.menu.refreshChecks() }
        updater.start()

        updateLength()
        sampler.sample()
        startSampleTimer()
        render()
        scheduleNextFrame()
        // CPU는 두 번 재야 값이 나오므로 첫 2초를 0%로 보이지 않게 한 번 더 잰다.
        let warmUp = Timer(timeInterval: 0.25, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampler.sample() }
        }
        RunLoop.main.add(warmUp, forMode: .common)
    }

    /// 설정이 바뀌면 체크 표시, 폭, 그림을 한 번에 맞춘다.
    private func apply() {
        if settings.mascotID != lastMascotID {
            lastMascotID = settings.mascotID
            flash.reset() // 캐릭터마다 단계가 달라 바꾼 직후에는 대사를 띄우지 않고, 띄워 둔 것도 내린다
            flashTimer?.invalidate()
            flashTimer = nil
        }
        menu.refreshChecks()
        updateLength()
        render()
    }

    private func openCleanup() {
        cleanup.show()
    }

    // MARK: 타이머 — 메뉴가 열려 있어도 돌도록 .common 모드에 등록

    private func startSampleTimer() {
        sampleTimer?.invalidate()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampler.sample() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        sampleTimer = timer
    }

    private func scheduleNextFrame() {
        frameTimer?.invalidate()
        let interval = AnimationClock.frameInterval(usage: usage)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private func tick() {
        phase += AnimationClock.phaseStep
        render()
        scheduleNextFrame()
    }

    /// 화면이 꺼져 있거나 다른 사용자가 쓰는 동안에는 재지도 그리지도 않는다.
    private func setActive(_ active: Bool) {
        if active {
            sampler.sample()
            startSampleTimer()
            render()
            scheduleNextFrame()
        } else {
            sampleTimer?.invalidate()
            sampleTimer = nil
            frameTimer?.invalidate()
            frameTimer = nil
        }
        cleanup.setActive(active)
    }

    // MARK: 그리기

    private func render() {
        guard let button = statusItem.button else { return }
        let m = mascot
        let value = usage
        if let cg = MascotRenderer.render(m, phase: phase, usage: value) {
            let image = NSImage(cgImage: cg, size: MascotRenderer.size)
            image.isTemplate = true
            button.image = image
        }
        let phrase = m.phrase(usage: value, tone: settings.tone)
        if button.toolTip != phrase { button.toolTip = phrase }
        // 숨겨 둔 대사는 단계가 바뀌는 순간에만 잠깐 보여 준다. 아직 재지 못한 0%는 단계로 치지 않는다.
        if sampler.isMeasured(settings.metric),
           flash.shouldFlash(tier: m.tierIndex(for: value), pinned: settings.showsPhrase) {
            startFlashTimer()
        }
        let title = StatusTitle.text(
            percent: settings.showsPercent ? value : nil, phrase: phraseVisible ? phrase : nil)
        if button.title != title { button.title = title }
        menu.setHeader("\(m.name)    \(settings.metric.label) \(UsageFormat.percent(value))", phrase: phrase)
    }

    /// 현재 캐릭터·말투의 문구 중 가장 긴 것에 폭을 고정한다. 숫자는 100%일 때의 폭을 늘 잡아 둔다.
    private func updateLength() {
        let font = statusItem.button?.font ?? NSFont.menuBarFont(ofSize: 0)
        func width(_ text: String) -> CGFloat {
            NSAttributedString(string: text, attributes: [.font: font]).size().width
        }
        let phraseWidths = phraseVisible ? mascot.tiers.map { width(" " + $0.text(settings.tone)) } : []
        statusItem.length = StatusLayout.length(
            iconWidth: MascotRenderer.size.width,
            percentWidth: settings.showsPercent ? width(StatusTitle.widestPercent) : 0,
            phraseWidths: phraseWidths)
    }

    /// 대사를 `PhraseFlash.duration` 동안 붙였다가 뗀다. 그 사이 또 바뀌면 시간을 다시 센다.
    private func startFlashTimer() {
        updateLength()
        flashTimer?.invalidate()
        let timer = Timer(timeInterval: PhraseFlash.duration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.flash.expire()
                self.updateLength()
                self.render()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        flashTimer = timer
    }
}
