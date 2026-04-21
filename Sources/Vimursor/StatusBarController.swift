import AppKit
import KeyboardShortcuts
import os

private let logger = Logger(subsystem: "com.vimursor.app", category: "StatusBar")

// MARK: - Constants

private enum MenuItemTag {
    static let launchAtLogin = 100
    static let continuousHintMode = 101
    static let hintMode = 102
    static let searchMode = 103
    static let scrollMode = 104
}

// MARK: - Protocol

/// NSStatusItem のテスト用抽象化。
/// 実装は NSStatusItem を直接ラップし、テストではモックを差し込む。
@MainActor
protocol StatusItemProvider: AnyObject {
    var button: NSStatusBarButton? { get }
    var menu: NSMenu? { get set }
}

// MARK: - Production wrapper

/// NSStatusItem を StatusItemProvider として公開するラッパー。
@MainActor
final class SystemStatusItem: StatusItemProvider {
    private let item: NSStatusItem

    init() {
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    }

    var button: NSStatusBarButton? { item.button }

    var menu: NSMenu? {
        get { item.menu }
        set { item.menu = newValue }
    }
}

// MARK: - Controller

/// メニューバー常駐アイコンとメニューを管理するコントローラ。
/// NSStatusItem のライフタイムを保持し、各モードの起動をコールバックに委譲する。
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {

    // MARK: - Private properties

    private let statusItem: any StatusItemProvider
    private let onHintMode: () -> Void
    private let onSearchMode: () -> Void
    private let onScrollMode: () -> Void
    private let onSettings: (() -> Void)?
    private let loginItemManager: LoginItemManager?
    private let settings: AppSettings

    // MARK: - Initialization

    /// 本番用イニシャライザ。NSStatusBar.system を使う。
    convenience init(
        onHintMode: @escaping () -> Void,
        onSearchMode: @escaping () -> Void,
        onScrollMode: @escaping () -> Void,
        onSettings: (() -> Void)? = nil,
        loginItemManager: LoginItemManager? = nil,
        settings: AppSettings = .shared
    ) {
        self.init(
            statusItem: SystemStatusItem(),
            onHintMode: onHintMode,
            onSearchMode: onSearchMode,
            onScrollMode: onScrollMode,
            onSettings: onSettings,
            loginItemManager: loginItemManager,
            settings: settings
        )
    }

    /// テスト・DI 用イニシャライザ。任意の StatusItemProvider を注入できる。
    init(
        statusItem: any StatusItemProvider,
        onHintMode: @escaping () -> Void,
        onSearchMode: @escaping () -> Void,
        onScrollMode: @escaping () -> Void,
        onSettings: (() -> Void)? = nil,
        loginItemManager: LoginItemManager? = nil,
        settings: AppSettings = .shared
    ) {
        self.statusItem = statusItem
        self.onHintMode = onHintMode
        self.onSearchMode = onSearchMode
        self.onScrollMode = onScrollMode
        self.onSettings = onSettings
        self.loginItemManager = loginItemManager
        self.settings = settings

        super.init()

        configureButton()
        configureMenu()
    }

    // MARK: - Private configuration

    private func configureButton() {
        guard let button = statusItem.button else { return }
        guard let icon = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: "Vimursor"
        ) else {
            logger.warning("SF Symbol 'keyboard' の読み込みに失敗しました")
            return
        }
        icon.isTemplate = true
        button.image = icon
        button.toolTip = "Vimursor"
    }

    private func configureMenu() {
        let menu = NSMenu()

        // ── モード起動 ──────────────────────────────
        let hintItem = NSMenuItem(
            title: "Hint Mode",
            action: #selector(activateHintMode),
            keyEquivalent: ""
        )
        hintItem.target = self
        hintItem.tag = MenuItemTag.hintMode
        hintItem.setShortcut(for: .hintMode)
        menu.addItem(hintItem)

        let searchItem = NSMenuItem(
            title: "Search Mode",
            action: #selector(activateSearchMode),
            keyEquivalent: ""
        )
        searchItem.target = self
        searchItem.tag = MenuItemTag.searchMode
        searchItem.setShortcut(for: .searchMode)
        menu.addItem(searchItem)

        let scrollItem = NSMenuItem(
            title: "Scroll Mode",
            action: #selector(activateScrollMode),
            keyEquivalent: ""
        )
        scrollItem.target = self
        scrollItem.tag = MenuItemTag.scrollMode
        scrollItem.setShortcut(for: .scrollMode)
        menu.addItem(scrollItem)

        menu.addItem(.separator())

        // ── Settings ──────────────────────────────
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        settingsItem.isEnabled = (onSettings != nil)
        menu.addItem(settingsItem)

        // ── About ─────────────────────────────────
        let aboutItem = NSMenuItem(
            title: "About Vimursor",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        // ── Continuous Hint Mode ─────────────────
        let continuousItem = NSMenuItem(
            title: "Continuous Hint Mode",
            action: #selector(toggleContinuousHintMode),
            keyEquivalent: ""
        )
        continuousItem.target = self
        continuousItem.tag = MenuItemTag.continuousHintMode
        menu.addItem(continuousItem)

        // ── Launch at Login ───────────────────────
        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.tag = MenuItemTag.launchAtLogin
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        // ── Quit ──────────────────────────────────
        let quitItem = NSMenuItem(
            title: "Quit Vimursor",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // メニューが開いている間は Carbon ホットキーをバッファしないよう無効化する
        KeyboardShortcuts.disable(.hintMode, .searchMode, .scrollMode)

        // macOS のメニュー描画エンジンは Shift+記号キー（例: Shift+/）の表示を正しく描画できない。
        // setShortcut(for:) が "/" + [.command, .shift] を設定するため、
        // "?" + [.command] に補正して ⌘⇧/ を正しく表示させる。
        if let item = menu.item(withTag: MenuItemTag.searchMode),
           item.keyEquivalentModifierMask.contains(.shift),
           item.keyEquivalent == "/" {
            item.keyEquivalent = "?"
            item.keyEquivalentModifierMask.remove(.shift)
        }

        if let item = menu.item(withTag: MenuItemTag.continuousHintMode) {
            item.state = settings.isContinuousMode ? .on : .off
        }

        if let item = menu.item(withTag: MenuItemTag.launchAtLogin) {
            if let loginItemManager {
                loginItemManager.syncWithSystem()
                item.isEnabled = true
                item.state = loginItemManager.isEnabled ? .on : .off
            } else {
                item.isEnabled = false
                item.state = .off
            }
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        KeyboardShortcuts.enable(.hintMode, .searchMode, .scrollMode)
    }

    // MARK: - Menu actions

    @objc private func activateHintMode() {
        onHintMode()
    }

    @objc private func activateSearchMode() {
        onSearchMode()
    }

    @objc private func activateScrollMode() {
        onScrollMode()
    }

    @objc private func openSettings() {
        onSettings?()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func toggleLaunchAtLogin() {
        loginItemManager?.toggle()
    }

    @objc private func toggleContinuousHintMode() {
        settings.toggleContinuousMode()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Test helpers

    #if DEBUG
    func simulateHintMode() {
        onHintMode()
    }

    func simulateSearchMode() {
        onSearchMode()
    }

    func simulateScrollMode() {
        onScrollMode()
    }

    func simulateSettings() {
        onSettings?()
    }
    #endif
}
