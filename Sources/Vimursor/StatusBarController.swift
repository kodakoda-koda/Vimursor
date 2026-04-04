import AppKit

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
final class StatusBarController {

    // MARK: - Private properties

    private let statusItem: any StatusItemProvider
    private let onHintMode: () -> Void
    private let onSearchMode: () -> Void
    private let onScrollMode: () -> Void

    // MARK: - Initialization

    /// 本番用イニシャライザ。NSStatusBar.system を使う。
    convenience init(
        onHintMode: @escaping () -> Void,
        onSearchMode: @escaping () -> Void,
        onScrollMode: @escaping () -> Void
    ) {
        self.init(
            statusItem: SystemStatusItem(),
            onHintMode: onHintMode,
            onSearchMode: onSearchMode,
            onScrollMode: onScrollMode
        )
    }

    /// テスト・DI 用イニシャライザ。任意の StatusItemProvider を注入できる。
    init(
        statusItem: any StatusItemProvider,
        onHintMode: @escaping () -> Void,
        onSearchMode: @escaping () -> Void,
        onScrollMode: @escaping () -> Void
    ) {
        self.statusItem = statusItem
        self.onHintMode = onHintMode
        self.onSearchMode = onSearchMode
        self.onScrollMode = onScrollMode

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
            print("[StatusBarController] SF Symbol 'keyboard' の読み込みに失敗しました")
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
            keyEquivalent: " "   // Space
        )
        hintItem.keyEquivalentModifierMask = [.command, .shift]
        hintItem.target = self
        menu.addItem(hintItem)

        let searchItem = NSMenuItem(
            title: "Search Mode",
            action: #selector(activateSearchMode),
            keyEquivalent: "?"
        )
        searchItem.keyEquivalentModifierMask = [.command]
        searchItem.target = self
        menu.addItem(searchItem)

        let scrollItem = NSMenuItem(
            title: "Scroll Mode",
            action: #selector(activateScrollMode),
            keyEquivalent: "j"
        )
        scrollItem.keyEquivalentModifierMask = [.command, .shift]
        scrollItem.target = self
        menu.addItem(scrollItem)

        menu.addItem(.separator())

        // ── About ─────────────────────────────────
        let aboutItem = NSMenuItem(
            title: "About Vimursor",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

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

        statusItem.menu = menu
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

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
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
    #endif
}
