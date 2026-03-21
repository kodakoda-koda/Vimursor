import AppKit
import CoreGraphics

struct ScrollAreaInfo {
    let frame: CGRect        // AX スクリーン座標（描画変換用）
    let centerPoint: CGPoint // CGEvent.location 用（変換不要、スクリーン座標のまま）
    let label: String        // "1", "2", ...
}

private enum ScrollModeState {
    case inactive
    case fetching
    case active(areas: [ScrollAreaInfo], selectedIndex: Int)
}

enum ScrollKeyCode {
    static let esc: CGKeyCode  = 53
    static let tab: CGKeyCode  = 48
    static let j: CGKeyCode    = 38
    static let k: CGKeyCode    = 40
    static let d: CGKeyCode    = 2
    static let u: CGKeyCode    = 32
    // 数字 1〜9（US キーボード）
    static let numToIndex: [CGKeyCode: Int] = [
        18: 0, 19: 1, 20: 2, 21: 3, 23: 4,
        22: 5, 26: 6, 28: 7, 25: 8
    ]
}

@MainActor
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

@MainActor
final class ScrollModeController {
    private var state: ScrollModeState = .inactive
    private var scrollAreaView: ScrollAreaView?
    private var indicatorView: ScrollIndicatorView?
    private weak var overlayWindow: OverlayWindow?
    private weak var hotkeyManager: HotkeyManager?

    func activate(overlayWindow: OverlayWindow, hotkeyManager: HotkeyManager) {
        guard case .inactive = state else { return }
        state = .fetching
        self.overlayWindow = overlayWindow
        self.hotkeyManager = hotkeyManager

        // fetching 中もキーを消費する（他モードへの漏れを防ぐ）
        hotkeyManager.keyEventHandler = { [weak self] keyCode, flags in
            guard let self else { return false }
            Task { @MainActor [weak self] in
                self?.handleKey(keyCode: keyCode, flags: flags)
            }
            return true
        }

        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            deactivate()
            return
        }
        let appElement = AXElement(ref: AXUIElementCreateApplication(focusedApp.processIdentifier))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let areas = ScrollTarget.enumerateScrollableElements(root: appElement.ref)
            DispatchQueue.main.async { self?.startScrollMode(areas: areas) }
        }
    }

    private func startScrollMode(areas: [ScrollAreaInfo]) {
        guard case .fetching = state else { return }

        if areas.isEmpty {
            deactivate()
            return
        }

        state = .active(areas: areas, selectedIndex: 0)

        let screenHeight = NSScreen.main?.frame.height ?? 0
        let viewFrame = overlayWindow?.contentView?.bounds ?? .zero
        let areaView = ScrollAreaView(screenHeight: screenHeight, frame: viewFrame)
        areaView.autoresizingMask = [.width, .height]
        areaView.update(areas: areas, selectedIndex: 0)
        overlayWindow?.contentView?.addSubview(areaView)
        self.scrollAreaView = areaView

        let indicator = ScrollIndicatorView(frame: CGRect(x: 12, y: 12, width: 80, height: 28))
        overlayWindow?.contentView?.addSubview(indicator)
        self.indicatorView = indicator

        overlayWindow?.show()
    }

    func deactivate() {
        state = .inactive
        scrollAreaView?.removeFromSuperview()
        scrollAreaView = nil
        indicatorView?.removeFromSuperview()
        indicatorView = nil
        hotkeyManager?.keyEventHandler = nil
        overlayWindow?.hide()
    }

    private func handleKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        // fetching 中は ESC のみ受け付ける
        if case .fetching = state {
            if keyCode == ScrollKeyCode.esc { deactivate() }
            return
        }

        guard case .active(let areas, let selectedIndex) = state else { return }

        // ESC: 終了（修飾キーに関わらず常に有効）
        if keyCode == ScrollKeyCode.esc {
            deactivate()
            return
        }

        let isShift = flags.contains(.maskShift)
        let otherModifiers = flags.intersection([.maskCommand, .maskControl, .maskAlternate])

        // Tab / Shift+Tab: 領域切り替え
        if keyCode == ScrollKeyCode.tab && otherModifiers.isEmpty {
            let next = isShift
                ? (selectedIndex - 1 + areas.count) % areas.count  // Shift+Tab: 逆順
                : (selectedIndex + 1) % areas.count                 // Tab: 順送り
            selectArea(index: next, areas: areas)
            return
        }

        // 修飾キー付きは以降を無視（Cmd+J 等のシステムショートカットとの競合防止）
        guard otherModifiers.isEmpty && !isShift else { return }

        // 数字キー: 領域選択
        if let index = ScrollKeyCode.numToIndex[keyCode], index < areas.count {
            selectArea(index: index, areas: areas)
            return
        }

        // スクロールキー
        let targetPoint = areas[selectedIndex].centerPoint
        switch keyCode {
        case ScrollKeyCode.j:
            ScrollEngine.scroll(amount: .step(direction: .down), targetPoint: targetPoint)
        case ScrollKeyCode.k:
            ScrollEngine.scroll(amount: .step(direction: .up), targetPoint: targetPoint)
        case ScrollKeyCode.d:
            ScrollEngine.scroll(amount: .halfPage(direction: .down), targetPoint: targetPoint)
        case ScrollKeyCode.u:
            ScrollEngine.scroll(amount: .halfPage(direction: .up), targetPoint: targetPoint)
        default:
            break
        }
    }

    private func selectArea(index: Int, areas: [ScrollAreaInfo]) {
        state = .active(areas: areas, selectedIndex: index)
        scrollAreaView?.update(areas: areas, selectedIndex: index)
    }
}
