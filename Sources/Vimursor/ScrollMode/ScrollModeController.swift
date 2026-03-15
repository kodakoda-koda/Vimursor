import AppKit
import CoreGraphics

private enum ScrollModeState {
    case inactive
    case active
}

private enum ScrollKeyCode {
    static let esc: CGKeyCode = 53
    static let j: CGKeyCode = 38
    static let k: CGKeyCode = 40
    static let d: CGKeyCode = 2
    static let u: CGKeyCode = 32
}

private final class ScrollIndicatorView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemBlue.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        ("SCROLL" as NSString).draw(
            at: CGPoint(x: 8, y: (bounds.height - 14) / 2),
            withAttributes: attrs
        )
    }
}

final class ScrollModeController: @unchecked Sendable {
    private var state: ScrollModeState = .inactive
    private var isActive: Bool = false
    private var indicatorView: ScrollIndicatorView?
    private weak var overlayWindow: OverlayWindow?
    private weak var hotkeyManager: HotkeyManager?
    private var currentTargetPoint: CGPoint? = nil

    func activate(overlayWindow: OverlayWindow, hotkeyManager: HotkeyManager) {
        guard !isActive else { return }
        self.overlayWindow = overlayWindow
        self.hotkeyManager = hotkeyManager
        state = .active
        isActive = true

        let indicator = ScrollIndicatorView(frame: CGRect(x: 12, y: 12, width: 80, height: 28))
        overlayWindow.contentView?.addSubview(indicator)
        self.indicatorView = indicator
        overlayWindow.show()

        hotkeyManager.keyEventHandler = { [weak self] keyCode, flags in
            guard let self, self.isActive else { return false }
            DispatchQueue.main.async { self.handleKey(keyCode: keyCode, flags: flags) }
            return true
        }

        // バックグラウンドでスクロール対象の中心点を取得
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AXElement(ref: AXUIElementCreateApplication(focusedApp.processIdentifier))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let target = ScrollTarget.findScrollableElement(in: appElement.ref)
            let point = target.flatMap { ScrollTarget.centerPoint(of: $0) }
            DispatchQueue.main.async { self?.currentTargetPoint = point }
        }
    }

    func deactivate() {
        isActive = false
        state = .inactive
        currentTargetPoint = nil
        indicatorView?.removeFromSuperview()
        indicatorView = nil
        hotkeyManager?.keyEventHandler = nil
        overlayWindow?.hide()
    }

    private func handleKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        if keyCode == ScrollKeyCode.esc {
            deactivate()
            return
        }

        // 修飾キー付きは無視（Cmd+J 等のシステムショートカットとの競合防止）
        guard flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else { return }

        switch keyCode {
        case ScrollKeyCode.j:
            ScrollEngine.scroll(amount: .step(direction: .down), targetPoint: currentTargetPoint)
        case ScrollKeyCode.k:
            ScrollEngine.scroll(amount: .step(direction: .up), targetPoint: currentTargetPoint)
        case ScrollKeyCode.d:
            ScrollEngine.scroll(amount: .halfPage(direction: .down), targetPoint: currentTargetPoint)
        case ScrollKeyCode.u:
            ScrollEngine.scroll(amount: .halfPage(direction: .up), targetPoint: currentTargetPoint)
        default:
            break
        }
    }
}
