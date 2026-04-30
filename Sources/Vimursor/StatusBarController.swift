import AppKit
import KeyboardShortcuts

// MARK: - Constants

private enum MenuItemTag {
    static let launchAtLogin = 100
    static let continuousHintMode = 101
    static let hintMode = 102
    static let searchMode = 103
    static let scrollMode = 104
    static let cursorMode = 105
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
    private let onCursorMode: () -> Void
    private let onSettings: (() -> Void)?
    private let loginItemManager: LoginItemManager?
    private let settings: AppSettings

    // MARK: - Initialization

    /// 本番用イニシャライザ。NSStatusBar.system を使う。
    convenience init(
        onHintMode: @escaping () -> Void,
        onSearchMode: @escaping () -> Void,
        onScrollMode: @escaping () -> Void,
        onCursorMode: @escaping () -> Void = {},
        onSettings: (() -> Void)? = nil,
        loginItemManager: LoginItemManager? = nil,
        settings: AppSettings = .shared
    ) {
        self.init(
            statusItem: SystemStatusItem(),
            onHintMode: onHintMode,
            onSearchMode: onSearchMode,
            onScrollMode: onScrollMode,
            onCursorMode: onCursorMode,
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
        onCursorMode: @escaping () -> Void = {},
        onSettings: (() -> Void)? = nil,
        loginItemManager: LoginItemManager? = nil,
        settings: AppSettings = .shared
    ) {
        self.statusItem = statusItem
        self.onHintMode = onHintMode
        self.onSearchMode = onSearchMode
        self.onScrollMode = onScrollMode
        self.onCursorMode = onCursorMode
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
        button.image = MenuBarIconLoader.loadFromBundle() ?? MenuBarIconLoader.fallbackIcon()
        button.toolTip = "Vimursor"
    }

    private func configureMenu() {
        let menu = NSMenu()
        addModeItems(to: menu)
        menu.addItem(.separator())
        addAppItems(to: menu)
        menu.addItem(.separator())
        addPreferenceItems(to: menu)
        menu.addItem(.separator())
        addQuitItem(to: menu)
        menu.delegate = self
        statusItem.menu = menu
    }

    private func addModeItems(to menu: NSMenu) {
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

        let cursorItem = NSMenuItem(
            title: "Cursor Mode",
            action: #selector(activateCursorMode),
            keyEquivalent: ""
        )
        cursorItem.target = self
        cursorItem.tag = MenuItemTag.cursorMode
        cursorItem.setShortcut(for: .cursorMode)
        menu.addItem(cursorItem)
    }

    private func addAppItems(to menu: NSMenu) {
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        settingsItem.isEnabled = (onSettings != nil)
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "About Vimursor",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
    }

    private func addPreferenceItems(to menu: NSMenu) {
        let continuousItem = NSMenuItem(
            title: "Continuous Hint Mode",
            action: #selector(toggleContinuousHintMode),
            keyEquivalent: ""
        )
        continuousItem.target = self
        continuousItem.tag = MenuItemTag.continuousHintMode
        menu.addItem(continuousItem)

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.tag = MenuItemTag.launchAtLogin
        menu.addItem(launchAtLoginItem)
    }

    private func addQuitItem(to menu: NSMenu) {
        let quitItem = NSMenuItem(
            title: "Quit Vimursor",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // メニューが開いている間は Carbon ホットキーをバッファしないよう無効化する
        KeyboardShortcuts.disable(.hintMode, .searchMode, .scrollMode, .cursorMode)

        // macOS のメニュー描画エンジンは Shift+記号キー（例: Shift+/）の表示を正しく描画できない。
        // setShortcut(for:) が "/" + [.command, .shift] を設定するため、
        // "?" + [.command] に補正して ⌘⇧/ を正しく表示させる。
        if let item = menu.item(withTag: MenuItemTag.searchMode),
           item.keyEquivalentModifierMask.contains(.command),
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
        KeyboardShortcuts.enable(.hintMode, .searchMode, .scrollMode, .cursorMode)
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

    @objc private func activateCursorMode() {
        onCursorMode()
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

    func simulateCursorMode() {
        onCursorMode()
    }

    func simulateSettings() {
        onSettings?()
    }
    #endif
}
