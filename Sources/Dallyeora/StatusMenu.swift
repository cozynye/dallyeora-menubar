import AppKit
import DallyeoraCore

/// 메뉴 막대 아이콘을 누르면 뜨는 메뉴. 항목은 설정만 바꾸고, 다시 그리기는 `Settings.didChange`를 듣는 쪽이 한다.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    let menu = NSMenu()
    /// 메뉴가 열리기 직전. 머리글을 최신 값으로 맞출 때 쓴다.
    var onOpen: (() -> Void)?
    var onCleanup: (() -> Void)?

    private let settings: Settings
    private let updater: UpdateChecker
    private let loginItem = LoginItem()
    private let updateItem = NSMenuItem()
    private let updateSeparator = NSMenuItem.separator()
    private let headerItem = NSMenuItem()
    private let phraseItem = NSMenuItem()
    private let cleanupItem = NSMenuItem()
    private let mascotMenu = NSMenu()
    private let toneMenu = NSMenu()
    private let metricMenu = NSMenu()
    private let phraseToggleItem = NSMenuItem()
    private let percentToggleItem = NSMenuItem()
    private let loginToggleItem = NSMenuItem()
    private let updateToggleItem = NSMenuItem()

    init(settings: Settings, updater: UpdateChecker) {
        self.settings = settings
        self.updater = updater
        super.init()
        build()
    }

    func setHeader(_ title: String, phrase: String) {
        headerItem.title = title
        phraseItem.title = phrase
    }

    /// 전역 단축키를 등록했을 때만 "정리하기…" 옆에 보여 준다.
    func setCleanupShortcutVisible(_ visible: Bool) {
        cleanupItem.keyEquivalent = visible ? "d" : ""
        cleanupItem.keyEquivalentModifierMask = visible ? [.control, .option, .command] : []
    }

    func refreshChecks() {
        for item in mascotMenu.items {
            item.state = (item.representedObject as? String) == settings.mascotID ? .on : .off
        }
        for item in toneMenu.items {
            item.state = (item.representedObject as? String) == settings.tone.rawValue ? .on : .off
        }
        for item in metricMenu.items {
            item.state = (item.representedObject as? String) == settings.metric.rawValue ? .on : .off
        }
        phraseToggleItem.state = settings.showsPhrase ? .on : .off
        percentToggleItem.state = settings.showsPercent ? .on : .off
        // 로그인 항목은 시스템 설정에서도 바뀔 수 있어 매번 묻는다.
        loginToggleItem.isEnabled = loginItem.isAvailable
        loginToggleItem.state = loginItem.isAvailable && loginItem.isEnabled ? .on : .off
        updateToggleItem.isEnabled = updater.isAvailable
        updateToggleItem.state = updater.isAvailable && settings.checksForUpdates ? .on : .off
        // 새 버전을 알고 있을 때만 맨 위에 한 줄이 생긴다.
        let newer = updater.newerVersion
        updateItem.title = newer.map { "새 버전 \($0) 받기" } ?? ""
        updateItem.isHidden = newer == nil
        updateSeparator.isHidden = newer == nil
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshChecks()
        onOpen?()
    }

    // MARK: 구성

    private func build() {
        menu.autoenablesItems = false
        menu.delegate = self
        configure(updateItem, "", #selector(openReleases))
        menu.addItem(updateItem)
        menu.addItem(updateSeparator)
        headerItem.isEnabled = false
        phraseItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(phraseItem)
        menu.addItem(.separator())

        configure(cleanupItem, "정리하기…", #selector(openCleanup))
        menu.addItem(cleanupItem)
        menu.addItem(.separator())

        addSubmenu("캐릭터", mascotMenu, Mascots.all.map { ($0.name, $0.id) }, #selector(selectMascot(_:)))
        addSubmenu("말투", toneMenu, Tone.allCases.map { ($0.label, $0.rawValue) }, #selector(selectTone(_:)))
        addSubmenu("지표", metricMenu, Metric.allCases.map { ($0.label, $0.rawValue) }, #selector(selectMetric(_:)))

        configure(phraseToggleItem, "메뉴 막대에 대사 표시", #selector(togglePhrase))
        menu.addItem(phraseToggleItem)
        configure(percentToggleItem, "메뉴 막대에 사용률 표시", #selector(togglePercent))
        menu.addItem(percentToggleItem)
        configure(loginToggleItem, "로그인 시 실행", #selector(toggleLogin))
        menu.addItem(loginToggleItem)
        configure(updateToggleItem, "새 버전 자동 확인", #selector(toggleUpdates))
        menu.addItem(updateToggleItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        refreshChecks()
    }

    private func configure(_ item: NSMenuItem, _ title: String, _ action: Selector) {
        item.title = title
        item.action = action
        item.target = self
    }

    private func addSubmenu(_ title: String, _ submenu: NSMenu, _ choices: [(title: String, value: String)], _ action: Selector) {
        for choice in choices {
            let item = NSMenuItem(title: choice.title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = choice.value
            submenu.addItem(item)
        }
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    // MARK: 액션

    @objc private func openCleanup() {
        onCleanup?()
    }

    @objc private func selectMascot(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        settings.mascotID = id
    }

    @objc private func selectTone(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let tone = Tone(rawValue: raw) else { return }
        settings.tone = tone
    }

    @objc private func selectMetric(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let metric = Metric(rawValue: raw) else { return }
        settings.metric = metric
    }

    @objc private func togglePhrase() {
        settings.showsPhrase.toggle()
    }

    @objc private func togglePercent() {
        settings.showsPercent.toggle()
    }

    @objc private func toggleUpdates() {
        settings.checksForUpdates.toggle()
    }

    @objc private func openReleases() {
        NSWorkspace.shared.open(UpdateChecker.releasesPage)
    }

    @objc private func toggleLogin() {
        do {
            try loginItem.setEnabled(!loginItem.isEnabled)
        } catch {
            let alert = NSAlert()
            alert.messageText = "로그인 시 실행을 바꾸지 못했습니다"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            NSApp.activate()
            alert.runModal()
        }
        // 사용자가 시스템 설정에서 막아 둔 경우에는 그 화면에서 직접 켜야 한다.
        if loginItem.needsApproval { loginItem.openSystemSettings() }
        refreshChecks()
    }
}
