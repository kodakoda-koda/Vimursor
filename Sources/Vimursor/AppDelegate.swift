import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindow: OverlayWindow?
    private var hotkeyManager: HotkeyManager?
    private var hintModeController: HintModeController?
    private var searchModeController: SearchModeController?
    private var scrollModeController: ScrollModeController?
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var permissionMonitor: AccessibilityPermissionMonitor?
    private var loginItemManager: LoginItemManager?
    private let appSettings = AppSettings.shared

    // MARK: - Constants

    private enum AccessibilitySettings {
        static let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // UI構築（権限有無に関わらず常に実施）
        let overlay = OverlayWindow()
        self.overlayWindow = overlay

        self.hintModeController = HintModeController(settings: appSettings)
        self.searchModeController = SearchModeController()
        self.scrollModeController = ScrollModeController()

        // ログイン時起動マネージャを生成し、システム状態と同期する
        let loginManager = LoginItemManager()
        loginManager.syncWithSystem()
        self.loginItemManager = loginManager

        // 設定ウィンドウコントローラを生成（遅延なしで保持）
        let settingsController = SettingsWindowController(settings: appSettings)
        self.settingsWindowController = settingsController

        // メニューバーアイコンは権限に関わらず常に表示。
        // モード起動コールバックは hotkeyManager が nil の場合は何もしない（weak self チェーンで自然に対応）。
        self.statusBarController = StatusBarController(
            onHintMode: { [weak self] in self?.hotkeyManager?.onHintModeActivated?() },
            onSearchMode: { [weak self] in self?.hotkeyManager?.onSearchModeActivated?() },
            onScrollMode: { [weak self] in self?.hotkeyManager?.onScrollModeActivated?() },
            onSettings: { [weak settingsController] in settingsController?.showSettingsWindow() },
            loginItemManager: loginManager,
            settings: appSettings
        )

        // KeyboardShortcuts コールバックを登録する。
        // NSEvent.addGlobalMonitorForEvents ベースのため、アクセシビリティ権限は不要。
        // hotkeyManager が nil の間はコールバック内で何もしない（weak self チェーンで自然に対応）。
        //
        // 【二重登録について】
        // StatusBarController のコールバック（メニューUI経由）と KeyboardShortcuts のコールバック
        // （ショートカットキー経由）は、両方とも hotkeyManager.onXxxActivated を経由する。
        // hotkeyManager.onXxxActivated 内の `guard hotkey.keyEventHandler == nil` により
        // 二重起動を防止しているため、登録経路が2つあっても問題ない。
        setupKeyboardShortcutsHandlers()

        // 権限チェック → 許可済みなら即 setupHotkeyManager、未許可なら Alert + ポーリング
        let checker = SystemAccessibilityPermissionChecker()
        if checker.isGranted() {
            setupHotkeyManager()
        } else {
            showPermissionAlert()
            startPermissionPolling(checker: checker)
        }
    }

    // MARK: - KeyboardShortcuts handlers

    /// KeyboardShortcuts のコールバックを登録する。
    /// Carbon ホットキーベースのため、アクセシビリティ権限不要で起動直後から有効になる。
    private func setupKeyboardShortcutsHandlers() {
        KeyboardShortcuts.onKeyUp(for: .hintMode) { [weak self] in
            self?.hotkeyManager?.onHintModeActivated?()
        }
        KeyboardShortcuts.onKeyUp(for: .searchMode) { [weak self] in
            self?.hotkeyManager?.onSearchModeActivated?()
        }
        KeyboardShortcuts.onKeyUp(for: .scrollMode) { [weak self] in
            self?.hotkeyManager?.onScrollModeActivated?()
        }
    }

    // MARK: - HotkeyManager setup

    /// HotkeyManager を生成してコールバックを接続し、start() を呼ぶ。
    private func setupHotkeyManager() {
        let manager = HotkeyManager()
        manager.onHintModeActivated = { [weak self] in
            guard let self,
                  let overlay = self.overlayWindow,
                  let hotkey = self.hotkeyManager,
                  hotkey.keyEventHandler == nil else { return }
            AXManager.enableManualAccessibility()
            self.hintModeController?.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        }
        manager.onSearchModeActivated = { [weak self] in
            guard let self,
                  let overlay = self.overlayWindow,
                  let hotkey = self.hotkeyManager,
                  hotkey.keyEventHandler == nil else { return }
            self.searchModeController?.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        }
        manager.onScrollModeActivated = { [weak self] in
            guard let self,
                  let overlay = self.overlayWindow,
                  let hotkey = self.hotkeyManager,
                  hotkey.keyEventHandler == nil else { return }
            self.scrollModeController?.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        }
        self.hotkeyManager = manager
        manager.start()
    }

    // MARK: - Permission handling

    /// 権限未許可時の NSAlert を表示し、どちらのボタン押下後もポーリングを開始する。
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "アクセシビリティ権限が必要です"
        alert.informativeText = """
            Vimursor はキーボード操作のためにアクセシビリティ権限が必要です。
            システム設定 > プライバシーとセキュリティ > アクセシビリティ で許可してください。
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "後で")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
           let url = AccessibilitySettings.url {
            NSWorkspace.shared.open(url)
        }
    }

    /// 権限付与を1秒間隔でポーリングし、付与されたら setupHotkeyManager() を呼ぶ。
    private func startPermissionPolling(checker: some AccessibilityPermissionChecker) {
        let monitor = AccessibilityPermissionMonitor(checker: checker, interval: 1.0)
        self.permissionMonitor = monitor
        monitor.startPolling { [weak self] in
            self?.setupHotkeyManager()
            self?.permissionMonitor = nil
        }
    }
}
