import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindow: OverlayWindow?
    private var hotkeyManager: HotkeyManager?
    private var hintModeController: HintModeController?
    private var searchModeController: SearchModeController?
    private var scrollModeController: ScrollModeController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibilityPermission()

        let overlay = OverlayWindow()
        self.overlayWindow = overlay

        let hintController = HintModeController()
        self.hintModeController = hintController

        let searchController = SearchModeController()
        self.searchModeController = searchController

        let scrollController = ScrollModeController()
        self.scrollModeController = scrollController

        let manager = HotkeyManager()
        manager.onHintModeActivated = { [weak self] in
            guard let self,
                  let overlay = self.overlayWindow,
                  let hotkey = self.hotkeyManager,
                  hotkey.keyEventHandler == nil else { return }
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

    private func checkAccessibilityPermission() {
        // kAXTrustedCheckOptionPrompt は C のグローバル var として Swift に見えるため
        // Swift 6 strict concurrency 対策として生の文字列キーを使う
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "アクセシビリティ権限が必要です"
            alert.informativeText = "システム設定 > プライバシーとセキュリティ > アクセシビリティ で Vimursor を許可してください。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
