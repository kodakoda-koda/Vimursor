import AppKit

@MainActor
final class OverlayWindow: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        level = .screenSaver
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false  // アプリが非アクティブでもパネルを維持する
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // key window 化を許可（NSPanel のデフォルトは false）
    override var canBecomeKey: Bool { true }

    func show() {
        orderFrontRegardless()
    }

    // 検索モード用: key window として前面表示
    func showAsKeyWindow() {
        ignoresMouseEvents = false  // NSTextField がイベントを受信できるようにする
        makeKeyAndOrderFront(nil)
    }

    func hide() {
        if isKeyWindow { resignKey() }
        ignoresMouseEvents = true  // 他のモード用にマウスイベント無視に戻す
        orderOut(nil)
    }
}
