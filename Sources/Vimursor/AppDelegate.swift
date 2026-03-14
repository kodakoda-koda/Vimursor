import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindow: OverlayWindow?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibilityPermission()

        let overlay = OverlayWindow()
        self.overlayWindow = overlay

        let manager = HotkeyManager()
        manager.onHintModeActivated = { [weak self] in
            self?.overlayWindow?.toggle()
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
